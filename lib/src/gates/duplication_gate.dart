import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../analysis/dart_parser.dart';
import '../analysis/method_extractor.dart';
import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// A single normalized token together with its source line.
class _NormalizedToken {
  /// Creates a [_NormalizedToken].
  _NormalizedToken(this.value, this.line);

  final String value;
  final int line;
  bool duplicated = false;
}

/// Position of a token window inside a file's token stream.
class _TokenPos {
  /// Creates a [_TokenPos].
  _TokenPos(this.fileIndex, this.tokenIndex);

  final int fileIndex;
  final int tokenIndex;
}

/// Token stream of a single file.
class _FileTokens {
  /// Creates a [_FileTokens].
  _FileTokens(this.file, this.tokens, this.totalLines);

  final String file;
  final List<_NormalizedToken> tokens;
  final int totalLines;
}

/// The `duplication` gate: fails files whose duplicated line percentage
/// exceeds the configured threshold.
///
/// The detection combines two ideas:
///  - Dart-aware tokenization via `package:analyzer` (like the rest of the
///    tool). String and numeric literals are normalized, comments are
///    skipped, and identifiers/keywords/operators keep their lexeme.
///  - Rabin-Karp-style sliding window indexing, similar to jscpd, so any
///    duplicated block of at least `min_tokens` tokens and `min_lines` lines
///    is detected within or across files.
class DuplicationGate implements Gate {
  /// Creates a [DuplicationGate].
  const DuplicationGate();

  @override
  String get id => 'duplication';

  static const int _base = 0x9e3779b97f4a7c15;
  static final int _mask = (1 << 64) - 1;

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.duplication;
    final files = _collectFiles(context, config);

    if (files.isEmpty) {
      return GateResult.pass(id, summary: 'no files with enough tokens');
    }

    _detectDuplicates(files, config.minTokens, config.minLines);
    final result = _buildResult(files, config, context);

