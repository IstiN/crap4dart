/// Formats tabular data as aligned text columns for console reports.
///
/// Shared by [CrapReport] and [ProfileReport] to avoid duplicated
/// width-computation and row-formatting logic.
class TableFormatter {
  /// Creates a [TableFormatter].
  ///
  /// Columns with index < [numericColumnCount] are right-aligned; the
  /// remaining columns are left-aligned.
  const TableFormatter({this.numericColumnCount = 0});

  /// Number of leading columns to right-align (numeric columns).
  final int numericColumnCount;

  /// Computes the maximum width for each column from [headers] and [rows].
  List<int> computeWidths(List<String> headers, List<List<String>> rows) {
    final widths = List.generate(headers.length, (i) => headers[i].length);
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }
    return widths;
  }

  /// Formats a single row, right-aligning numeric columns and left-aligning
  /// the rest, separated by two spaces.
  String formatRow(List<String> cells, List<int> widths) {
    final padded = <String>[];
    for (var i = 0; i < cells.length; i++) {
      padded.add(
        i < numericColumnCount
            ? cells[i].padLeft(widths[i])
            : cells[i].padRight(widths[i]),
      );
    }
    return padded.join('  ');
  }

  /// Renders the separator line (dashes matching each column width).
  String separator(List<int> widths) => widths.map((w) => '-' * w).join('  ');

  /// Renders [headers] and [rows] as a complete table (header row, separator,
  /// data rows), each terminated by a newline.
  String renderTable(List<String> headers, List<List<String>> rows) {
    final widths = computeWidths(headers, rows);
    final buffer = StringBuffer();
    buffer.writeln(formatRow(headers, widths));
    buffer.writeln(separator(widths));
    for (final row in rows) {
      buffer.writeln(formatRow(row, widths));
    }
    return buffer.toString();
  }
}
