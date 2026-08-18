import 'package:crap4dart/src/gates/test_assertions_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('test_assertions ignores trailing named arguments such as skip:',
      () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'test/skip_test.dart', '''
import 'package:test/test.dart';

void main() {
  test('skipped but empty', () {
    print('nothing asserted');
  }, skip: true);

  test('asserted despite skip', () {
    expect(1 + 1, 2);
  }, skip: true);

  testWidgets('widget skipped but empty', (tester) async {
    await tester.pumpWidget(const MyWidget());
  }, skip: true);

  testWidgets('widget asserted despite timeout', (tester) async {
    await expectLater(find.byType(MyWidget), matchesGoldenFile('x.png'));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
''');
    final result = await TestAssertionsGate().run(
      makeContext(project, ['test/skip_test.dart']),
    );
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).toList();
    expect(
        messages.where((m) => m.contains("'skipped but empty'")), hasLength(1),
        reason: 'skip: should not hide missing assertions');
    expect(messages.where((m) => m.contains("'widget skipped but empty'")),
        hasLength(1));
    expect(messages.where((m) => m.contains('asserted despite skip')), isEmpty);
    expect(messages.where((m) => m.contains('widget asserted despite timeout')),
        isEmpty);
  });
}
