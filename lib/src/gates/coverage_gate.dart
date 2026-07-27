import '../coverage/lcov_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `test_coverage` gate: enforces `gates.test_coverage.min_percent`
/// line coverage computed from the loaded LCOV data, aggregated over the
/// files under `gates.test_coverage.dirs` (default: `lib`).
class CoverageGate implements Gate {
  /// Creates a [CoverageGate].
  const CoverageGate();

  @override
  String get id => 'test_coverage';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.testCoverage;
    final lcov = context.lcov;
    if (lcov == null) {
      final lcovPath = context.config.coverage.lcovPath;
      if (context.config.coverage.required) {
        return GateResult.fail(id, [
          GateViolation(
            file: lcovPath,
            message: 'no coverage data at $lcovPath',
          ),
        ]);
      }
      return GateResult.skip(id, 'no coverage data at $lcovPath');
    }
    final scopedFiles = [
      for (final f in lcov)
        if (_isUnderDirs(f.path, config.dirs)) f,
    ];
    final totals = _totals(scopedFiles);
    final percent = totals.found == 0 ? 100.0 : totals.hit / totals.found * 100;
    final passed = percent >= config.minPercent;
    final comparison = passed ? '>=' : '<';
    final summary =
        'coverage ${_fmt(percent)}% $comparison ${_fmt(config.minPercent)}%';
    if (passed) {
      return GateResult.pass(id, summary: summary);
    }
    final violations = <GateViolation>[
      GateViolation(
        file: config.dirs.join(', '),
        message:
            'total coverage ${_fmt(percent)}% < min ${_fmt(config.minPercent)}%',
      ),
    ];
    if (config.perFile) {
      violations.addAll(_perFileViolations(scopedFiles, config.minPercent));
    }
    return GateResult.fail(id, violations, summary: summary);
  }

  bool _isUnderDirs(String path, List<String> dirs) => dirs.any(
        (dir) => path == dir || path.startsWith('$dir/'),
      );

  List<GateViolation> _perFileViolations(
    List<FileCoverage> files,
    double minPercent,
  ) =>
      [
        for (final file in files)
          if (_percent(file) < minPercent)
            GateViolation(
              file: file.path,
              message:
                  'coverage ${_fmt(_percent(file))}% < min ${_fmt(minPercent)}%',
            ),
      ];

  ({int hit, int found}) _totals(List<FileCoverage> files) {
    var hit = 0;
    var found = 0;
    for (final file in files) {
      for (final hits in file.lineHits.values) {
        found++;
        if (hits > 0) hit++;
      }
    }
    return (hit: hit, found: found);
  }

  double _percent(FileCoverage file) {
    if (file.lineHits.isEmpty) return 100.0;
    final covered = file.lineHits.values.where((h) => h > 0).length;
    return covered / file.lineHits.length * 100;
  }

  static String _fmt(double value) => value.toStringAsFixed(1);
}
