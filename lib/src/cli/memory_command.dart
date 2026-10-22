import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'exit_codes.dart';
import '../memory/memory_profiler.dart';

/// The `memory` command: runs the test suite under `--verbose_gc`,
/// attributes GC events and reclaimed memory to tests, and reports the
/// allocation churn / old-gen growth hotspots.
///
/// Informational: always exits 0; thresholds and the `memory_pressure`
/// gate come separately (they need baseline machinery to be honest —
/// raw GC counts are machine-dependent, allocated MB are not).
class MemoryCommand extends Command<int> {
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
        _formatOption,
        allowed: ['console', 'json'],
        defaultsTo: 'console',
        help: 'Output format.',
      );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  final MemoryProfiler _profiler;

  @override
  final String name = 'memory';

  @override
  final String description = 'Run the test suite under --verbose_gc and '
      'report per-test allocation churn and GC pressure.';

  @override
  Future<int> run() async {
    final root = projectRoot ?? Directory.current.path;
    if (!_isDartProject(root)) {
      stderr.writeln(_noSuiteMessage(root));
      return ExitCodes.usageError;
    }
    stderr.writeln('Running dart --verbose_gc test (this may take a while)');
    final report = await _profiler.profile(root, argResults!.rest);
    if (report.testCount == 0) {
      stderr.writeln('memory: no tests executed');
      return ExitCodes.usageError;
    }
    _printReport(report);
    return ExitCodes.success;
  }

  /// The error text for a directory without a runnable Dart suite.
  String _noSuiteMessage(String root) =>
      'memory: no Dart test suite found in $root '
      '(the memory profiler runs `dart test`; Flutter projects are '
      'not supported yet)';

  /// Prints the report in the selected format.
  void _printReport(MemoryReport report) {
    final top = int.tryParse(argResults![_topOption] as String) ?? 20;
    if (argResults![_formatOption] == 'json') {
      _printJson(report);
    } else {
      _printConsole(report, top);
    }
  }

  /// Whether [root] looks like a Dart project (pubspec, no flutter
  /// dependency requirement — that check needs resolution, keep it
  /// light).
  bool _isDartProject(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    return pubspec.existsSync() && Directory(p.join(root, 'test')).existsSync();
  }

  /// The console report.
  void _printConsole(MemoryReport report, int top) {
    stdout.writeln(
      'memory: ${report.testCount} tests, ${report.totalGcs.length} GCs, '
      'churn ${report.totalChurnMb.toStringAsFixed(1)} MB new-gen, '
      'old-gen ${report.totalOldGrowthMb >= 0 ? '+' : ''}'
      '${report.totalOldGrowthMb.toStringAsFixed(1)} MB',
    );
    stdout.writeln('');
    stdout.writeln('top $top by allocation churn (reclaimed new-gen MB):');
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
      '  ${'GCs'.padLeft(5)}  ${'churn MB'.padLeft(9)}  '
      '${'old Δ MB'.padLeft(9)}  test',
    );
    for (final entry in entries) {
      stdout.writeln(
        '${entry.gcs.length.toString().padLeft(7)}  '
        '${entry.churnNewMb.toStringAsFixed(1).padLeft(9)}  '
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
        'totalChurnMb': _round1(report.totalChurnMb),
        'totalOldGrowthMb': _round1(report.totalOldGrowthMb),
        'clockOffsetSeconds': report.clockOffsetSeconds,
        'suites': [
          for (final suite in report.suites) suite.toJson(),
        ],
        'tests': [
          for (final test in report.tests) test.toJson(),
        ],
      }),
    );
  }

  static double _round1(double value) => double.parse(value.toStringAsFixed(1));
}

const String _topOption = 'top';
const String _formatOption = 'format';
