import 'package:analyzer/dart/ast/ast.dart';

import '../analysis/dart_parser.dart';
import '../analysis/method_extractor.dart';

/// A single method instrumentation insertion point.
class _Insertion {
  final int offset;
  final String text;

  _Insertion(this.offset, this.text);
}

/// Instruments Dart source code by wrapping each method body in a
/// `Stopwatch`-based `try/finally` block that records execution time.
///
/// The instrumented code imports a collector library (expected at
/// `package:PACKAGE/__crap_collector.dart`) and calls
/// `CrapCollector.instance.record(key, micros)` on every method exit.
class SourceInstrumenter {
  /// Creates a [SourceInstrumenter].
  const SourceInstrumenter({required this.packageName});

  /// Package name used for the collector import URI.
  final String packageName;

  /// Instruments [source] and returns the modified source code.
  ///
  /// [filePath] is used only for error messages. Methods that cannot be
  /// instrumented (expression bodies, generators, external methods) are
  /// skipped silently.
  String instrument(String source, {String filePath = ''}) {
    final parsed = DartParser().parse(content: source, path: filePath);
    // Parts cannot contain imports, so the collector import cannot be
    // injected into a `part of` file — skip them entirely (their methods
    // are simply not profiled) instead of producing uncompilable code.
    if (parsed.unit.directives.any((d) => d is PartOfDirective)) {
      return source;
    }
    final extracted = MethodExtractor().extractWithNodes(
      parsed.unit,
      parsed.lineInfo,
      filePath: filePath,
    );

    final insertions = <_Insertion>[];

    for (final entry in extracted) {
      final body = _getBody(entry.node);
      if (body == null) continue;

      final leftBracket = body.block.leftBracket;
      final rightBracket = body.block.rightBracket;

      // Skip empty bodies ({}) — both insertion points would overlap.
      if (leftBracket.offset + leftBracket.length >= rightBracket.offset) {
        continue;
      }

      final key = _methodKey(entry.info);
      final varName = '__sw_crap';

      // Insert after the opening brace: start timer + try.
      insertions.add(_Insertion(
        leftBracket.offset + leftBracket.length,
        '\n      final $varName = Stopwatch()..start();\n      try {',
      ));

      // Insert before the closing brace: finally + record.
      insertions.add(_Insertion(
        rightBracket.offset,
        '} finally { '
        "CrapCollector.instance.record('$key', "
        '$varName.elapsedMicroseconds); '
        '}\n    ',
      ));
    }

    if (insertions.isEmpty) return source;

    // Apply insertions from end to start so offsets don't shift.
    insertions.sort((a, b) => b.offset.compareTo(a.offset));

    var result = source;
    for (final ins in insertions) {
      result = result.substring(0, ins.offset) +
          ins.text +
          result.substring(ins.offset);
    }

    // Insert the collector import after any leading `library`/`part of`
    // directive — Dart requires those to precede all other directives, so
    // prepending blindly (as before) produced a compile error on files that
    // start with `library;`.
    final importLine = "import 'package:$packageName/__crap_collector.dart';\n";
    final importOffset = _importInsertionOffset(parsed.unit, source);

    return result.substring(0, importOffset) +
        importLine +
        result.substring(importOffset);
  }

  /// Extracts the [BlockFunctionBody] from a method or function node.
  BlockFunctionBody? _getBody(AstNode node) {
    if (node is MethodDeclaration) {
      final body = node.body;
      if (body is BlockFunctionBody) return body;
    } else if (node is FunctionDeclaration) {
      final body = node.functionExpression.body;
      if (body is BlockFunctionBody) return body;
    }
    return null;
  }

  /// Builds the profiling key for a method: `ClassName.methodName`.
  String _methodKey(MethodInfo info) => '${info.className}.${info.methodName}';

  /// Returns the offset at which the collector import should be inserted.
  ///
  /// Dart mandates that `library` (and `part of`) directives appear before
  /// all other directives. The import is therefore placed immediately after
  /// any such leading directive, or at the start of the file when none is
  /// present. The offset is computed against the original [source]; it is
  /// valid for the instrumented copy because method-body insertions never
  /// touch the directive region at the top of the file.
  int _importInsertionOffset(CompilationUnit unit, String source) {
    var offset = 0;
    for (final directive in unit.directives) {
      if (directive is LibraryDirective ||
          directive is PartOfDirective ||
          directive is PartDirective) {
        offset = _endOfLine(source, directive.end);
      } else {
        // Reached an import/export — stop so the collector import lands
        // alongside (before) existing imports.
        break;
      }
    }
    return offset;
  }

  /// Advances [offset] to the start of the line following it.
  int _endOfLine(String source, int offset) {
    final nl = source.indexOf('\n', offset);
    return nl == -1 ? source.length : nl + 1;
  }
}
