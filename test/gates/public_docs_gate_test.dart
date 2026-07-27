import 'dart:io';

import 'package:crap4dart/src/gates/public_docs_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = PublicDocsGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('passes documented public API', () async {
    writeFile(project, 'lib/a.dart', '''
/// A documented class.
class A {
  /// A documented method.
  void f() {}

  /// A documented field.
  final int x = 0;
}

/// A documented function.
void g() {}
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('flags undocumented public declarations', () async {
    writeFile(project, 'lib/a.dart', '''
class Undocumented {
  void method() {}

  final int field = 0;
}

void topLevel() {}

const answer = 42;
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).join('\n');
    expect(messages, contains('class "Undocumented"'));
    expect(messages, contains('method "method"'));
    expect(messages, contains('field "field"'));
    expect(messages, contains('function "topLevel"'));
    expect(messages, contains('variable "answer"'));
  });

  test('exempts private and @override members', () async {
    writeFile(project, 'lib/a.dart', '''
class A {
  void _private() {}

  @override
  String toString() => 'A';
}
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    // Only the class itself is flagged; its members are exempt.
    expect(result.violations, hasLength(1));
    expect(result.violations.single.message, contains('class "A"'));
  });

  test('skips files under the exclude globs', () async {
    writeFile(project, 'test/a_test.dart', '''
class Undocumented {}
''');
    final result = await gate.run(makeContext(project, ['test/a_test.dart']));
    expect(result.passed, isTrue);
  });
}
