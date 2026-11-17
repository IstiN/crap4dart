import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../config/config.dart';
import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// Lifecycle-flag shape: `is/has/was/will/should/can` prefixes
/// (`isLoading`, `hasFailed`) or a lifecycle keyword suffix in
/// lowerCamelCase (`shardLoaded`, `engineReady`, `runPending`).
final RegExp stateFlagName = RegExp(
  r'^(?:is|has|was|will|should|can)[A-Z]'
  r'|(?:Loaded|Started|Stopped|Disposed|Pending|Ready|Done|Failed'
  r'|Scheduled|Driving|Running|Closed|Opened|Initialized|Connected'
  r'|Completed|Submitted|Finished|Canceled|Cancelled|Active|Busy'
  r'|Alive|Mounted|Broken|Dirty|Locked|Expired|Cached)$',
);

/// Whole-name lifecycle stage: `status`, `state`, `phase`, `stage`,
/// `mode`, `lifecycle`.
final RegExp statusFieldName = RegExp(
  r'^(?:status|state|phase|stage|mode|lifecycle)$',
);

/// The `implicit_state` gate: surfaces *implicit finite state machines* —
/// lifecycle logic spread over boolean flag clusters, multi-mutator status
/// fields and conditions that branch on flag combinations.
///
/// A cluster of mutable `bool` fields (`isLoading`, `hasFailed`,
/// `isDisposed`) mutated from several methods behaves like a state
/// machine with unmodelled combination states; a `status`/`state` field
/// assigned from many places is an FSM whose transitions are scattered;
/// `if (isLoading && hasFailed)` branches on an implicit combination.
/// All three make invalid states representable and transitions
/// unauditable — the fix is an explicit model (enum + exhaustive
/// switch, sealed class).
///
/// Detection is name-shape based on parsed (unresolved) sources:
///
/// - flag cluster: at least [ImplicitStateGateConfig.minFlags] matching
///   mutable bool fields, one or more of them mutated from at least
///   [ImplicitStateGateConfig.minMutators] distinct methods;
/// - per-flag finding: a single matching bool field or a matching
///   `status`-like field mutated from at least
///   [ImplicitStateGateConfig.minMutators] distinct methods;
/// - flag-combination condition: a condition reading two or more
///   lifecycle flags at once.
///
/// Detection intentionally stays syntactic: it cannot prove reachability
/// or races, it surfaces candidates for an explicit-model refactor. Use
/// `severity: warning` plus a baseline for adoption on existing code.
class ImplicitStateGate implements Gate {
  /// Creates the gate.
  const ImplicitStateGate();

  @override
  String get id => GateIds.implicitState;

  @override
  Future<GateResult> run(GateContext context) async {
    final settings = context.config.gates.quality.implicitState;
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final relative = context.relativePath(file);
      parsed.unit.visitChildren(
        _ClassCollector(relative, parsed.lineInfo, settings, violations),
      );
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: 'no implicit state machines')
        : GateResult.fail(
            id,
            violations,
            summary: '${violations.length} implicit state machine findings',
          );
  }
}

/// Visits class declarations and scans each one.
class _ClassCollector extends RecursiveAstVisitor<void> {
  final String _file;

  final LineInfo _lineInfo;

  final ImplicitStateGateConfig _settings;

  final List<GateViolation> _violations;

  _ClassCollector(
    this._file,
    this._lineInfo,
    this._settings,
    this._violations,
  );

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final violations = <GateViolation>[];
    final scanner = _ClassScanner(
      node,
      _file,
      _lineInfo,
      _settings,
      violations,
    );
    node.accept(scanner);
    scanner.finish();
    _violations.addAll(violations);
    super.visitClassDeclaration(node);
  }
}

/// One class scan: collects lifecycle flags, status fields, their
/// mutation sites per method, and flag-combination conditions.
class _ClassScanner extends RecursiveAstVisitor<void> {
  final ClassDeclaration _node;

  final String _file;

  final LineInfo _lineInfo;

  final ImplicitStateGateConfig _settings;

  final List<GateViolation> _violations;

  final _flags = <String, _FieldSites>{};

  final _statuses = <String, _FieldSites>{};

  final _memberStack = <String>[];

