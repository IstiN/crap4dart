import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../analysis/dart_parser.dart';
import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// The `enum_name_contract` gate: flags usages of the built-in
/// `.name` / `.index` members *inside enum declaration bodies*, where the
/// contract value silently changes when a Dart identifier is renamed.
///
/// `Color.red.name` is `"red"` today; rename the constant to `crimson`
/// and every persisted YAML/JSON/DB row written from it drifts. The fix
/// is an explicit contract field: `final String value;` (enhanced enum)
/// contracted on as `.value`.
///
/// Only *provable* receivers are flagged — pure unresolved-AST reasoning:
/// - `this` (`this.name`, `this.index`);
/// - implicit `this`: a bare `name`/`index` identifier read inside an
///   instance member body with no local shadowing of that name;
/// - the enum's own constants (`red.name`, `Color.red.name`);
/// - the `values` list: loop variables introduced by
///   `for (final v in values)`, and `values[i]` index accesses;
/// - parameters explicitly typed with the enclosing enum's name.
///
/// Names the enum body declares itself (`name`/`index` members) shadow
/// the built-ins and are skipped. Usages *outside* enum bodies are Tier 2
/// and deliberately out of scope — they need in-package type matching.
///
/// Warning severity by default: `.name` in log/display labels is legal;
/// the message asks to confirm the usage is not a persisted contract.
class EnumNameContractGate implements Gate {
  // The built-in enum members this gate polices (library-private: the
  // visitor classes below share them).
  static const String _nameMember = 'name';
  static const String _indexMember = 'index';

  /// Creates an [EnumNameContractGate].
  const EnumNameContractGate();

  @override
  String get id => GateIds.enumNameContract;

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final parsed = context.parsed(file);
      parsed.unit.accept(
        _EnumDeclarationsVisitor(
          context.relativePath(file),
          parsed,
          violations,
        ),
      );
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: 'no built-in name/index contracts')
        : GateResult.fail(id, violations);
  }
}

/// Visits every enum declaration and audits its member bodies.
class _EnumDeclarationsVisitor extends RecursiveAstVisitor<void> {
  final String _file;

  final ParsedUnit _parsed;

  final List<GateViolation> _violations;

  _EnumDeclarationsVisitor(this._file, this._parsed, this._violations);

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final enumName =
        (node.namePart.childEntities.first as dynamic).lexeme as String;
    final shadowed = _shadowedMembers(node.body.members);
    for (final member in node.body.members) {
      final body = _memberBody(member);
      if (body != null) {
        final visitor = _BodyVisitor(
          enumName: enumName,
          constants: node.body.constants,
          inStaticMember: _isStatic(member),
          shadowed: shadowed,
          outer: this,
        );
        _visitParameters(member, visitor);
        body.accept(visitor);
      }
    }
    super.visitEnumDeclaration(node);
  }

  /// Parameters are siblings of the body — visit them first so enum-typed
  /// parameters and shadowing names are registered before any use.
  void _visitParameters(ClassMember member, _BodyVisitor visitor) {
    if (member is MethodDeclaration) {
      member.parameters?.accept(visitor);
    } else if (member is ConstructorDeclaration) {
      member.parameters.accept(visitor);
    }
  }

  /// Names `name`/`index` that this enum declares itself — those shadow
  /// the built-ins and must not be flagged.
  Set<String> _shadowedMembers(List<ClassMember> members) {
    final shadowed = <String>{};
    for (final member in members) {
      for (final name in _declaredMemberNames(member)) {
        if (name == EnumNameContractGate._nameMember ||
            name == EnumNameContractGate._indexMember) {
          shadowed.add(name);
        }
      }
    }
    return shadowed;
  }

  Iterable<String> _declaredMemberNames(ClassMember member) sync* {
    if (member is MethodDeclaration) {
      yield member.name.lexeme;
    } else if (member is FieldDeclaration) {
      for (final variable in member.fields.variables) {
        yield variable.name.lexeme;
      }
    }
  }

  AstNode? _memberBody(ClassMember member) {
    if (member is MethodDeclaration) return member.body;
    if (member is ConstructorDeclaration) return member.body;
    return null;
  }

  bool _isStatic(ClassMember member) =>
      member is MethodDeclaration && member.isStatic;

  void _flag(AstNode node, String enumName, String member) {
    _violations.add(
      GateViolation(
        file: _file,
        line: _parsed.lineInfo.getLocation(node.offset).lineNumber,
        message: "enum '$enumName' contracts on the built-in '.$member' — "
            'the persisted value changes when the identifier is renamed; '
            "declare a 'final String value' field and contract on '.value'",
      ),
    );
  }
}