    return result.violations.isEmpty
        ? GateResult.pass(id, summary: result.summary)
        : GateResult.fail(id, result.violations, summary: result.summary);
  }

  /// Loads and tokenizes the files that participate in duplicate detection.
  List<_FileTokens> _collectFiles(
    GateContext context,
    DuplicationGateConfig config,
  ) {
    final files = <_FileTokens>[];
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final tokens = _extractMethodTokens(parsed);
      if (tokens.length >= config.minTokens) {
        final totalLines = _lineCount(File(file).readAsStringSync());
        files.add(_FileTokens(file, tokens, totalLines));
      }
    }
    return files;
  }

  /// Builds the gate result from marked token streams.
  _Result _buildResult(
    List<_FileTokens> files,
    DuplicationGateConfig config,
    GateContext context,
  ) {
    final violations = <GateViolation>[];
    var checkedLines = 0;
    var duplicatedLines = 0;
    for (final file in files) {
      final dupLineSet = <int>{};
      for (final token in file.tokens) {
        if (token.duplicated) dupLineSet.add(token.line);
      }
      checkedLines += file.totalLines;
      duplicatedLines += dupLineSet.length;
      final violation = _violationFor(file, dupLineSet, config, context);
      if (violation != null) violations.add(violation);
    }

    final totalPercent =
        checkedLines == 0 ? 0.0 : (duplicatedLines / checkedLines) * 100.0;
    final summary = violations.isEmpty
        ? '${files.length} files, ${totalPercent.toStringAsFixed(2)}% duplicated lines'
        : '${violations.length}/${files.length} files over ${config.threshold}% duplication';
    return _Result(violations, summary);
  }

  /// Returns a violation when the file exceeds the duplication threshold.
  GateViolation? _violationFor(
    _FileTokens file,
    Set<int> dupLineSet,
    DuplicationGateConfig config,
    GateContext context,
  ) {
    if (file.totalLines == 0) return null;
    final percent = (dupLineSet.length / file.totalLines) * 100.0;
    if (percent <= config.threshold) return null;
    final firstLine = dupLineSet.isEmpty ? null : dupLineSet.reduce(min);
    return GateViolation(
      file: context.relativePath(file.file),
      line: firstLine,
      message: '${percent.toStringAsFixed(2)}% duplicated lines > '
          '${config.threshold}%',
    );
  }

  /// Extracts normalized tokens from method bodies in [parsed].
  List<_NormalizedToken> _extractMethodTokens(ParsedUnit parsed) {
    const extractor = MethodExtractor();
    final tokens = <_NormalizedToken>[];
    for (final method in extractor.extractWithNodes(
      parsed.unit,
      parsed.lineInfo,
      filePath: parsed.path,
    )) {
      final body = _body(method.node);
      if (body == null) continue;
      Token? token = body.beginToken;
      final end = body.endToken;
      while (token != null) {
        if (token.offset > end.offset) break;
        final normalized = _normalize(token);
        if (normalized != null) {
          final line = parsed.lineInfo.getLocation(token.offset).lineNumber;
          tokens.add(_NormalizedToken(normalized, line));
        }
        if (token == end) break;
        token = token.next;
      }
    }
    return tokens;
  }

  /// Returns the body of a method or top-level function declaration.
  FunctionBody? _body(AstNode node) {
    if (node is MethodDeclaration) return node.body;
    if (node is FunctionDeclaration) return node.functionExpression.body;
    return null;
  }

  /// Normalizes a token for duplicate detection.
  ///
  /// Comments and synthetic tokens are skipped; everything else keeps its
  /// lexeme. Whitespace is already absent from the analyzer token stream.
  String? _normalize(Token token) {
    if (token.isSynthetic || token is CommentToken) return null;
    if (token.type.name == 'EOF') return null;
    return token.lexeme;
  }

  /// Detects duplicated windows and marks the involved tokens.
  void _detectDuplicates(List<_FileTokens> files, int minTokens, int minLines) {
    final occurrences = <int, List<_TokenPos>>{};
    for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
      _indexFile(files[fileIndex], fileIndex, minTokens, minLines, occurrences);
    }

    for (final positions in occurrences.values) {
      if (positions.length < 2) continue;
      for (final pos in positions) {
        final tokens = files[pos.fileIndex].tokens;
        final limit = min(pos.tokenIndex + minTokens, tokens.length);
        for (var i = pos.tokenIndex; i < limit; i++) {
          tokens[i].duplicated = true;
        }
      }
    }
  }

  /// Indexes all valid windows of a single file.
  void _indexFile(
    _FileTokens file,
    int fileIndex,
    int minTokens,
    int minLines,
    Map<int, List<_TokenPos>> occurrences,
  ) {
    final tokens = file.tokens;
    final n = tokens.length;
    if (n < minTokens) return;

    final lines = tokens.map((t) => t.line).toList();
    final codes = tokens
        .map((t) => t.value.hashCode.toUnsigned(64))
        .toList(growable: false);
    final pow = _modPow(_base, minTokens - 1);

    var hash = 0;
    for (var i = 0; i < minTokens; i++) {
      hash = ((hash * _base) + codes[i]) & _mask;
    }
    _recordIfValid(occurrences, hash, fileIndex, 0, lines, minTokens, minLines);

    for (var start = 1; start <= n - minTokens; start++) {
      final removed = (codes[start - 1] * pow) & _mask;
      hash = (hash - removed) & _mask;
      hash = ((hash * _base) + codes[start + minTokens - 1]) & _mask;
      _recordIfValid(
        occurrences,
        hash,
        fileIndex,
        start,
        lines,
        minTokens,
        minLines,
      );
    }
  }

  /// Records a window only when it spans at least [minLines] lines.
  void _recordIfValid(
    Map<int, List<_TokenPos>> occurrences,
    int hash,
    int fileIndex,
    int start,
    List<int> lines,
    int minTokens,
    int minLines,
  ) {
    final firstLine = lines[start];
    final lastLine = lines[start + minTokens - 1];
    if (lastLine - firstLine + 1 < minLines) return;
    occurrences.putIfAbsent(hash, () => <_TokenPos>[]).add(
          _TokenPos(fileIndex, start),
        );
  }

  /// Computes `base^exp mod 2^64`.
  int _modPow(int base, int exp) {
    var result = 1 & _mask;
    var b = base & _mask;
    var e = exp;
    while (e > 0) {
      if (e & 1 == 1) result = (result * b) & _mask;
      b = (b * b) & _mask;
      e >>= 1;
    }
    return result;
  }

  /// Counts lines in [content].
  int _lineCount(String content) {
    if (content.isEmpty) return 0;
    final newlines = '\n'.allMatches(content).length;
    return content.endsWith('\n') ? newlines : newlines + 1;
  }
}

/// Intermediate result of [_buildResult].
class _Result {
  /// Creates a [_Result].
  _Result(this.violations, this.summary);

  final List<GateViolation> violations;
  final String summary;
}
