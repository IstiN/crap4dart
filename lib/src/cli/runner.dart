import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../config/config.dart';
import '../config/config_loader.dart';
import '../config/config_template.dart';
import '../coverage/coverage_runner.dart';
import '../coverage/lcov_parser.dart';
import '../crap/crap_analyzer.dart';
import '../crap/crap_report.dart';
import '../files/changed_files.dart';
import '../files/diff_parser.dart';
import '../files/source_finder.dart';
import '../gates/baseline.dart';
import '../gates/gate_context.dart';
import '../gates/gate_runner.dart';
import '../hooks/ci_installer.dart';
import '../hooks/hook_installer.dart';
import '../profile/profile_runner.dart';
import '../report/badge_svg.dart';
import '../report/json_reporter.dart';
import 'exit_codes.dart';
import 'profile_command.dart';
import 'skill_command.dart';

/// Canonical absolute form of [path] (symlinks resolved — git reports
/// /private/var on macOS while callers often hold /var).
String canonicalPath(String path) => Directory(path).resolveSymbolicLinksSync();

/// Resolves the git working-tree root containing [dir]. `git diff/status`
/// report paths relative to this root (not to the current directory), so
/// monorepo sub-package runs must join staged/changed paths against it.
Future<String> gitTopLevel(String dir) async {
  final result = await Process.run(
    'git',
    const ['rev-parse', '--show-toplevel'],
    workingDirectory: dir,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      const ['rev-parse', '--show-toplevel'],
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  return '${result.stdout}'.trim();
}

/// Current crap4dart version.
const String crap4dartVersion = '0.7.1';

/// Shared CLI flag names used by multiple commands.
const String _configFlag = 'config';
const String _changedFlag = 'changed';
const String _runTestsFlag = 'run-tests';
const String _formatFlag = 'format';
const String _forceFlag = 'force';
const String _diffBaseFlag = 'diff-base';
const String _diffFlag = 'diff';
const String _stagedFlagName = 'staged';

/// Shared `--format` option values.
const String _consoleFormat = 'console';
const String _jsonFormat = 'json';

/// Option names used by a single command family.
const String _thresholdFlagName = 'threshold';
const String _lcovFlag = 'lcov';
const String _configHelp = 'Path to a crap4dart.yaml config file.';

/// Command-line entry point of crap4dart.
class Crap4DartRunner {
  /// Creates a [Crap4DartRunner].
  ///
  /// [projectRoot] overrides the project root (default: the current
  /// working directory) — used by in-process invocations and tests.
  Crap4DartRunner({String? projectRoot, ProfileRunner? profileRunner})
      : _runner = _buildRunner(projectRoot, profileRunner);

  final CommandRunner<int> _runner;

  static CommandRunner<int> _buildRunner(
    String? projectRoot,
    ProfileRunner? profileRunner,
  ) {
    final runner = CommandRunner<int>(
      'crap4dart',
      'CRAP metric analyzer for Dart and Flutter projects.',
    )
      ..addCommand(AnalyzeCommand(projectRoot: projectRoot))
      ..addCommand(CheckCommand(projectRoot: projectRoot))
      ..addCommand(ProfileCommand(
        projectRoot: projectRoot,
        profileRunner: profileRunner ?? const ProfileRunner(),
      ))
      ..addCommand(SkillCommand(projectRoot: projectRoot))
      ..addCommand(InitCommand(projectRoot: projectRoot))
      ..addCommand(InstallCommand(projectRoot: projectRoot));
    runner.argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the crap4dart version.',
    );
    return runner;
  }

  /// Runs the CLI with [args] and returns the process exit code.
  Future<int> run(List<String> args) async {
    // Bare invocation is equivalent to `crap4dart analyze`.
    if (args.isEmpty) {
      return await _runner.run(const ['analyze']) ?? ExitCodes.success;
    }
    try {
      if (args.first == '--version' || args.first == '-v') {
        stdout.writeln('crap4dart $crap4dartVersion');
        return ExitCodes.success;
      }
      return await _runner.run(args) ?? ExitCodes.success;
    } on UsageException catch (e) {
      stderr.writeln(e);
      return ExitCodes.usageError;
    }
  }
}

