import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The `named_record_shapes` gate: record shapes must live behind one
/// named declaration, and record fields must be named.
///
/// Three violation kinds:
/// 1. an inline record type annotation in a function signature (return
///    type or parameter type, including nested in `Future<...>` type
///    arguments) — consumers diff the shape field-by-field instead of
///    going to one type definition, and "similar but not exact" inline
///    shapes silently drift apart; declare the shape as a `typedef`
///    (or a class when nominal identity is needed) and reference it by
///    name;
/// 2. a positional (unnamed) record field in a signature — `.$1`-style
///    access carries zero self-documentation; use named fields
///    (`({int x, int y})`);
/// 3. a positional field access (`.$1`, `.$2`, ...) anywhere — the
///    fingerprint of kinds 1-2; always replaceable by a named field or
///    a destructuring pattern.
///
/// Record *values* (literals, locals, destructuring patterns) remain
/// legal — only type annotations in signatures are regulated. Record
/// type *aliases* (`typedef Pair = (int, int);`) are the blessed form:
/// their internals are not scanned.
///
/// Default severity is `warning`: a positional shape is a readability
/// debt, not a bug.
class NamedRecordShapesGate implements Gate {
  /// Creates a [NamedRecordShapesGate].
  const NamedRecordShapesGate();

  @override
  String get id => 'named_record_shapes';

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    var signatures = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final scanner = _ShapeScanner(parsed.lineInfo);
      parsed.unit.accept(scanner);
      signatures += scanner.signatures;
      for (final finding in scanner.findings) {
        violations.add(
          GateViolation(
            file: context.relativePath(file),
            line: finding.line,
            message: finding.message,
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$signatures signatures checked, no anonymous record shapes'
        : '${violations.length} anonymous record shapes: inline record '
            'types, positional signature fields or .\$N accesses';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

/// One gate finding: message plus its 1-based line.
class _Finding {
  /// Creates a finding.
  const _Finding(this.line, this.message);

  /// 1-based source line.
  final int line;

  /// Human readable description.
  final String message;
}

/// Walks a compilation unit collecting anonymous record shapes.
///
/// Function-like declarations have their signature types scanned for
/// inline record type annotations (outermost only — a nested record
/// inside a flagged shape is part of the same fix). Type aliases are
/// skipped entirely: their internals are the blessed named declaration.
/// Bodies are still descended for local functions and lambdas.
class _ShapeScanner extends RecursiveAstVisitor<void> {
  _ShapeScanner(this._lineInfo);

  final LineInfo _lineInfo;
  final RegExp _positionalAccess = RegExp(r'^\$\d+$');

  /// Findings, in source order.
  final List<_Finding> findings = [];

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
    // declaration, so its internals stay unscanned. Any other aliased
    // type still gets scanned: an inline record inside
    // `typedef F = int Function((int, int));` is an anonymous shape
    // that merely hides behind a function-type name.
    if (node.type is! RecordTypeAnnotation) {
      node.type.accept(_typeWalker);
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
      _Finding(
        _line(node),
        "positional record field access '.$name' — use a named field "
        'or a destructuring pattern',
      ),
    );
  }

  void _scanTypes(TypeAnnotation? returnType, FormalParameterList? params) {
    if (returnType != null) returnType.accept(_typeWalker);
    for (final param in params?.parameters ?? const <FormalParameter>[]) {
      param.type?.accept(_typeWalker);
    }
  }

  void _recordShape(RecordTypeAnnotation node) {
    if (!_reportedShapeOffsets.add(node.offset)) return;
    final positionalCount = node.positionalFields.length;
    final shape = node.toString();
    if (positionalCount > 0) {
      findings.add(
        _Finding(
          _line(node),
          "positional record type '$shape' in signature: "
          '$positionalCount positional field(s) — name the fields '
          '({int x, ...}) and declare the shape as a typedef',
        ),
      );
    } else {
      findings.add(
        _Finding(
          _line(node),
          "inline record type '$shape' in signature — declare the "
          'shape as a typedef and reference it by name',
        ),
      );
    }
  }

  int _line(AstNode node) =>
      _lineInfo.getLocation(node.beginToken.offset).lineNumber;
}

/// Scans a type annotation subtree for record type annotations,
/// reporting only the outermost one of a nested group: an inner record
/// inside a flagged shape is fixed by the same typedef extraction.
class _TypeWalker extends RecursiveAstVisitor<void> {
  _TypeWalker(this._scanner);

  final _ShapeScanner _scanner;

  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) {
    _scanner._recordShape(node);
  }
}
