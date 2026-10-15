part of 'duplication_gate.dart';

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

/// Token masking applied before hashing: literal erasure, global
/// identifier erasure, and function-local consistent renaming. All
/// modes are opt-in.
class _TokenMask {
  _TokenMask(
    this._scopes,
    this._ignoreLocals,
    this._ignoreLiterals,
    this._ignoreIdentifiers,
  );

  final List<_FunctionScope> _scopes;
  final bool _ignoreLocals;
  final bool _ignoreLiterals;
  final bool _ignoreIdentifiers;

  /// Builds the mask [config] asks for; scopes are sorted and disjoint.
  static _TokenMask build(
    ParsedUnit parsed,
    DuplicationGateConfig config,
  ) {
    final matching = config.matching;
    if (!matching.ignoreLocals) {
      return _TokenMask(
        const [],
        false,
        matching.ignoreLiterals,
        matching.ignoreIdentifiers,
      );
    }
    final builder = _FunctionScopeBuilder();
    parsed.unit.accept(builder);
    return _TokenMask(
      builder.scopes,
      true,
      matching.ignoreLiterals,
      matching.ignoreIdentifiers,
    );
  }

  /// Masked value of [token], or null to keep its lexeme.
  String? of(Token token) {
    final literal = _literalMask(token);
    if (literal != null) return literal;
    // CPD --ignore-identifiers: structure-only matching. Makes the
    // per-scope renaming below redundant (everything identifier-shaped
    // collapses to one placeholder).
    if (_ignoreIdentifiers && _isIdentifierToken(token)) {
      return r'$ID';
    }
    return _localMask(token);
  }

  /// Function-local masking: interpolated strings become opaque and
  /// declared identifiers get scope placeholders. Null keeps the
  /// lexeme.
  String? _localMask(Token token) {
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

  /// Whether [token] is identifier-shaped: a plain identifier or a
  /// built-in / pseudo keyword (`out`, `show`, `sync`, ...), which the
  /// scanner reports as a keyword token occupying an identifier slot.
  static bool _isIdentifierToken(Token token) {
    final type = token.type;
    if (type == TokenType.IDENTIFIER) return true;
    if (type is! Keyword) return false;
    return type.isBuiltIn || type.isPseudo;
  }

  /// Literal mask for [token] when `ignore_literals` is on, else null.
  String? _literalMask(Token token) {
    if (!_ignoreLiterals) return null;
    switch (token.type.name) {
      case 'STRING':
      case 'STRING_INTERPOLATION':
        return '\$STR';
      case 'INT':
      case 'DOUBLE':
      case 'HEXADECIMAL':
        return '\$NUM';
    }
    return null;
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
