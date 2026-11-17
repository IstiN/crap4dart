import 'package:crap4dart/src/gates/quality/implicit_state_gate.dart';
import 'package:test/test.dart';

import '../gate_test_utils.dart';
import 'implicit_state_fixtures.dart';

void main() {
  test('reports a status field assigned from several methods', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/status.dart', statusSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/status.dart']));
    final findings = result.violations
        .where((v) => v.message.contains("status field 'status'"))
        .toList();
    expect(findings, hasLength(1));
  });

  test('min_mutators 2 skips a single mutation site', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/single.dart', onceSource);
    final context = makeContext(
      root,
      ['lib/single.dart'],
      configYaml: 'gates:\n  implicit_state:\n    min_mutators: 2\n',
    );
    final result = await const ImplicitStateGate().run(context);
    expect(result.violations, isEmpty);
  });

  test('min_mutators 1 reports single-place mutations', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/single.dart', onceSource);
    final context = makeContext(
      root,
      ['lib/single.dart'],
      configYaml: 'gates:\n  implicit_state:\n    min_mutators: 1\n',
    );
    final result = await const ImplicitStateGate().run(context);
    expect(result.violations, hasLength(1));
  });

  test('flags if-conditions branching on flag combinations', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/combo.dart', comboSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/combo.dart']));
    final combos = result.violations
        .where((v) => v.message.contains('state combination'))
        .toList();
    expect(combos, hasLength(1),
        reason: 'the if-condition reads two '
            'flags; getter bodies are not conditions in v1');
    expect(combos.single.line, 8);
  });

  test('member accesses and single-flag conditions are not combos', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/plain.dart', plainSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/plain.dart']));
    expect(
      result.violations.where((v) => v.message.contains('combination')),
      isEmpty,
    );
  });
}
