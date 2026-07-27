import 'crap_analyzer.dart';

/// Default CRAP threshold (matches the Java reference implementation).
const double defaultCrapThreshold = 8.0;

/// Renders CRAP analysis results as a console table.
class CrapReport {
  /// Creates a [CrapReport] for [metrics].
  const CrapReport(this.metrics);

  /// The analyzed method metrics.
  final List<MethodMetrics> metrics;

  /// Column headers of the report table.
  static const List<String> headers = [
    'CRAP',
    'COV%',
    'BR%',
    'CC',
    'METHOD',
    'FILE:LINE',
  ];

  /// Metrics sorted for display: numeric CRAP descending, then N/A entries.
  List<MethodMetrics> get sorted {
    final copy = List<MethodMetrics>.of(metrics);
    copy.sort((a, b) {
      final aCrap = a.crap;
      final bCrap = b.crap;
      if (aCrap == null && bCrap == null) return 0;
      if (aCrap == null) return 1;
      if (bCrap == null) return -1;
      return bCrap.compareTo(aCrap);
    });
    return copy;
  }

  /// Maximum numeric CRAP score, or `0.0` when no numeric scores exist.
  double get maxCrap {
    var max = 0.0;
    for (final m in metrics) {
      final crap = m.crap;
      if (crap != null && crap > max) max = crap;
    }
    return max;
  }

  /// Whether the maximum CRAP score exceeds [threshold].
  bool isThresholdExceeded(double threshold) => maxCrap > threshold;

  /// Renders the report table as a string, optionally prefixed with a
  /// [header] line (e.g. the diff-mode marker).
  String render({double threshold = defaultCrapThreshold, String? header}) {
    final rows = sorted.map(_rowFor).toList();
    final widths = List.generate(headers.length, (i) => headers[i].length);
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }
    final buffer = StringBuffer();
    if (header != null) buffer.writeln(header);
    buffer.writeln(_formatRow(headers, widths));
    buffer.writeln(widths.map((w) => '-' * w).join('  '));
    for (final row in rows) {
      buffer.writeln(_formatRow(row, widths));
    }
    buffer.writeln();
    final verdict = isThresholdExceeded(threshold)
        ? 'FAIL (threshold: ${_fmt(threshold)})'
        : 'OK (threshold: ${_fmt(threshold)})';
    buffer.write('Max CRAP: ${_fmt(maxCrap)} — $verdict');
    return buffer.toString();
  }

  List<String> _rowFor(MethodMetrics m) => [
        m.crap == null ? 'N/A' : _fmt(m.crap!),
        _percent(m.coverage),
        _percent(m.branchCoverage),
        '${m.complexity}',
        '${m.method.className}.${m.method.methodName}',
        '${m.method.filePath}:${m.method.startLine}',
      ];

  String _formatRow(List<String> cells, List<int> widths) {
    final padded = <String>[];
    for (var i = 0; i < cells.length; i++) {
      // Right-align numeric columns, left-align the rest.
      padded.add(
        i < 4 ? cells[i].padLeft(widths[i]) : cells[i].padRight(widths[i]),
      );
    }
    return padded.join('  ');
  }

  static String _percent(double? value) =>
      value == null ? 'N/A' : (value * 100).toStringAsFixed(1);

  static String _fmt(double value) => value.toStringAsFixed(2);
}