/// Runs `git diff` against [base], reporting failures to stderr.
Future<DiffLineMap?> _loadDiff(String projectRoot, String base) async {
  try {
    return await const GitDiffParser().diff(projectRoot, base: base);
  } on ProcessException catch (e) {
    stderr.writeln('git diff failed: ${e.message}');
    return null;
  }
}

/// Shared helpers for [AnalyzeCommand] and [CheckCommand].
mixin CommandHelpers on Command<int> {
  /// Loads the config, reporting errors to stderr and returning `null` on
  /// failure.
  Crap4DartConfig? loadConfig(String projectRoot) {
    try {
      return const ConfigLoader().load(
        projectRoot,
        configPath: argResults![_configFlag] as String?,
      );
    } on ConfigException catch (e) {
      stderr.writeln(e);
      return null;
    }
  }

  /// Resolves `--diff` / `--diff-base` and returns the diff map together with
  /// the base ref.
  Future<({DiffLineMap? map, String? base, bool ok})> resolveDiff(
    String projectRoot,
  ) async {
    final diffBase = argResults![_diffBaseFlag] as String?;
    final diffMode = (argResults![_diffFlag] as bool) || diffBase != null;
    if (!diffMode) return (map: null, base: null, ok: true);
    final changed = argResults![_changedFlag] as bool;
    final staged = stagedFlag;
    if (changed || staged || argResults!.rest.isNotEmpty) {
      throw UsageException(
        '--diff cannot be combined with --changed, --staged, or explicit paths',
        invocation,
      );
    }
    final map = await _loadDiff(projectRoot, diffBase ?? 'HEAD');
    return (map: map, base: diffBase ?? 'HEAD', ok: map != null);
  }

  /// Selects files from explicit paths, `--changed`, `--staged`, or default
  /// sources.
  Future<List<String>> selectFiles(
    String projectRoot,
    List<String> sources,
  ) async {
    const finder = SourceFinder();
    final paths = argResults!.rest;
    final changed = argResults![_changedFlag] as bool;
    final staged = stagedFlag;
    if (changed && staged) {
      throw UsageException(
        '--changed and --staged are mutually exclusive',
        invocation,
      );
    }
    if (changed || staged) {
      return findChangedFiles(projectRoot, staged: staged);
    }
    try {
      if (paths.isNotEmpty) return finder.expandPaths(paths);
      return finder.findDefaultSources(projectRoot, roots: sources);
    } on FileSystemException catch (e) {
      throw UsageException('Invalid path: ${e.path}', invocation);
    }
  }

  /// Reads the optional `--staged` flag when the command exposes it.
  bool get stagedFlag =>
      argResults!.options.contains(_stagedFlagName) &&
      argResults![_stagedFlagName] as bool;

  /// Finds changed or staged files and keeps only those inside the project
  /// root.
  Future<List<String>> findChangedFiles(
    String projectRoot, {
    required bool staged,
  }) async {
    try {
      final files =
          await const ChangedFilesFinder().find(projectRoot, staged: staged);
      final topLevel = canonicalPath(await gitTopLevel(projectRoot));
      final rootAbs = canonicalPath(projectRoot);
      return [
        for (final f in files)
          if (p.isWithin(rootAbs, p.join(topLevel, f))) p.join(topLevel, f),
      ];
    } on ProcessException catch (e) {
      throw UsageException('git failed: ${e.message}', invocation);
    }
  }

  /// Loads LCOV coverage data when the configured file exists.
  List<FileCoverage>? loadLcov(String projectRoot, Crap4DartConfig config) {
    final lcovPath = config.coverage.lcovPath;
    final resolved =
        p.isAbsolute(lcovPath) ? lcovPath : p.join(projectRoot, lcovPath);
    final file = File(resolved);
    if (!file.existsSync()) return null;
    return LcovParser(projectRoot: projectRoot).parse(file.readAsStringSync());
  }

  /// Parses a comma-separated gate id list for `--only` / `--skip`.
  Set<String>? gateFilter(String option) {
    final raw = argResults![option] as String?;
    if (raw == null) return null;
    final ids =
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    for (final id in ids) {
      if (!ConfigLoader.knownGates.contains(id)) {
        throw UsageException('Unknown gate id: "$id"', invocation);
      }
    }
    return ids;
  }

  /// Loads config, resolves diff and selects files. Returns an [exitCode] when
  /// the command should stop early; otherwise returns config/files/diff data.
  ///
  /// Pass an already loaded [config] to avoid parsing it twice when the caller
  /// needs to validate command-specific arguments before file selection.
  Future<
      ({
        Crap4DartConfig? config,
        List<String>? files,
        DiffLineMap? diffMap,
        String? diffBase,
        bool partialSelection,
        int? exitCode,
      })> prepareRun(
    String projectRoot,
    String emptyMessage, {
    Crap4DartConfig? config,
  }) async {
    final resolvedConfig = config ?? loadConfig(projectRoot);
    if (resolvedConfig == null) {
      return (
        config: null,
        files: null,
        diffMap: null,
        diffBase: null,
        partialSelection: false,
        exitCode: ExitCodes.usageError
      );
    }
    final diff = await resolveDiff(projectRoot);
    if (!diff.ok) {
      return (
        config: null,
        files: null,
        diffMap: null,
        diffBase: null,
        partialSelection: false,
        exitCode: ExitCodes.usageError
      );
    }
    final partial = _isPartialSelection(diff.map);
    final files = const SourceFinder().filterByGlobs(
      projectRoot,
      diff.map != null
          ? diff.map!.existingFiles()
          : await selectFiles(projectRoot, resolvedConfig.sources),
      resolvedConfig.exclude,
    );
    if (files.isEmpty) {
      stdout.writeln(emptyMessage);
      return (
        config: null,
        files: null,
        diffMap: null,
        diffBase: null,
        partialSelection: false,
        exitCode: ExitCodes.success
      );
    }
    return (
      config: resolvedConfig,
      files: files,
      diffMap: diff.map,
      diffBase: diff.base,
      partialSelection: partial,
      exitCode: null,
    );
  }

  /// Whether this run analyzes a subset of the project (diff, changed,
  /// staged or explicit paths) instead of the full source set.
  bool _isPartialSelection(DiffLineMap? diffMap) =>
      diffMap != null ||
      argResults![_changedFlag] as bool ||
      stagedFlag ||
      argResults!.rest.isNotEmpty;
}

