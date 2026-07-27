import 'dart:io';

import 'package:crap4dart/src/gates/golden_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = GoldenGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
    makeFlutterProject(project);
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('passes when all widgets have golden tests via import', () async {
    writeFile(project, 'lib/widgets/my_widget.dart', '''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
    writeFile(project, 'test/my_widget_test.dart', '''
import 'package:fixture/widgets/my_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('golden', (tester) async {
    await expectLater(find.byType(SizedBox), matchesGoldenFile('my.png'));
  });
}
''');
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue);
    expect(result.summary, contains('1/1 widgets'));
  });
}
