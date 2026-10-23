import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The kind of one record-type finding; each record gate consumes its
/// own kind from the shared [RecordTypesScanner] walk.
enum RecordFindingKind {
  /// A record type annotation in a signature carrying unnamed
  /// fields — the only fields readable via `.$N`.
  unnamedFields,

  /// A `.$1`-style positional field access.
  positionalAccess,

  /// An inline record type annotation in a signature.
  inlineType,

  /// A record type (inline or aliased) with more fields than the
  /// configured cap.
  oversized,
}

/// One record-shape finding: kind, message, and its 1-based line.
class RecordFinding {
  /// Creates a finding.
  const RecordFinding(this.kind, this.line, this.message);

  /// Which gate-facing check produced the finding.
  final RecordFindingKind kind;

  /// 1-based source line.
  final int line;

  /// Human readable description.
  final String message;
}

/// Default field cap shared by the scanner and the `record_size` gate
/// config.
const int defaultRecordMaxFields = 5;

/// Runs the shared record scan over [context] and reports only
/// [kinds]; the three record gates call this with their own kind set
/// (and [maxFields] for the `record_size` cap).
GateResult runRecordGate(
  GateContext context,
  String id,
  Set<RecordFindingKind> kinds, {
  int maxFields = defaultRecordMaxFields,
}) {
  final violations = <GateViolation>[];
  var signatures = 0;
  for (final file in context.files) {
    final parsed = context.parsed(file);
    final scanner = RecordTypesScanner(
      parsed.lineInfo,
      maxFields: maxFields,
    );
    parsed.unit.accept(scanner);
    signatures += scanner.signatures;
    for (final finding in scanner.findings) {
      if (!kinds.contains(finding.kind)) continue;
      violations.add(
        GateViolation(
          file: context.relativePath(file),
          line: finding.line,
          message: finding.message,
        ),
      );
    }
  }
  return violations.isEmpty
      ? GateResult.pass(id, summary: _passSummary(id, signatures))
      : GateResult.fail(id, violations, summary: _failSummary(id, violations));
}

String _passSummary(String id, int signatures) => switch (id) {
      'record_named_fields' =>
        '$signatures signatures checked, record fields named',
      'inline_record_types' =>
        '$signatures signatures checked, no inline record types',
      _ => '$signatures signatures checked, no records over the field cap',
    };

String _failSummary(String id, List<GateViolation> violations) => switch (id) {
      'record_named_fields' =>
        '${violations.length} positional record fields or .\$N accesses',
      'inline_record_types' =>
        '${violations.length} inline record types in signatures',
      _ => '${violations.length} records over the field cap',
    };

/// Walks a compilation unit collecting record-shape findings for the
/// three record gates.
///
/// Function-like declarations have their signature types scanned for
/// inline record type annotations (outermost only — a nested record
/// inside a flagged shape is part of the same fix). Record type
/// aliases are the blessed named declaration: their internals produce
/// no inline/positional findings, but their field count still counts
/// towards [maxFields]. Bodies are still descended for local functions
/// and lambdas; positional `.$N` accesses are collected everywhere
/// except inside record alias declarations.
class RecordTypesScanner extends RecursiveAstVisitor<void> {
  /// Creates a scanner; [maxFields] caps the field count of a record
  /// type before the `oversized` kind fires.
  RecordTypesScanner(this._lineInfo, {this.maxFields = defaultRecordMaxFields});

  final LineInfo _lineInfo;
  final RegExp _positionalAccess = RegExp(r'^\$\d+$');

  /// Maximum record field count before a record should become a class.
  final int maxFields;

  /// Findings, in source order.
  final List<RecordFinding> findings = [];

  /// Number of signatures scanned.
  int signatures = 0;

  /// Offsets of record type annotations already reported — a named
  /// function and its inner [FunctionExpression] share the parameters.
  final Set<int> _reportedShapeOffsets = {};

  late final _TypeWalker _typeWalker = _TypeWalker(this);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    signatures++;
    _scanTypes(node.returnType, node.functionExpression.parameters);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    signatures++;
    _scanTypes(node.returnType, node.parameters);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    signatures++;
    _scanTypes(null, node.parameters);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A named function's FunctionExpression wraps the same parameters
    // its FunctionDeclaration already scanned.
    if (node.parent is! FunctionDeclaration) {
      signatures++;
      _scanTypes(null, node.parameters);
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    // `typedef Pair = (int, int);` — the record type IS the named
    // declaration, so its internals stay unscanned; only the field
    // count applies (an oversized record should become a class
    // wherever it is declared). Any other aliased type still gets
    // scanned: an inline record inside
    // `typedef F = int Function((int, int));` is an anonymous shape
    // that merely hides behind a function-type name.
    final aliased = node.type;
    if (aliased is RecordTypeAnnotation) {
      _checkSize(aliased, "typedef ${node.name.lexeme}");
      _sizeWalkFields(aliased);
    } else {
      aliased.accept(_typeWalker);
      aliased.accept(_sizeWalker);
    }
  }

