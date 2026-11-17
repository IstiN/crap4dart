import 'package:crap4dart/src/gates/gate_ids.dart';
import 'package:crap4dart/src/gates/quality/implicit_state_gate.dart';
import 'package:test/test.dart';

import '../gate_test_utils.dart';
import 'implicit_state_fixtures.dart';

void main() {
  test('flags a lifecycle-flag cluster mutated across methods', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/cluster.dart', clusterSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/cluster.dart']));
    expect(result.passed, isFalse);
    final cluster = result.violations
        .where((v) => v.message.contains('boolean-cluster'))
        .toList();
    expect(cluster, hasLength(1));
    expect(cluster.single.line, 1);
  });

  test('respects min_flags for the cluster finding', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/small.dart', twoFlagsSource);
    final context = makeContext(
      root,
      ['lib/small.dart'],
      configYaml: 'gates:\n  implicit_state:\n    min_flags: 3\n',
    );
    final result = await const ImplicitStateGate().run(context);
    expect(
      result.violations.where((v) => v.message.contains('boolean-cluster')),
      isEmpty,
      reason: '2 flags < min_flags 3: no cluster finding',
    );
  });

  test('reports a single flag mutated from many places', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/one_flag.dart', oneFlagSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/one_flag.dart']));
    final findings =
        result.violations.where((v) => v.message.contains("'isDone'")).toList();
    expect(findings, hasLength(1));
    expect(findings.single.line, 2);
  });

  test('final and static bool fields are ignored', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/immutable.dart', immutableSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/immutable.dart']));
    expect(result.violations, isEmpty);
  });

  test('non-state bool fields are ignored', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/muted.dart', mutedSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/muted.dart']));
    expect(result.violations, isEmpty);
  });

  test('gate id and pass summary', () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'lib/clean.dart', cleanSource);
    final result = await const ImplicitStateGate()
        .run(makeContext(root, ['lib/clean.dart']));
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
    expect(const ImplicitStateGate().id, GateIds.implicitState);
  });
}