  _ClassScanner(
    this._node,
    this._file,
    this._lineInfo,
    this._settings,
    this._violations,
  );

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic) _collectFields(node);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _memberStack.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
    _memberStack.removeLast();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _memberStack.add(node.name?.lexeme ?? '<constructor>');
    super.visitConstructorDeclaration(node);
    _memberStack.removeLast();
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final name = _assignedPropertyName(node);
    if (name != null && _memberStack.isNotEmpty) {
      final method = _memberStack.last;
      _flags[name]?.methods.add(method);
      _statuses[name]?.methods.add(method);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    final collector = _StateFlagCollector(_flags.keys.toSet());
    node.expression.accept(collector);
    final names = collector.names;
    if (names.length >= 2) {
      _violations.add(
        GateViolation(
          file: _file,
          line: _lineOf(node.offset),
          message: 'condition branches on ${names.length} lifecycle flags '
              '(${names.join(', ')}) — an implicit state combination; '
              'model the states explicitly',
        ),
      );
    }
    super.visitIfStatement(node);
  }

  /// Emits the per-field and cluster violations after the whole class
  /// body has been visited.
  void finish() {
    final classLine = _lineOf(_node.offset);
    _reportFields(
        _flags,
        'lifecycle flag',
        'part of an implicit '
            'state machine');
    _reportFields(
        _statuses,
        'status field',
        'implicit transitions; '
            'centralize them');
    final assigned =
        _flags.values.where((sites) => sites.methods.isNotEmpty).toList();
    final scattered = assigned.any((s) => s.methods.length >= 2);
    if (assigned.length >= _settings.minFlags && scattered) {
      _violations.add(
        GateViolation(
          file: _file,
          line: classLine,
          message: 'class holds ${assigned.length} lifecycle flags mutated '
              'across methods — a boolean-cluster state machine; model it '
              'with an enum/sealed state',
        ),
      );
    }
  }

  int _lineOf(int offset) => _lineInfo.getLocation(offset).lineNumber;

  void _collectFields(FieldDeclaration node) {
    final type = node.fields.type;
    final isBool = type is NamedType && type.name.lexeme == 'bool';
    final mutable = !node.fields.isFinal && !node.fields.isConst;
    for (final variable in node.fields.variables) {
      final name = variable.name.lexeme;
      if (isBool && mutable && stateFlagName.hasMatch(name)) {
        _flags[name] = _FieldSites(_lineOf(variable.name.offset));
      } else if (statusFieldName.hasMatch(name.toLowerCase())) {
        _statuses[name] = _FieldSites(_lineOf(variable.name.offset));
      }
    }
  }

  String? _assignedPropertyName(AssignmentExpression node) {
    final target = node.leftHandSide;
    if (target is SimpleIdentifier) return target.name;
    if (target is PropertyAccess) return target.propertyName.name;
    if (target is PrefixedIdentifier) return target.identifier.name;
    return null;
  }

  void _reportFields(
    Map<String, _FieldSites> fields,
    String kind,
    String tail,
  ) {
    for (final entry in fields.entries) {
      final count = entry.value.methods.length;
      if (count < _settings.minMutators) continue;
      _violations.add(
        GateViolation(
          file: _file,
          line: entry.value.line,
          message: "$kind '${entry.key}' is mutated from $count places — "
              '$tail',
        ),
      );
    }
  }
}

/// Per-field declaration line and the set of methods assigning it.
class _FieldSites {
  /// Declaration line.
  final int line;

  /// Distinct member declarations that assign the field.
  final Set<String> methods = <String>{};

  _FieldSites(this.line);
}

/// Collects standalone lifecycle-flag identifiers in a condition,
/// skipping property-name positions (`x.isDone` is an access, not a
/// bare flag read).
class _StateFlagCollector extends RecursiveAstVisitor<void> {
  /// Declared lifecycle flags of the scanned class.
  final Set<String> _fields;

  /// Bare flag reads found in one condition.
  final Set<String> names = <String>{};

  _StateFlagCollector(this._fields);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    final isPropertyAccess =
        (parent is PrefixedIdentifier && parent.identifier == node) ||
            (parent is PropertyAccess && parent.propertyName == node);
    if (!isPropertyAccess && _fields.contains(node.name)) {
      names.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }
}
