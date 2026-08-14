import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../analysis/method_extractor.dart';
import '../config/config.dart';
import '../files/diff_parser.dart';
import '../profile/profile_runner.dart';
import '../profile/profile_reporter.dart';
import '../report/json_reporter.dart';
import 'exit_codes.dart';
import 'runner.dart';

/// The `profile` command: runs the test suite against instrumented source
/// code and reports per-method timing data.
class ProfileCommand extends Command<int> with CommandHelpers {
  /// Creates a [ProfileCommand].
  ProfileCommand(
      {this.projectRoot, this.profileRunner = const ProfileRunner()}) {
    argParser
      ..addFlag(
        'changed',
        negatable: false,
        help: 'Profile only changed Dart files (git working tree).',
      )
      ..addFlag(
        'staged',
        negatable: false,
        help: 'Profile only staged Dart files (git index).',
      )
      ..addOption(
        'threshold',
        help: 'Warn on methods above this total time in milliseconds.',
      )
      ..addOption(
        'top',
        help: 'Show only the top N methods (default: all).',
      )
      ..addOption(
        'name',
        help: 'Run only tests matching this name (substring or regex).',
      )
      ..addOption(
        'tags',
        help: 'Run only tests with these tags (comma-separated).',
      )
      ..addOption(
        'exclude-tags',
        help: 'Exclude tests with these tags (comma-separated).',
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
        help: 'Profile only methods on lines changed since HEAD.',
      )
      ..addOption(
        'diff-base',
        help: 'Like --diff, but diffs against the given git ref.',
      );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  /// Test runner used to execute the instrumented test suite; tests
  /// inject a fake so no real `dart test` subprocess is spawned.
  final ProfileRunner profileRunner;

  @override
  final String name = 'profile';

  @override
  final description = 'Run instrumented tests and report per-method timing.';

  @override
  String get invocation => 'crap4dart profile [options] [test_paths...]\n'
      '\n'
      'Examples:\n'
      '  crap4dart profile                          # all tests\n'
      '  crap4dart profile test/collab/             # specific dir\n'
      '  crap4dart profile --name "golden"          # by test name\n'
      '  crap4dart profile --tags "integration"     # by tag\n'
      '  crap4dart profile --threshold 10.0 --top 20\n'
      '  crap4dart profile --format json > prof.json';

  @override
  Future<int> run() async {
    final root = projectRoot ?? Directory.current.path;
    final config = loadConfig(root);
    if (config == null) return ExitCodes.usageError;
    if (!config.profile.enabled) {
      stdout.writeln('Profiling disabled in config.');
      return ExitCodes.success;
    }
    final thresholdMs = _resolveThreshold(config);
    final top = _resolveTop(config);
    final prepared = await prepareRun(
      root,
      'No Dart files to profile.',
      config: config,
    );
    if (prepared.exitCode != null) return prepared.exitCode!;
    final files = prepared.files!;

    // Run instrumented tests.
    final filter = TestFilter(
      name: argResults!['name'] as String?,
      tags: _csvToList(argResults!['tags'] as String?),
      excludeTags: _csvToList(argResults!['exclude-tags'] as String?),
      paths: argResults!.rest,
    );
    final result = await profileRunner.run(root, filter: filter);
    if (result == null) {
      stderr.writeln('Profiling did not produce any results.');
      return ExitCodes.usageError;
    }

    // Parse source files for MethodInfo (for file:line attribution).
    final methods = _extractMethods(files);
    final profiles =
        const ProfileAttributor().attribute(result.timings, methods);
    final filtered = _filterByDiff(profiles, prepared.diffMap);

    final report = ProfileReport(profiles: filtered);

    // Always write full report files for later analysis.
    _writeReportFiles(report, thresholdMs, prepared.diffBase, root);

    _printReport(report, thresholdMs, top, prepared.diffBase);

    if (thresholdMs != null) {
      final exceeding =
          filtered.where((p) => p.timing.totalMillis > thresholdMs);
      if (exceeding.isNotEmpty) {
        return ExitCodes.thresholdExceeded;
      }
    }
    return ExitCodes.success;
  }

  /// Parses all [files] and extracts [MethodInfo] for each.
  List<MethodInfo> _extractMethods(List<String> files) {
    final parser = DartParser();
    const extractor = MethodExtractor();
    final methods = <MethodInfo>[];
    for (final filePath in files) {
      final content = File(filePath).readAsStringSync();
      final parsed = parser.parse(content: content, path: filePath);
      methods.addAll(
        extractor.extract(parsed.unit, parsed.lineInfo, filePath: filePath),
      );
    }
    return methods;
  }

  /// Filters [profiles] to only those intersecting [diffMap].
  List<MethodProfile> _filterByDiff(
    List<MethodProfile> profiles,
    DiffLineMap? diffMap,
  ) {
    if (diffMap == null) return profiles;
    return [
      for (final p in profiles)
        if (diffMap.intersects(
          p.method.filePath,
          p.method.startLine,
          p.method.endLine,
        ))
          p,
    ];
  }

  /// Writes full (untruncated) report files for later analysis by agents
  /// or CI. Files are written to `<root>/profile-report.txt` and
  /// `<root>/profile-report.json`.
  void _writeReportFiles(
    ProfileReport report,
    double? thresholdMs,
    String? diffBase,
    String root,
  ) {
    final dir = p.join(root, 'profile-reports');
    Directory(dir).createSync(recursive: true);
    final txtPath = p.join(dir, 'profile-report.txt');
    final jsonPath = p.join(dir, 'profile-report.json');
    try {
      File(txtPath).writeAsStringSync(
        report.render(
          thresholdMs: thresholdMs,
          header: diffBase == null ? null : 'Diff mode: base $diffBase',
        ),
      );
      File(jsonPath).writeAsStringSync(
        const JsonReporter().renderProfile(
          report,
          thresholdMs: thresholdMs,
        ),
      );
      stderr.writeln('Full report saved to $dir/');
    } on FileSystemException catch (e) {
      stderr.writeln('Warning: could not write report files: ${e.message}');
    }
  }

  void _printReport(
    ProfileReport report,
    double? thresholdMs,
    int? top,
    String? diffBase,
  ) {
    if (argResults!['format'] == 'json') {
      stdout.writeln(
        const JsonReporter().renderProfile(
          report,
          thresholdMs: thresholdMs,
          top: top,
        ),
      );
    } else {
      stdout.writeln(
        report.render(
          thresholdMs: thresholdMs,
          top: top,
          header: diffBase == null ? null : 'Diff mode: base $diffBase',
        ),
      );
    }
  }

  double? _resolveThreshold(Crap4DartConfig config) {
    if (argResults!.wasParsed('threshold')) {
      final raw = argResults!['threshold'] as String;
      final value = double.tryParse(raw);
      if (value == null) {
        throw UsageException(
          'Invalid --threshold value: "$raw"',
          invocation,
        );
      }
      return value;
    }
    return config.profile.thresholdMs;
  }

  int? _resolveTop(Crap4DartConfig config) {
    if (argResults!.wasParsed('top')) {
      final raw = argResults!['top'] as String?;
      if (raw == null) return null;
      final value = int.tryParse(raw);
      if (value == null || value < 0) {
        throw UsageException('Invalid --top value: "$raw"', invocation);
      }
      return value;
    }
    return config.profile.top;
  }

  /// Splits a comma-separated string into a list, or returns null.
  List<String>? _csvToList(String? value) {
    if (value == null || value.isEmpty) return null;
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
