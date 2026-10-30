import '../common/constants.dart';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'exit_codes.dart';
import '../memory/flutter_memory.dart';
import '../memory/memory_profiler.dart';
import '../report/badge_svg.dart';

/// The `memory` command: runs the test suite under `--verbose_gc`,
/// attributes GC events and reclaimed memory to tests, and reports the
/// allocation churn / old-gen growth hotspots.
///
/// Informational: always exits 0; thresholds and the `memory_pressure`
/// gate come separately (they need baseline machinery to be honest —
/// raw GC counts are machine-dependent, allocated MB are not).
class MemoryCommand extends Command<int> {
  /// Project root override (default: the current working directory).
  final String? projectRoot;

  final MemoryProfiler _profiler;

  @override
  final String name = 'memory';

  @override
  final String description = 'Run the test suite under --verbose_gc and '
      'report per-test allocation churn and GC pressure.';

  /// Creates a [MemoryCommand].
  MemoryCommand({this.projectRoot, MemoryProfiler? profiler})
      : _profiler = profiler ?? MemoryProfiler() {
    argParser
      ..addOption(
        _topOption,
        defaultsTo: '20',
        help: 'How many entries per leaderboard to print.',
      )
      ..addOption(
        kFormat,
        allowed: [kConsole, kJson],
        defaultsTo: kConsole,
        help: kOutputFormatHelp,
      )
      ..addOption(
        kBadge,
        help: 'Write a shields-style SVG badge with the suite churn '
            'to this path (green below, yellow at most twice, red over '
            'the --badge-threshold MB).',
      )
      ..addOption(
        _engineOption,
        allowed: ['auto', kDart, kFlutter],
        defaultsTo: 'auto',
        help: 'Test engine: auto-detects Flutter from pubspec.yaml. '
            'Flutter mode rides `flutter test --verbose` and re-runs each '
            'spawned flutter_tester with --verbose_gc (files run twice).',
      )
      ..addOption(
        _badgeThresholdOption,
        defaultsTo: '500',
        help: 'Churn threshold (MB) for the badge color.',
      );
  }

  static double _round1(double value) => double.parse(value.toStringAsFixed(1));

  @override
  Future<int> run() async {
    var root = projectRoot ?? Directory.current.path;
    final rest = argResults!.rest;
    var engine = _resolveEngine(root);
    if (engine == kNoEngine && rest.isNotEmpty) {
      // Workspace-root invocation with explicit test paths: derive the
      // package root from the paths themselves.
      root = inferPackageRoot(root, rest) ?? root;
      engine = _resolveEngine(root);
    }
    if (engine == kNoEngine) {
      stderr.writeln(_noSuiteMessage(root));
      return ExitCodes.usageError;
    }
    final report = engine == kFlutter
        ? await _profileFlutter(root, rest)
        : await _profileDart(root);
    if (report.testCount == 0) {
      stderr.writeln('memory: no tests executed');
      return ExitCodes.usageError;
    }
    _printReport(report);
    _maybeWriteBadge(report);
    return ExitCodes.success;
  }

  /// `dart`, `flutter`, or `none` (no suite at all).
  String _resolveEngine(String root) {
    final chosen = argResults![_engineOption] as String?;
    final isFlutter = _isFlutterProject(root);
    if (chosen == kDart || chosen == kFlutter) return chosen!;
    if (_isDartProject(root) || isFlutter) {
      return isFlutter ? kFlutter : kDart;
    }
    return kNoEngine;
  }

  /// The dart-engine path (dart --verbose_gc test).
  Future<MemoryReport> _profileDart(String root) async {
    stderr.writeln('Running dart --verbose_gc test (this may take a while)');
    return _profiler.profile(root, argResults!.rest);
  }

  /// The flutter-engine path: rides flutter test --verbose, measuring
  /// every spawned flutter_tester (each file runs twice). Positional
  /// [testPaths] forward to `flutter test` for targeted measurement.
  Future<MemoryReport> _profileFlutter(
    String root,
    List<String> testPaths,
  ) async {
    final missing = missingTestPaths(root, testPaths);
    if (missing.isNotEmpty) {
      stderr.writeln('memory: test path(s) not found: ${missing.join(', ')}');
      return emptyMemoryReport();
    }
    stderr.writeln(
      'Running flutter test (each file executes twice: the tool run '
      'plus the measured copy) — this may take a while',
    );
    return runFlutterMemory(root, stderr.writeln, testPaths: testPaths);
  }

  /// Whether [root] declares the Flutter SDK dependency.
  bool _isFlutterProject(String root) {
    final pubspec = File(p.join(root, kPubspec));
    if (!pubspec.existsSync()) return false;
    return pubspec.readAsStringSync().contains(
          RegExp('^  flutter:\\s*\$', multiLine: true),
        );
  }

