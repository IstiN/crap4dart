import 'dart:io';

import 'package:crap4dart/src/gates/quality/public_docs_gate.dart';
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

  test('members of private containers are not public API', () async {
    writeFile(project, 'lib/a.dart', _containerPrivacyFixture);
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).join('\n');
    // Every public container kind flags its undocumented member; private
    // containers and the unnamed extension do not (the enclosing-privacy
    // walk covers all branches of `_DocsVisitor._enclosingIsPublic`).
    expect(
      result.violations.where((v) => v.message.contains('"undocumented"')),
      hasLength(5),
    );
    expect(messages, isNot(contains('_Private')));
    expect(messages, contains('function "topLevelUndocumented"'));
  });
}

/// Every container kind, public and private, plus an unnamed extension —
/// exercises all branches of `_DocsVisitor._enclosingIsPublic`.
const _containerPrivacyFixture = '''
class Public {
  void undocumented() {}
}

class _Private {
  void undocumented() {}
}

enum PublicEnum {
  a,
  b;

  void undocumented() {}
}

enum _PrivateEnum {
  a,
  b;

  void undocumented() {}
}

mixin PublicMixin {
  void undocumented() {}
}

mixin _PrivateMixin {
  void undocumented() {}
}

extension type PublicExt(int x) {
  void undocumented() {}
}

extension type _PrivateExt(int x) {
  void undocumented() {}
}

extension PublicNamed on int {
  void undocumented() {}
}

extension on int {
  void undocumented() {}
}

void topLevelUndocumented() {}
''';