/// Walks one enum-member body, tracking which local names are provably
/// enum-typed and flagging `.name`/`.index` accesses on provable enum
/// receivers.
class _BodyVisitor extends RecursiveAstVisitor<void> {
  final String _enumName;

  final List<EnumConstantDeclaration> _constants;

  final bool _inStaticMember;

  final Set<String> _shadowed;

  final _EnumDeclarationsVisitor _outer;

  /// Locals provably enum-typed: loop variables over `values`, parameters
  /// explicitly typed with the enum's name.
  final Set<String> _enumLocals = {};

  /// All local names declared in the body — used to reject
  /// implicit-`this` candidates that are actually shadowed locals.
  final Set<String> _locals = {};

  _BodyVisitor({
    required String enumName,
    required List<EnumConstantDeclaration> constants,
    required bool inStaticMember,
    required Set<String> shadowed,
    required _EnumDeclarationsVisitor outer,
  })  : _enumName = enumName,
        _constants = constants,
        _inStaticMember = inStaticMember,
        _shadowed = shadowed,
        _outer = outer;

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _locals.add(name);
      if (_hasEnumDeclaredType(node.type)) _enumLocals.add(name);
    }
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _registerLoopVariables(node.forLoopParts);
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    _registerLoopVariables(node.forLoopParts);
    super.visitForElement(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _locals.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkAccess(node, node.prefix, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target != null) {
      _checkAccess(node, target, node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!_inStaticMember) _checkImplicitThis(node);
    super.visitSimpleIdentifier(node);
  }

  bool _hasEnumDeclaredType(TypeAnnotation? type) {
    if (type == null) return false;
    final spelling = type.toString();
    return spelling == _enumName || spelling.endsWith('.$_enumName');
  }

  void _registerLoopVariables(ForLoopParts parts) {
    if (parts is ForEachPartsWithDeclaration) {
      final loopVar = parts.loopVariable.name.lexeme;
      _locals.add(loopVar);
      if (_isValuesIterable(parts.iterable)) _enumLocals.add(loopVar);
    }
  }

  /// Whether [expression] is the enum's `values` list: the implicit
  /// static `values` or `EnumName.values`.
  bool _isValuesIterable(Expression expression) {
    if (expression is SimpleIdentifier) {
      return expression.name == 'values';
    }
    if (expression is PrefixedIdentifier) {
      return expression.prefix.name == _enumName &&
          expression.identifier.name == 'values';
    }
    return false;
  }

  void _checkAccess(AstNode access, Expression target, String member) {
    if (member != EnumNameContractGate._nameMember &&
        member != EnumNameContractGate._indexMember) {
      return;
    }
    if (_shadowed.contains(member)) return;
    if (_isProvableEnumReceiver(target)) {
      _outer._flag(access, _enumName, member);
    }
  }

  /// Whether [target] is provably an enum value of the audited enum —
  /// see the gate's documentation for the accepted receiver shapes.
  bool _isProvableEnumReceiver(Expression target) {
    if (target is ThisExpression) return true;
    if (target is SimpleIdentifier) {
      return _enumLocals.contains(target.name) || _isConstantName(target.name);
    }
    if (target is PrefixedIdentifier) {
      return target.prefix.name == _enumName &&
          _isConstantName(target.identifier.name);
    }
    if (target is IndexExpression) {
      final sequence = target.target;
      return sequence != null && _isValuesIterable(sequence);
    }
    return false;
  }

  bool _isConstantName(String name) =>
      _constants.any((c) => c.name.lexeme == name);

  /// A bare `name`/`index` identifier read inside an instance member body
  /// is `this.name`/`this.index` — unless a local shadows it, the name is
  /// a property/call position (those are not reads of the built-in), or
  /// it is being assigned (the built-ins have no setters; such code is a
  /// compile error we stay out of).
  void _checkImplicitThis(SimpleIdentifier node) {
    final lexeme = node.name;
    if (!_isPolicedMember(lexeme)) return;
    if (_shadowed.contains(lexeme) || _locals.contains(lexeme)) return;
    if (!_isImplicitThisRead(node)) return;
    _outer._flag(node, _enumName, lexeme);
  }

  /// Whether [lexeme] is one of the built-in members this gate polices.
  bool _isPolicedMember(String lexeme) =>
      lexeme == EnumNameContractGate._nameMember ||
      lexeme == EnumNameContractGate._indexMember;

  /// Whether [node] is a plain read of `this.<member>`: not a property
  /// name (`x.name`), not an invocation (`x.name()`), not an assignment
  /// target.
  bool _isImplicitThisRead(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is AssignmentExpression) return false;
    if (parent is PropertyAccess && parent.propertyName == node) return false;
    if (parent is PrefixedIdentifier && parent.identifier == node) {
      return false;
    }
    return parent is! MethodInvocation;
  }
}
