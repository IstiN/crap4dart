import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

/// Result of parsing a single Dart source file.
class ParsedUnit {
  /// Creates a [ParsedUnit] wrapping the parsed [unit] and its [lineInfo].
  const ParsedUnit({
    required this.unit,
    required this.lineInfo,
    required this.path,
  });

  /// The parsed (unresolved) compilation unit.
  final CompilationUnit unit;

  /// Line information used to map offsets to line numbers.
  final LineInfo lineInfo;

  /// The path the content was parsed from (may be empty).
  final String path;
}

/// Exception thrown when Dart source cannot be parsed.
class DartParseException implements Exception {
  /// Creates a [DartParseException] for [path] with a diagnostic [message].
  const DartParseException(this.path, this.message);

  /// Path of the file that failed to parse.
  final String path;

  /// Human readable diagnostics.
  final String message;

  @override
  String toString() => 'Failed to parse "$path": $message';
}

/// Parses Dart source files into unresolved ASTs.
class DartParser {
  /// Parses [content] as a Dart compilation unit.
  ///
  /// Throws a [DartParseException] with line/column diagnostics when the
  /// content produces parse errors.
  ParsedUnit parse({required String content, String path = ''}) {
    final ParseStringResult result;
    try {
      result = parseString(content: content, path: path);
    } on ArgumentError catch (e) {
      throw DartParseException(path, e.message.toString());
    }
    return ParsedUnit(
      unit: result.unit,
      lineInfo: result.lineInfo,
      path: path,
    );
  }
}
