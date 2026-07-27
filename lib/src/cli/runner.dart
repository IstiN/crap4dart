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
import '../gates/gate_context.dart';
import '../gates/gate_runner.dart';
import '../hooks/ci_installer.dart';
import '../hooks/hook_installer.dart';
import '../report/json_reporter.dart';
import 'exit_codes.dart';

/// Current crap4dart version.
const String crap4dartVersion = '0.1.1';

/// Command-line entry point of crap4dart.
class Crap4DartRunner {
  /// Creates a [Crap4DartRunner].
  Crap4DartRunner() : _runner = _buildRunner();

  final CommandRunner<int> _runner;

  static CommandRunner<int> _buildRunner() {
    final runner = CommandRunner<int>(
      'crap4dart',
      'CRAP metric analyzer for Dart and Flutter projects.',
    )
      ..addCommand(AnalyzeCommand())
      ..addCommand(CheckCommand())
      ..addCommand(InitCommand())
      ..addCommand(InstallCommand());
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

/// The `analyze` command: computes CRAP scores for Dart source files.
class AnalyzeCommand extends Command<int> {
  /// Creates an [AnalyzeCommand].
  AnalyzeCommand() {
    argParser
      ..addFlag(
        'changed',
        negatable: false,
        help: 'Analyze only changed Dart files (git working tree).',
      )
      ..addOption(
        'threshold',
        help: 'Maximum allowed CRAP score (overrides the config value).',
      )
      ..addOption(
        'lcov',
        help: 'Path to an LCOV coverage file (overrides the config value).',
      )
      ..addFlag(
        'run-tests',
        negatable: false,
        help: 'Run the test suite first to generate coverage.',
      )
      ..addOption(
        'config',
        help: 'Path to a crap4dart.yaml config file.',
      )
      ..addOption(
        'format',
        allowed: ['console', 'json'],
        defaultsTo: 'console',
        help: 'Output format (json writes only JSON to stdout).',
      )
      ..addFlag(
        'diff',
        negatable: false,
        help: 'Analyze only methods on lines changed since HEAD.',
      )
      ..addOption(
        'diff-base',
        help: 'Like --diff, but diffs against the given git ref.',
      );
  }

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
    final projectRoot = Directory.current.path;
    final config = _loadConfig(projectRoot);
    if (config == null) return ExitCodes.usageError;
    if (!config.crap.enabled) {
      stdout.writeln('CRAP analysis disabled in config.');
      return ExitCodes.success;
    }
    final threshold = _resolveThreshold(config);
    final diff = await _resolveDiff(projectRoot);
    if (!diff.ok) return ExitCodes.usageError;
    final files = const SourceFinder().filterByGlobs(
      projectRoot,
      diff.map != null
          ? diff.map!.existingFiles()
          : await _selectFiles(projectRoot, config.sources),
      config.exclude,
    );
    if (files.isEmpty) {
      stdout.writeln('No Dart files to analyze.');
      return ExitCodes.success;
    }
    final lcovPath = await _resolveLcov(projectRoot, config);
    if (lcovPath == null) {
      stderr.writeln(
        'Warning: no LCOV coverage data found; coverage and CRAP scores '
        'will be reported as N/A.',
      );
    }
    final report = CrapReport(
      _computeMetrics(files, lcovPath, projectRoot, config, diff.map),
    );
    _printReport(report, threshold, diff.base);
    if (report.isThresholdExceeded(threshold)) {
      stderr.writeln(
        'CRAP threshold exceeded: ${report.maxCrap.toStringAsFixed(2)} > '
        '$threshold',
      );
      return ExitCodes.thresholdExceeded;
    }
    return ExitCodes.success;
  }

  Future<({DiffLineMap? map, String? base, bool ok})> _resolveDiff(
    String projectRoot,
  ) async {
    final diffBase = argResults!['diff-base'] as String?;
    final diffMode = (argResults!['diff'] as bool) || diffBase != null;
    if (!diffMode) return (map: null, base: null, ok: true);
    if ((argResults!['changed'] as bool) || argResults!.rest.isNotEmpty) {
      throw UsageException(
        '--diff cannot be combined with --changed or explicit paths',
        invocation,
      );
    }
    final map = await _loadDiff(projectRoot, diffBase ?? 'HEAD');
    return (map: map, base: diffBase ?? 'HEAD', ok: map != null);
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
    if (argResults!['format'] == 'json') {
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

  Crap4DartConfig? _loadConfig(String projectRoot) {
    try {
      return const ConfigLoader().load(
        projectRoot,
        configPath: argResults!['config'] as String?,
      );
    } on ConfigException catch (e) {
      stderr.writeln(e);
      return null;
    }
  }

  double _resolveThreshold(Crap4DartConfig config) {
    if (!argResults!.wasParsed('threshold')) return config.crap.threshold;
    final raw = argResults!['threshold'] as String;
    final value = double.tryParse(raw);
    if (value == null) {
      throw UsageException('Invalid --threshold value: "$raw"', invocation);
    }
    return value;
  }

  Future<List<String>> _selectFiles(
    String projectRoot,
    List<String> sources,
  ) async {
    const finder = SourceFinder();
    final paths = argResults!.rest;
    try {
      if (argResults!['changed'] as bool) {
        return const ChangedFilesFinder().find(projectRoot);
      }
      if (paths.isNotEmpty) return finder.expandPaths(paths);
      return finder.findDefaultSources(projectRoot, roots: sources);
    } on FileSystemException catch (e) {
      throw UsageException('Invalid path: ${e.path}', invocation);
    } on ProcessException catch (e) {
      throw UsageException('git failed: ${e.message}', invocation);
    }
  }

  Future<String?> _resolveLcov(String projectRoot, Crap4DartConfig config) {
    final runTests = (argResults!['run-tests'] as bool) ||
        config.crap.runTests ||
        config.coverage.runTests;
    final lcovPath = argResults!.wasParsed('lcov')
        ? argResults!['lcov'] as String
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
    return File(lcovPath).existsSync() ? lcovPath : null;
  }
}

/// The `check` command: runs the quality gates enabled in the config.
class CheckCommand extends Command<int> {
  /// Creates a [CheckCommand].
  CheckCommand() {
    argParser
      ..addFlag(
        'all',
        negatable: false,
        help: 'Check all Dart files under lib/ and bin/ (default).',
      )
      ..addFlag(
        'changed',
        negatable: false,
        help: 'Check only changed Dart files (git working tree).',
      )
      ..addFlag(
        'staged',
        negatable: false,
        help: 'Check only staged Dart files (git index).',
      )
      ..addOption('only', help: 'Run only these gates (comma-separated ids).')
      ..addOption('skip', help: 'Skip these gates (comma-separated ids).')
      ..addOption('config', help: 'Path to a crap4dart.yaml config file.')
      ..addFlag(
        'run-tests',
        negatable: false,
        help: 'Run the test suite first to generate coverage.',
      )
      ..addOption(
        'format',
        allowed: ['console', 'json'],
        defaultsTo: 'console',
        help: 'Output format (json writes only JSON to stdout).',
      )
      ..addFlag(
        'diff',
        negatable: false,
        help: 'Check only lines changed since HEAD (ratchet mode).',
      )
      ..addOption(
        'diff-base',
        help: 'Like --diff, but diffs against the given git ref.',
      );
  }

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
    final projectRoot = Directory.current.path;
    final config = _loadConfigOrReport(projectRoot);
    if (config == null) return ExitCodes.usageError;
    final diffBase = argResults!['diff-base'] as String?;
    final diffMode = (argResults!['diff'] as bool) || diffBase != null;
    DiffLineMap? diffMap;
    if (diffMode) {
      if ((argResults!['changed'] as bool) || (argResults!['staged'] as bool)) {
        throw UsageException(
          '--diff cannot be combined with --changed/--staged',
          invocation,
        );
      }
      diffMap = await _loadDiff(projectRoot, diffBase ?? 'HEAD');
      if (diffMap == null) return ExitCodes.usageError;
    }
    final files = const SourceFinder().filterByGlobs(
      projectRoot,
      diffMap != null
          ? diffMap.existingFiles()
          : await _selectFiles(projectRoot, config.sources),
      config.exclude,
    );
    if (files.isEmpty) {
      stdout.writeln('No Dart files to check.');
      return ExitCodes.success;
    }
    if (!await _runTestsIfRequested(projectRoot, config)) {
      return ExitCodes.usageError;
    }
    final context = GateContext(
      projectRoot: projectRoot,
      config: config,
      files: files,
      lcov: _loadLcov(projectRoot, config),
    );
    final runner = GateRunner();
    final result = await runner.run(
      context,
      only: _gateFilter('only'),
      skip: _gateFilter('skip'),
      diff: diffMap,
    );
    if (argResults!['format'] == 'json') {
      stdout.writeln(const JsonReporter().renderCheck(result));
    } else {
      stdout.writeln(runner.render(result));
    }
    return result.passed ? ExitCodes.success : ExitCodes.thresholdExceeded;
  }

  Future<bool> _runTestsIfRequested(
    String projectRoot,
    Crap4DartConfig config,
  ) async {
    final runTests =
        (argResults!['run-tests'] as bool) || config.coverage.runTests;
    if (!runTests) return true;
    final generated = await const CoverageRunner().run(projectRoot);
    if (generated == null) {
      stderr.writeln('Error: test run did not produce coverage data.');
      return false;
    }
    return true;
  }

  Crap4DartConfig? _loadConfigOrReport(String projectRoot) {
    try {
      return const ConfigLoader().load(
        projectRoot,
        configPath: argResults!['config'] as String?,
      );
    } on ConfigException catch (e) {
      stderr.writeln(e);
      return null;
    }
  }

  Future<List<String>> _selectFiles(
    String projectRoot,
    List<String> sources,
  ) async {
    final changed = argResults!['changed'] as bool;
    final staged = argResults!['staged'] as bool;
    if (changed && staged) {
      throw UsageException(
        '--changed and --staged are mutually exclusive',
        invocation,
      );
    }
    try {
      if (changed) return const ChangedFilesFinder().find(projectRoot);
      if (staged) {
        return const ChangedFilesFinder().find(projectRoot, staged: true);
      }
      return const SourceFinder()
          .findDefaultSources(projectRoot, roots: sources);
    } on ProcessException catch (e) {
      throw UsageException('git failed: ${e.message}', invocation);
    }
  }

  List<FileCoverage>? _loadLcov(String projectRoot, Crap4DartConfig config) {
    final file = File(config.coverage.lcovPath);
    if (!file.existsSync()) return null;
    return LcovParser(projectRoot: projectRoot).parse(file.readAsStringSync());
  }

  Set<String>? _gateFilter(String option) {
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
}

/// The `init` command: writes a default `crap4dart.yaml` config file.
class InitCommand extends Command<int> {
  /// Creates an [InitCommand].
  InitCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite an existing config file.',
    );
  }

  @override
  final String name = 'init';

  @override
  final String description =
      'Create a default crap4dart.yaml config file in the current directory.';

  @override
  int run() {
    final path = p.join(Directory.current.path, ConfigLoader.configFileName);
    final file = File(path);
    if (file.existsSync() && !(argResults!['force'] as bool)) {
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
  InstallCommand() {
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
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Merge into existing hooks / overwrite existing files.',
      )
      ..addOption('config', help: 'Path to a crap4dart.yaml config file.');
  }

  @override
  final String name = 'install';

  @override
  final String description =
      'Install the pre-commit hook and (with --ci) the CI workflow.';

  @override
  Future<int> run() async {
    final projectRoot = Directory.current.path;
    try {
      final config = const ConfigLoader().load(
        projectRoot,
        configPath: argResults!['config'] as String?,
      );
      final force = argResults!['force'] as bool;
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
      p.relative(path, from: Directory.current.path);
}