  /// Sizes the nested records of [node] without re-flagging the root.
  void _sizeWalkFields(RecordTypeAnnotation node) {
    for (final field in node.positionalFields) {
      field.type.accept(_sizeWalker);
    }
    for (final field in node.namedFields?.fields ?? const []) {
      field.type.accept(_sizeWalker);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    // Legacy `typedef R f(int x);` form — a function declaration with
    // a name, scanned like any signature.
    signatures++;
    _scanTypes(node.returnType, node.parameters);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkAccess(node.identifier.name, node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _checkAccess(node.propertyName.name, node);
    super.visitPropertyAccess(node);
  }

  void _checkAccess(String name, AstNode node) {
    if (!_positionalAccess.hasMatch(name)) return;
    findings.add(
      RecordFinding(
        RecordFindingKind.positionalAccess,
        _line(node),
        "positional record field access '.$name' — use a named field "
        'or a destructuring pattern',
      ),
    );
  }

  void _scanTypes(TypeAnnotation? returnType, FormalParameterList? params) {
    if (returnType != null) {
      returnType.accept(_typeWalker);
      returnType.accept(_sizeWalker);
    }
    for (final param in params?.parameters ?? const <FormalParameter>[]) {
      final type = param.type;
      if (type == null) continue;
      type.accept(_typeWalker);
      type.accept(_sizeWalker);
    }
  }

  late final _SizeWalker _sizeWalker = _SizeWalker(this);

  void _recordShape(RecordTypeAnnotation node) {
    if (!_reportedShapeOffsets.add(node.offset)) return;
    final shape = node.toString();
    // A named positional field (`(int x, int y)`) is documented and
    // name-accessible; only fields without a name carry the `.$N`
    // fingerprint. The `{...}` group is named by construction.
    final unnamedCount =
        node.positionalFields.where((f) => f.name == null).length;
    if (unnamedCount > 0) {
      findings.add(
        RecordFinding(
          RecordFindingKind.unnamedFields,
          _line(node),
          "record type '$shape' in signature: "
          '$unnamedCount unnamed field(s) — name the fields '
          '({int x, ...}) and declare the shape as a typedef',
        ),
      );
    }
    // Every inline shape is gate 2's concern, named fields or not:
    // move the shape behind one named declaration.
    findings.add(
      RecordFinding(
        RecordFindingKind.inlineType,
        _line(node),
        "inline record type '$shape' in signature — declare the "
        'shape as a typedef and reference it by name',
      ),
    );
  }

  void _checkSize(RecordTypeAnnotation node, String label) {
    final count = _fieldCount(node);
    if (count <= maxFields) return;
    findings.add(
      RecordFinding(
        RecordFindingKind.oversized,
        _line(node),
        '$label has $count fields > max $maxFields — transform the '
        'record into a class',
      ),
    );
  }

  /// Total field count: positional plus named fields.
  static int _fieldCount(RecordTypeAnnotation node) =>
      node.positionalFields.length + (node.namedFields?.fields.length ?? 0);

  int _line(AstNode node) =>
      _lineInfo.getLocation(node.beginToken.offset).lineNumber;
}

/// Scans a type annotation subtree for record type annotations,
/// reporting only the outermost one of a nested group: an inner record
/// inside a flagged shape is fixed by the same typedef extraction.
class _TypeWalker extends RecursiveAstVisitor<void> {
  _TypeWalker(this._scanner);

  final RecordTypesScanner _scanner;

  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) {
    _scanner._recordShape(node);
  }
}

/// Sizes every record type annotation in a subtree — including records
/// nested inside other records: a six-field record is a class-to-be
/// wherever it hides. Findings are gated to
/// [RecordFindingKind.oversized].
class _SizeWalker extends RecursiveAstVisitor<void> {
  _SizeWalker(this._scanner);

  final RecordTypesScanner _scanner;

  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) {
    _scanner._checkSize(node, "record type '$node'");
    super.visitRecordTypeAnnotation(node);
  }
}