  /// Writes the SVG badge when --badge was given.
  void _maybeWriteBadge(MemoryReport report) {
    final path = argResults![kBadge] as String?;
    if (path == null || path.isEmpty) return;
    final threshold =
        double.tryParse(argResults![_badgeThresholdOption] as String) ?? 500;
    final churn =
        report.churnAvailable ? report.totalChurnMb : report.totalAllocatedMb;
    final color = churn <= threshold
        ? BadgeColors.green
        : churn <= 2 * threshold
            ? BadgeColors.yellow
            : BadgeColors.red;
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        renderBadgeSvg(
          label: 'memory churn',
          message: '${churn.round()} MB',
          colorHex: color,
        ),
      );
    stderr.writeln('Badge written to $path');
  }

  /// The error text for a directory without a runnable suite.
  String _noSuiteMessage(String root) =>
      'memory: no Dart or Flutter test suite found in $root';

  /// Prints the report in the selected format.
  void _printReport(MemoryReport report) {
    final top = int.tryParse(argResults![_topOption] as String) ?? 20;
    if (argResults![kFormat] == kJson) {
      _printJson(report);
    } else {
      _printConsole(report, top);
    }
  }

  /// Whether [root] looks like a Dart project (pubspec, no flutter
  /// dependency requirement — that check needs resolution, keep it
  /// light).
  bool _isDartProject(String root) {
    final pubspec = File(p.join(root, kPubspec));
    return pubspec.existsSync() && Directory(p.join(root, kTest)).existsSync();
  }

  /// The console report.
  void _printConsole(MemoryReport report, int top) {
    stdout.writeln(
      'memory: ${report.testCount} tests, ${report.totalGcs.length} GCs, '
      '${report.churnAvailable ? 'churn ${report.totalChurnMb.toStringAsFixed(1)} MB new-gen, ' : 'new-gen churn unavailable (VM stream has no reclaimed counters), '}'
      'old-gen ${report.totalOldGrowthMb >= 0 ? '+' : ''}'
      '${report.totalOldGrowthMb.toStringAsFixed(1)} MB'
      '${report.totalAllocatedMb > 0 ? ', allocated ${report.totalAllocatedMb.toStringAsFixed(1)} MB' : ''}',
    );
    stdout.writeln('');
    stdout.writeln('top $top by allocation volume '
        '(allocated MB; reclaimed new-gen MB on the Dart engine):');
    _printTable(report.topChurn.take(top).toList());
    stdout.writeln('');
    stdout.writeln('top $top by old-gen growth (leak suspects first):');
    _printTable(report.topOldGrowth.take(top).toList());
  }

  /// One leaderboard block.
  void _printTable(List<MemoryEntry> entries) {
    if (entries.isEmpty) {
      stdout.writeln('  (no GC activity)');
      return;
    }
    stdout.writeln(
      '  ${'GCs'.padLeft(5)}  ${'alloc MB'.padLeft(9)}  '
      '${'old Δ MB'.padLeft(9)}  test',
    );
    for (final entry in entries) {
      stdout.writeln(
        '${entry.gcs.length.toString().padLeft(7)}  '
        '${entry.allocatedMb.toStringAsFixed(1).padLeft(9)}  '
        '${entry.oldGrowthMb.toStringAsFixed(1).padLeft(9)}  '
        '${entry.label}',
      );
    }
  }

  /// The JSON report (stdout stays JSON-only).
  void _printJson(MemoryReport report) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'testCount': report.testCount,
        'gcCount': report.totalGcs.length,
        'churnAvailable': report.churnAvailable,
        'totalChurnMb':
            report.churnAvailable ? _round1(report.totalChurnMb) : null,
        'totalAllocatedMb': _round1(report.totalAllocatedMb),
        'totalOldGrowthMb': _round1(report.totalOldGrowthMb),
        'suites': [
          for (final suite in report.suites) suite.toJson(),
        ],
        'tests': [
          for (final test in report.tests) test.toJson(),
        ],
      }),
    );
  }
}

/// Positional test paths that resolve to neither a file nor a
/// directory (relative to [root] or absolute) — surfaced as a usage
/// error instead of silently measuring nothing.
List<String> missingTestPaths(String root, List<String> paths) => [
      for (final path in paths)
        if (!File(p.join(root, path)).existsSync() &&
            !File(path).existsSync() &&
            !Directory(p.join(root, path)).existsSync())
          path,
    ];

/// An empty report for early-exit paths (nothing measured yet).
MemoryReport emptyMemoryReport() => MemoryReport(
      testCount: 0,
      totalGcs: const [],
      suites: const [],
      tests: const [],
      unattributedGcs: const [],
    );

/// Derives a package root from explicit test paths: walks up from the
/// first path's directory to the nearest pubspec. Returns null when
/// the filesystem root is reached without one.
String? inferPackageRoot(String root, List<String> paths) {
  var dir = File(p.join(root, paths.first)).parent.path;
  if (!Directory(dir).existsSync()) dir = File(paths.first).parent.path;
  for (var candidate = dir;; candidate = p.dirname(candidate)) {
    if (File(p.join(candidate, 'pubspec.yaml')).existsSync()) {
      return candidate;
    }
    if (candidate == p.dirname(candidate)) return null;
  }
}

const String _topOption = 'top';
const String _engineOption = 'engine';
const String _badgeThresholdOption = 'badge-threshold';