/// The `analyze` command: computes CRAP scores for Dart source files.
class AnalyzeCommand extends Command<int> with CommandHelpers {
  /// Creates an [AnalyzeCommand].
  AnalyzeCommand({this.projectRoot}) {
    argParser
      ..addFlag(
        _changedFlag,
        negatable: false,
        help: 'Analyze only changed Dart files (git working tree).',
      )
      ..addOption(
        _thresholdFlagName,
        help: 'Maximum allowed CRAP score (overrides the config value).',
      )
      ..addOption(
        _lcovFlag,
        help: 'Path to an LCOV coverage file (overrides the config value).',
      )
      ..addFlag(
        _runTestsFlag,
        negatable: false,
        help: 'Run the test suite first to generate coverage.',
      )
      ..addOption(
        _configFlag,
        help: _configHelp,
      )
      ..addOption(
        _formatFlag,
        allowed: [_consoleFormat, _jsonFormat],
        defaultsTo: _consoleFormat,
        help: 'Output format (json writes only JSON to stdout).',
      )
      ..addFlag(
        _diffFlag,
        negatable: false,
        help: 'Analyze only methods on lines changed since HEAD.',
      )
      ..addOption(
        _diffBaseFlag,
        help: 'Like --diff, but diffs against the given git ref.',
      )
      ..addOption(
        'badge',
        help: 'Write an SVG badge with the max CRAP score to this path.',
      );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'analyze';

  @override
  final String description =
      'Analyze Dart files and print CRAP scores (default command).';

  @override
  String get invocation =>
      'crap4dart analyze [paths...] [--changed] [--threshold 8.0] '
      '[--lcov coverage/lcov.info] [--run-tests] [--config crap4dart.yaml]';

  @override
  Future<int> run() async {
    final projectRoot = this.projectRoot ?? Directory.current.path;
    final config = loadConfig(projectRoot);
    if (config == null) return ExitCodes.usageError;
    if (!config.crap.enabled) {
      stdout.writeln('CRAP analysis disabled in config.');
      return ExitCodes.success;
    }
    final threshold = _resolveThreshold(config);
    final prepared = await prepareRun(
      projectRoot,
      'No Dart files to analyze.',
      config: config,
    );
    if (prepared.exitCode != null) return prepared.exitCode!;
    final files = prepared.files!;
    final lcovPath = await _resolveLcov(projectRoot, config);
    if (lcovPath == null) {
      stderr.writeln(
        'Warning: no LCOV coverage data found; coverage and CRAP scores '
        'will be reported as N/A.',
      );
    }
    final report = CrapReport(
      _computeMetrics(files, lcovPath, projectRoot, config, prepared.diffMap),
    );
    _printReport(report, threshold, prepared.diffBase);
    _writeBadge(report, threshold);
    if (report.isThresholdExceeded(threshold)) {
      stderr.writeln(
        'CRAP threshold exceeded: ${report.maxCrap.toStringAsFixed(2)} > '
        '$threshold',
      );
      return ExitCodes.thresholdExceeded;
    }
    return ExitCodes.success;
  }

  List<MethodMetrics> _computeMetrics(
    List<String> files,
    String? lcovPath,
    String projectRoot,
    Crap4DartConfig config,
    DiffLineMap? diffMap,
  ) {
    var metrics = const CrapAnalyzer().analyze(
      files,
      lcovPath: lcovPath,
      projectRoot: projectRoot,
      countLambdas: config.crap.countLambdas,
    );
    if (diffMap == null) return metrics;
    return [
      for (final m in metrics)
        if (diffMap.intersects(
          m.method.filePath,
          m.method.startLine,
          m.method.endLine,
        ))
          m,
    ];
  }

  void _printReport(CrapReport report, double threshold, String? diffBase) {
    if (argResults![_formatFlag] == _jsonFormat) {
      stdout.writeln(
        const JsonReporter().renderAnalyze(
          report,
          threshold: threshold,
          diffBase: diffBase,
        ),
      );
    } else {
      stdout.writeln(
        report.render(
          threshold: threshold,
          header: diffBase == null ? null : 'Diff mode: base $diffBase',
        ),
      );
    }
  }

  /// Writes the SVG badge when `--badge` is given. Always runs — also
  /// when the threshold is exceeded — and never changes the exit code.
  void _writeBadge(CrapReport report, double threshold) {
    final badgePath = argResults!['badge'] as String?;
    if (badgePath == null) return;
    final hasNumeric = report.metrics.any((m) => m.crap != null);
    final message = hasNumeric ? report.maxCrap.toStringAsFixed(2) : 'N/A';
    final color = badgeColorFor(hasNumeric ? report.maxCrap : null, threshold);
    try {
      final file = File(badgePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        renderBadgeSvg(label: 'CRAP', message: message, colorHex: color),
      );
      stderr.writeln('Badge written to $badgePath');
      stderr.writeln('![CRAP]($badgePath)');
    } on FileSystemException catch (e) {
      stderr.writeln('Warning: could not write badge: ${e.message}');
    }
  }

  double _resolveThreshold(Crap4DartConfig config) {
    if (!argResults!.wasParsed(_thresholdFlagName)) {
      return config.crap.threshold;
    }
    final raw = argResults![_thresholdFlagName] as String;
    final value = double.tryParse(raw);
    if (value == null) {
      throw UsageException('Invalid --threshold value: "$raw"', invocation);
    }
    return value;
  }

  Future<String?> _resolveLcov(String projectRoot, Crap4DartConfig config) {
    final runTests = (argResults![_runTestsFlag] as bool) ||
        config.crap.runTests ||
        config.coverage.runTests;
    final lcovPath = argResults!.wasParsed(_lcovFlag)
        ? argResults![_lcovFlag] as String
        : config.coverage.lcovPath;
    return _resolveLcovPath(projectRoot, runTests, lcovPath);
  }

  Future<String?> _resolveLcovPath(
    String projectRoot,
    bool runTests,
    String lcovPath,
  ) async {
    if (runTests) {
      final generated = await const CoverageRunner().run(projectRoot);
      if (generated != null) return generated;
    }
    // Config-relative LCOV paths resolve against the project root.
    final resolved =
        p.isAbsolute(lcovPath) ? lcovPath : p.join(projectRoot, lcovPath);
    return File(resolved).existsSync() ? resolved : null;
  }
}

/// The `check` command: runs the quality gates enabled in the config.
class CheckCommand extends Command<int> with CommandHelpers {
  /// Creates a [CheckCommand].
  CheckCommand({this.projectRoot}) {
    argParser
      ..addFlag(
        'all',
        negatable: false,
        help: 'Check all Dart files under lib/ and bin/ (default).',
      )
      ..addFlag(
        _changedFlag,
        negatable: false,
        help: 'Check only changed Dart files (git working tree).',
      )
      ..addFlag(
        _stagedFlagName,
        negatable: false,
        help: 'Check only staged Dart files (git index).',
      )
      ..addOption('only', help: 'Run only these gates (comma-separated ids).')
      ..addOption('skip', help: 'Skip these gates (comma-separated ids).')
      ..addOption(_configFlag, help: 'Path to a crap4dart.yaml config file.')
      ..addFlag(
        _runTestsFlag,
        negatable: false,
        help: 'Run the test suite first to generate coverage.',
      )
      ..addOption(
        _formatFlag,
        allowed: [_consoleFormat, _jsonFormat],
        defaultsTo: _consoleFormat,
        help: 'Output format (json writes only JSON to stdout).',
      )
      ..addFlag(
        _diffFlag,
        negatable: false,
        help: 'Check only lines changed since HEAD (ratchet mode).',
      )
      ..addOption(
        _diffBaseFlag,
        help: 'Like --diff, but diffs against the given git ref.',
      )
      ..addFlag(
        'save-baseline',
        negatable: false,
        help: "Record current violations to $baselineFileName "
            '(future runs fail only on new violations).',
      )
      ..addFlag(
        'baseline',
        negatable: false,
        help: 'Fail only on violations not recorded in the baseline file.',
      );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'check';

  @override
  final String description = 'Run the quality gates enabled in the config.';

  @override
  String get invocation =>
      'crap4dart check [--all|--changed|--staged] [--only g1,g2] '
      '[--skip g3] [--config crap4dart.yaml]';

  @override
  Future<int> run() async {
    final projectRoot = this.projectRoot ?? Directory.current.path;
    final config = loadConfig(projectRoot);
    if (config == null) return ExitCodes.usageError;
    final only = gateFilter('only');
    final skip = gateFilter('skip');
    final prepared = await prepareRun(
      projectRoot,
      'No Dart files to check.',
      config: config,
    );
    if (prepared.exitCode != null) return prepared.exitCode!;
    final files = prepared.files!;
    if (!await _runTestsIfRequested(projectRoot, config)) {
      return ExitCodes.usageError;
    }
    final context = GateContext(
      projectRoot: projectRoot,
      config: config,
      files: files,
      lcov: loadLcov(projectRoot, config),
      partialSelection: prepared.partialSelection,
    );
    final runner = GateRunner();
    var result = await runner.run(
      context,
      only: only,
      skip: skip,
      diff: prepared.diffMap,
    );
    if (argResults!['save-baseline'] as bool) {
      final count = writeBaseline(projectRoot, result.results);
      stderr.writeln(
        'Baseline saved: $count violation(s) recorded in '
        '$baselineFileName',
      );
      _printResult(runner, result);
      return ExitCodes.success;
    }
    if (argResults!['baseline'] as bool) {
      final baseline = Baseline.load(projectRoot);
      result = GateRunResult([
        for (final gateResult in result.results)
          applyBaseline(gateResult.gateId, gateResult, baseline),
      ], diffMode: result.diffMode);
    }
    _printResult(runner, result);
    return result.passed ? ExitCodes.success : ExitCodes.thresholdExceeded;
  }

  void _printResult(GateRunner runner, GateRunResult result) {
    if (argResults![_formatFlag] == _jsonFormat) {
      stdout.writeln(const JsonReporter().renderCheck(result));
    } else {
      stdout.writeln(runner.render(result));
    }
  }

  Future<bool> _runTestsIfRequested(
    String projectRoot,
    Crap4DartConfig config,
  ) async {
    final runTests =
        (argResults![_runTestsFlag] as bool) || config.coverage.runTests;
    if (!runTests) return true;
    final generated = await const CoverageRunner().run(projectRoot);
    if (generated == null) {
      stderr.writeln('Error: test run did not produce coverage data.');
      return false;
    }
    return true;
  }
}

/// The `init` command: writes a default `crap4dart.yaml` config file.
class InitCommand extends Command<int> {
  /// Creates an [InitCommand].
  InitCommand({this.projectRoot}) {
    argParser.addFlag(
      _forceFlag,
      abbr: 'f',
      negatable: false,
      help: 'Overwrite an existing config file.',
    );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'init';

  @override
  final String description =
      'Create a default crap4dart.yaml config file in the current directory.';

  @override
  int run() {
    final root = projectRoot ?? Directory.current.path;
    final path = p.join(root, ConfigLoader.configFileName);
    final file = File(path);
    if (file.existsSync() && !(argResults![_forceFlag] as bool)) {
      stderr.writeln(
        '${ConfigLoader.configFileName} already exists '
        '(use --force to overwrite).',
      );
      return ExitCodes.usageError;
    }
    file.writeAsStringSync(defaultConfigTemplate);
    stdout.writeln('Created ${ConfigLoader.configFileName}');
    return ExitCodes.success;
  }
}

/// The `install` command: installs git hooks and CI workflow templates.
class InstallCommand extends Command<int> {
  /// Creates an [InstallCommand].
  InstallCommand({this.projectRoot}) {
    argParser
      ..addOption(
        'hook',
        defaultsTo: 'pre-commit',
        help: 'Name of the git hook to install.',
      )
      ..addFlag(
        'ci',
        negatable: false,
        help: 'Also install the GitHub Actions quality workflow.',
      )
      ..addFlag(
        _forceFlag,
        abbr: 'f',
        negatable: false,
        help: 'Merge into existing hooks / overwrite existing files.',
      )
      ..addOption(_configFlag, help: _configHelp);
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'install';

  @override
  final String description =
      'Install the pre-commit hook and (with --ci) the CI workflow.';

  @override
  Future<int> run() async {
    final projectRoot = this.projectRoot ?? Directory.current.path;
    try {
      final config = const ConfigLoader().load(
        projectRoot,
        configPath: argResults![_configFlag] as String?,
      );
      final force = argResults![_forceFlag] as bool;
      final hookPath = await const HookInstaller().installHook(
        projectRoot,
        hookName: argResults!['hook'] as String,
        force: force,
        runTests: config.coverage.runTests,
      );
      stdout.writeln('Installed git hook: ${_relative(hookPath)}');
      if (argResults!['ci'] as bool) {
        final workflowPath =
            const CiInstaller().installCi(projectRoot, force: force);
        stdout.writeln('Installed CI workflow: ${_relative(workflowPath)}');
      }
      return ExitCodes.success;
    } on ConfigException catch (e) {
      stderr.writeln(e);
      return ExitCodes.usageError;
    } on HookInstallException catch (e) {
      stderr.writeln(e);
      return ExitCodes.usageError;
    }
  }

  String _relative(String path) =>
      p.relative(path, from: projectRoot ?? Directory.current.path);
}
