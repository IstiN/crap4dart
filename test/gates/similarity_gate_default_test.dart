import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import '../similarity/similarity_fixtures.dart';
import 'gate_test_utils.dart';

void main() {
  test('similarity gate is disabled by default — the runner skips it',
      () async {
    final root = createTempProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeFile(root, 'docs/a.md', proseA);
    writeFile(root, 'docs/b.md', proseA);
    final result = await GateRunner().run(
      makeContext(root, []),
    );
    final similarity =
        result.results.singleWhere((r) => r.gateId == 'similarity');
    expect(similarity.skipped, isTrue);
  });
}
