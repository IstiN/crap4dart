import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// A single token together with its source line, raw lexeme, and
/// normalized value (identical to the lexeme when no masking applies).
class _NormalizedToken {
  /// Creates a [_NormalizedToken].
  _NormalizedToken(this.lexeme, this.value, this.line);

  final String lexeme;
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
/// The detection tokenizes the whole Dart file with `package:analyzer`,
/// skips comments, then indexes sliding windows of tokens with a
/// Rabin-Karp hash, similar to jscpd. Any duplicated block of at least
/// `min_tokens` tokens and `min_lines` lines is detected within or across
/// files. Two opt-in normalizations extend detection to renamed clones
/// (Type-2): `ignore_locals` renames function-local identifiers
/// consistently in first-use order — the API surface (called method
/// names, type names, field references) keeps its lexeme, so swapped
/// locals or different calls never match — and `ignore_literals`
/// replaces string and numeric literals with type placeholders.
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

    _detectDuplicates(files, config.matching);
    final result = _buildResult(files, config, context);

    return result.violations.isEmpty
        ? GateResult.pass(id, summary: result.summary)
        : GateResult.fail(id, result.violations, summary: result.summary);
  }

  /// Loads and tokenizes the files that participate in duplicate detection.
  ///
  /// Beyond the analyzed source set, the gate's [DuplicationGateConfig.sources]
  /// paths are unioned in — that is what makes cross-module duplication
  /// visible without widening the CRAP analysis scope.
  List<_FileTokens> _collectFiles(
    GateContext context,
    DuplicationGateConfig config,
  ) {
    final files = <String>[...context.files];
    for (final source in _expandSources(context, config.sources)) {
      if (!files.contains(source)) files.add(source);
    }
    files.sort();
    final tokens = <_FileTokens>[];
    for (final file in files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final fileTokens = _extractFileTokens(parsed, config);
      if (fileTokens.length >= config.matching.minTokens) {
        final totalLines = _lineCount(File(file).readAsStringSync());
        tokens.add(_FileTokens(file, fileTokens, totalLines));
      }
    }
    return tokens;
  }

  /// Resolves the gate's additional [sources] against the project root:
  /// directories are scanned recursively for `.dart` files, files are
  /// taken directly, missing paths are skipped silently.
  List<String> _expandSources(GateContext context, List<String> sources) {
    final result = <String>[];
    for (final source in sources) {
      final absolute = p.join(context.projectRoot, source);
      final type = FileSystemEntity.typeSync(absolute);
      if (type == FileSystemEntityType.file) {
        if (absolute.endsWith('.dart')) result.add(absolute);
      } else if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(absolute).listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            result.add(entity.path);
          }
        }
      }
    }
    return result;
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

  /// Extracts normalized tokens from the whole parsed file.
  List<_NormalizedToken> _extractFileTokens(
    ParsedUnit parsed,
    DuplicationGateConfig config,
  ) {
    final tokens = <_NormalizedToken>[];
    final mask = _TokenMask.build(parsed, config);
    Token? token = parsed.unit.beginToken;
    final end = parsed.unit.endToken;
    while (token != null) {
      if (token.offset > end.offset) break;
      final normalized = _normalize(token, mask);
      if (normalized != null) {
        final line = parsed.lineInfo.getLocation(token.offset).lineNumber;
        tokens.add(_NormalizedToken(token.lexeme, normalized, line));
      }
      if (token == end) break;
      token = token.next;
    }
    return tokens;
  }

  /// Normalizes a token for duplicate detection.
  ///
  /// Comments and synthetic tokens are skipped; string and numeric
  /// literals are masked when [DuplicationGateConfig.ignoreLiterals] is
  /// set, and function-local identifiers are consistently renamed when
  /// [DuplicationGateConfig.ignoreLocals] is set. Everything else keeps
  /// its lexeme. Whitespace is already absent from the analyzer token
  /// stream.
  String? _normalize(Token token, _TokenMask mask) {
    if (token.isSynthetic || token is CommentToken) return null;
    if (token.type.name == 'EOF') return null;
    return mask.of(token) ?? token.lexeme;
  }

  /// Detects duplicated windows and marks the involved tokens.
  ///
  /// Two passes: the raw pass compares lexemes (Type-1 copy-paste) and
  /// always runs; when local renaming is enabled a second pass compares
  /// masked values (Type-2 renamed clones). The union of both is
  /// reported — enabling `ignore_locals` can only add findings, never
  /// lose exact copies whose enclosing scopes shift placeholder
  /// numbering.
  void _detectDuplicates(
    List<_FileTokens> files,
    DuplicationMatching matching,
  ) {
    if (matching.ignoreLocals) {
      _markDuplicates(files, matching, _rawCodes);
    }
    _markDuplicates(files, matching, _maskedCodes);
  }

  /// Token codes from the raw lexemes.
  List<int> _rawCodes(List<_NormalizedToken> tokens) =>
      [for (final t in tokens) t.lexeme.hashCode.toUnsigned(64)];

  /// Token codes from the masked (normalized) values.
  List<int> _maskedCodes(List<_NormalizedToken> tokens) =>
      [for (final t in tokens) t.value.hashCode.toUnsigned(64)];

  /// One detection pass over the given [codes] of every file.
  void _markDuplicates(
    List<_FileTokens> files,
    DuplicationMatching matching,
    List<int> Function(List<_NormalizedToken>) codes,
  ) {
    final occurrences = <int, List<_TokenPos>>{};
    for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
      _indexFile(files[fileIndex], fileIndex, matching, codes, occurrences);
    }

    for (final positions in occurrences.values) {
      if (positions.length < 2) continue;
      for (final pos in positions) {
        final tokens = files[pos.fileIndex].tokens;
        final limit = min(pos.tokenIndex + matching.minTokens, tokens.length);
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
    DuplicationMatching matching,
    List<int> Function(List<_NormalizedToken>) codeOf,
    Map<int, List<_TokenPos>> occurrences,
  ) {
    final tokens = file.tokens;
    final n = tokens.length;
    if (n < matching.minTokens) return;

    final minTokens = matching.minTokens;
    final minLines = matching.minLines;
    final lines = tokens.map((t) => t.line).toList();
    final codes = codeOf(tokens);
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

/// A single function-local scope: identifiers declared inside [start,
/// end) are renamed consistently for clone matching.
class _FunctionScope {
  _FunctionScope(this.start, this.end, this.names);

  final int start;
  final int end;
  final Set<String> names;
  final Map<String, String> _placeholders = {};

  /// Placeholder for [name], assigned in first-use order: renamed clones
  /// of the same algorithm hash identically, while two locals swapped
  /// against each other keep different placeholders and never match.
  String placeholderFor(String name) =>
      _placeholders.putIfAbsent(name, () => '\$L${_placeholders.length + 1}');
}

/// Token masking applied before hashing: literal erasure and
/// function-local consistent renaming. Both modes are opt-in.
class _TokenMask {
  _TokenMask(this._scopes, this._ignoreLocals, this._ignoreLiterals);

  final List<_FunctionScope> _scopes;
  final bool _ignoreLocals;
  final bool _ignoreLiterals;

  /// Builds the mask [config] asks for; scopes are sorted and disjoint.
  static _TokenMask build(
    ParsedUnit parsed,
    DuplicationGateConfig config,
  ) {
    if (!config.matching.ignoreLocals) {
      return _TokenMask(const [], false, config.matching.ignoreLiterals);
    }
    final builder = _FunctionScopeBuilder();
    parsed.unit.accept(builder);
    return _TokenMask(builder.scopes, true, config.matching.ignoreLiterals);
  }

  /// Masked value of [token], or null to keep its lexeme.
  String? of(Token token) {
    if (_ignoreLiterals) {
      switch (token.type.name) {
        case 'STRING':
        case 'STRING_INTERPOLATION':
          return '\$STR';
        case 'INT':
        case 'DOUBLE':
        case 'HEXADECIMAL':
          return '\$NUM';
      }
    }
    // Interpolated strings embed local identifiers in their raw lexeme;
    // they are opaque under local renaming so embedded renames cannot
    // break window hashes.
    if (_ignoreLocals && token.type.name == 'STRING_INTERPOLATION') {
      return '\$STR';
    }
    if (_scopes.isEmpty) return null;
    final scope = _scopeAt(token.offset);
    if (scope == null || !scope.names.contains(token.lexeme)) return null;
    return scope.placeholderFor(token.lexeme);
  }

  /// Scope containing [offset], or null — binary search over starts.
  _FunctionScope? _scopeAt(int offset) {
    var low = 0;
    var high = _scopes.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final scope = _scopes[mid];
      if (offset < scope.start) {
        high = mid - 1;
      } else if (offset >= scope.end) {
        low = mid + 1;
      } else {
        return scope;
      }
    }
    return null;
  }
}

/// Collects the outermost function scopes of a compilation unit: one
/// per method, constructor, and function expression; nested functions
/// share the outermost scope.
class _FunctionScopeBuilder extends GeneralizingAstVisitor<void> {
  final scopes = <_FunctionScope>[];
  var _depth = 0;

  @override
  void visitNode(AstNode node) => node.visitChildren(this);

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      _addScope(node, node.parameters?.offset ?? node.body.offset);

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) =>
      _addScope(node, node.parameters.offset);

  @override
  void visitFunctionExpression(FunctionExpression node) =>
      _addScope(node, node.parameters?.offset ?? node.body.offset);

  void _addScope(AstNode node, int start) {
    if (_depth > 0) {
      node.visitChildren(this);
      return;
    }
    final collector = _DeclaredNamesCollector();
    node.accept(collector);
    scopes.add(_FunctionScope(start, node.end, collector.names));
    _depth++;
    node.visitChildren(this);
    _depth--;
  }
}

/// Collects every identifier declared inside a function: parameters
/// (except field initializers, which reference API state), local
/// variables, loop and catch variables, type parameters, local
/// functions, and pattern variables.
class _DeclaredNamesCollector extends GeneralizingAstVisitor<void> {
  final names = <String>{};

  @override
  void visitNode(AstNode node) => node.visitChildren(this);

  @override
  void visitFormalParameter(FormalParameter node) {
    if (node is! FieldFormalParameter && node is! SuperFormalParameter) {
      final name = node.name;
      if (name != null) names.add(name.lexeme);
    }
    node.visitChildren(this);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitCatchClauseParameter(CatchClauseParameter node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitVariablePattern(VariablePattern node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitWildcardPattern(WildcardPattern node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    names.add(node.name.lexeme);
    node.visitChildren(this);
  }
}

/// Intermediate result of [_buildResult].
class _Result {
  /// Creates a [_Result].
  _Result(this.violations, this.summary);

  final List<GateViolation> violations;
  final String summary;
}
