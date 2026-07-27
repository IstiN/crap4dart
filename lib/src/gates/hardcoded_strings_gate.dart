import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `hardcoded_strings` gate: flags user-visible string literals that
/// bypass localization, and `l10n.<key>` references missing from
/// `app_en.arb`.
///
/// Skipped for non-Flutter projects.
class HardcodedStringsGate implements Gate {
  /// Creates a [HardcodedStringsGate].
  const HardcodedStringsGate();

  /// Marker comment that disables the gate for a whole file when it
  /// appears within the first 5 lines.
  static const String ignoreFileMarker = '// l10n:ignore-file';

  static final RegExp _letters = RegExp('[A-Za-z\u0400-\u04FF]');

  @override
  String get id => 'hardcoded_strings';

  @override
  Future<GateResult> run(GateContext context) async {
    if (!context.isFlutterProject) {
      return GateResult.skip(id, 'not a Flutter project');
    }
    final config = context.config.gates.hardcodedStrings;
    final arbKeys = _loadArbKeys(context.projectRoot);
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final content = File(file).readAsStringSync();
      if (_isIgnoredFile(content)) continue;
      final parsed = context.parsed(file);
      final visitor = _StringsVisitor(
        context.relativePath(file),
        parsed,
        config.checkParams,
        config.ignoreMarker,
        content.split('\n'),
        arbKeys,
      );
      parsed.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: 'no hardcoded strings found')
        : GateResult.fail(id, violations);
  }

  bool _isIgnoredFile(String content) {
    final head = content.split('\n').take(5);
    return head.any((line) => line.contains(ignoreFileMarker));
  }

  /// Returns the keys of `app_en.arb` under `lib/`, or `null` when no ARB
  /// files exist (the l10n key check is then disabled).
  Set<String>? _loadArbKeys(String projectRoot) {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return null;
    final arbFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    if (arbFiles.isEmpty) return null;
    final appEn = arbFiles.where((f) => p.basename(f.path) == 'app_en.arb');
    final file = appEn.isNotEmpty ? appEn.first : arbFiles.first;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) return null;
      return {
        for (final key in json.keys)
          if (key is String && !key.startsWith('@')) key,
      };
    } on FormatException {
      return null;
    }
  }
}

class _StringsVisitor extends RecursiveAstVisitor<void> {
  _StringsVisitor(
    this._file,
    this._parsed,
    this._checkParams,
    this._ignoreMarker,
    this._lines,
    this._arbKeys,
  );

  final String _file;
  final ParsedUnit _parsed;
  final List<String> _checkParams;
  final String _ignoreMarker;
  final List<String> _lines;
  final Set<String>? _arbKeys;
  final List<GateViolation> violations = [];

  static final RegExp _letters = HardcodedStringsGate._letters;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _checkString(node, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final literal = [
      for (final element in node.elements)
        if (element is InterpolationString) element.contents,
    ].join();
    if (_letters.hasMatch(literal)) {
      _checkNode(node, literal.trim());
    }
    super.visitStringInterpolation(node);
  }

  void _checkString(SingleStringLiteral node, String value) {
    if (node is! StringInterpolation && !_letters.hasMatch(value)) return;
    _checkNode(node, value);
  }

  void _checkNode(SingleStringLiteral node, String preview) {
    if (_isIgnored(node)) return;
    // Ascend through adjacent strings: 'foo' 'bar' is one logical string.
    AstNode contextNode = node;
    if (contextNode.parent is AdjacentStrings) {
      contextNode = contextNode.parent!;
    }
    final parent = contextNode.parent;
    if (parent is NamedExpression) {
      final label = parent.name.label.name;
      if (_checkParams.contains(label)) {
        _add(node, preview, "in parameter '$label'");
      }
      return;
    }
    if (parent is ArgumentList && _isTextCall(parent.parent)) {
      _add(node, preview, 'in Text(...)');
    }
  }

  bool _isTextCall(AstNode? node) {
    if (node is MethodInvocation) return node.methodName.name == 'Text';
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name2.lexeme == 'Text';
    }
    return false;
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'l10n') _checkL10nKey(node, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier && target.name == 'l10n') {
      _checkL10nKey(node, node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }

  void _checkL10nKey(AstNode node, String key) {
    final arbKeys = _arbKeys;
    if (arbKeys != null && !arbKeys.contains(key)) {
      violations.add(
        GateViolation(
          file: _file,
          line: _lineOf(node),
          message: "l10n key '$key' missing from app_en.arb",
        ),
      );
    }
  }

  bool _isIgnored(AstNode node) {
    final line = _lineOf(node);
    for (final candidate in [line, line - 1]) {
      if (candidate >= 1 &&
          candidate <= _lines.length &&
          _lines[candidate - 1].contains(_ignoreMarker)) {
        return true;
      }
    }
    return false;
  }

  void _add(AstNode node, String preview, String where) {
    final short =
        preview.length > 40 ? '${preview.substring(0, 37)}...' : preview;
    violations.add(
      GateViolation(
        file: _file,
        line: _lineOf(node),
        message: "hardcoded string '$short' $where",
      ),
    );
  }

  int _lineOf(AstNode node) =>
      _parsed.lineInfo.getLocation(node.offset).lineNumber;
}
