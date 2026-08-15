import 'package:crap4dart/src/gates/test_assertions_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('test_assertions flags tests without assertions', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'test/widget_test.dart', '''
import 'package:test/test.dart';

void main() {
  test('good test', () {
    expect(1 + 1, 2);
  });

  test('empty test', () {
    print('nothing asserted');
  });

  testWidgets('golden shot', (tester) async {
    await tester.pumpWidget(const MyWidget());
  });

  testWidgets('golden verified', (tester) async {
    await expectLater(find.byType(MyWidget), matchesGoldenFile('x.png'));
  });
}
''');
    final result = await TestAssertionsGate().run(
      makeContext(project, ['test/widget_test.dart']),
    );
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).toList();
    expect(messages.where((m) => m.contains('empty test')), hasLength(1));
    expect(messages.where((m) => m.contains('golden shot')), hasLength(1),
        reason: 'matchesGoldenFile is not an assertion');
    expect(messages.where((m) => m.contains('good test')), isEmpty);
    expect(messages.where((m) => m.contains('golden verified')), isEmpty);
  });

  test('test_assertions counts assertions in nested groups', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'test/grouped_test.dart', '''
import 'package:test/test.dart';

void main() {
  group('area', () {
    test('deeply empty', () {
      final x = 1;
      print(x);
    });
  });
}
''');
    final result = await TestAssertionsGate().run(
      makeContext(project, ['test/grouped_test.dart']),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('deeply empty'));
  });
}
