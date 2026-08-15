import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The `test_assertions` gate: flags `test()`/`testWidgets()` bodies
/// that contain fewer than `min_assertions` assertion calls
/// (`expect`, `expectLater`, `expectIdentical`, `fail`, `throwsA`).
///
/// A test without assertions compiles, runs green and verifies nothing
/// — a typical AI-generated placeholder.
class TestAssertionsGate implements Gate {
  /// Creates a [TestAssertionsGate].
  const TestAssertionsGate();

  /// Assertion-ish method names counted towards the minimum.
  static const Set<String> assertionNames = {
    'expect',
    'expectLater',
    'expectIdentical',
    'expectInOrder',
    'fail',
    'throwsA',
    'verify',
    'matchesGoldenFile',
  };

  @override
  String get id => 'test_assertions';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.testAssertions;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final visitor = _TestBodyVisitor(parsed.lineInfo);
      parsed.unit.accept(visitor);
      for (final candidate in visitor.tests) {
        checked++;
        if (candidate.assertions < config.minAssertions) {
          violations.add(
            GateViolation(
              file: context.relativePath(file),
              line: candidate.line,
              message: "'${candidate.name}' has ${candidate.assertions} "
                  'assertion(s) — a test without assertions verifies '
                  'nothing',
            ),
          );
        }
      }
    }
    final summary = violations.isEmpty
        ? '$checked tests assert their expectations'
        : '${violations.length}/$checked tests without assertions';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

class _TestCandidate {
  _TestCandidate(this.name, this.line, this.assertions);

  final String name;
  final int line;
  final int assertions;
}

/// Counts assertion calls inside `test()`/`testWidgets()` bodies.
class _TestBodyVisitor extends RecursiveAstVisitor<void> {
  _TestBodyVisitor(this._lineInfo);

  final LineInfo _lineInfo;
  final List<_TestCandidate> tests = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'test' || name == 'testWidgets') {
      _registerTest(node, name);
    }
    super.visitMethodInvocation(node);
  }

  void _registerTest(MethodInvocation node, String kind) {
    final args = node.argumentList.arguments;
    if (args.length < 2) return;
    final nameArg = args[0];
    final bodyArg = args[args.length - 1];
    final label = nameArg is StringLiteral ? nameLiteral(nameArg) : kind;
    final line = _lineInfo.getLocation(node.offset).lineNumber;
    final counter = _AssertionCounter();
    bodyArg.accept(counter);
    tests.add(_TestCandidate(label, line, counter.count));
  }

  String nameLiteral(StringLiteral node) {
    final value = node.stringValue;
    return value == null ? '<test>' : "'$value'";
  }
}

/// Counts assertion-ish invocations in a visited subtree.
class _AssertionCounter extends RecursiveAstVisitor<void> {
  int count = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (TestAssertionsGate.assertionNames.contains(node.methodName.name)) {
      count++;
    }
    super.visitMethodInvocation(node);
  }
}
