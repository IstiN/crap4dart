import 'dart:io';

import 'package:crap4dart/src/gates/golden_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

/// Writes CoveredWidget and UncoveredWidget fixture classes.
void writeGoldenWidgets(Directory project) {
  writeFile(project, 'lib/widgets/covered_widget.dart', '''
import 'package:flutter/material.dart';

class CoveredWidget extends StatelessWidget {
  const CoveredWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  writeFile(project, 'lib/widgets/uncovered_widget.dart', '''
import 'package:flutter/material.dart';

class UncoveredWidget extends StatefulWidget {
  const UncoveredWidget({super.key});

  @override
  State<UncoveredWidget> createState() => _UncoveredWidgetState();
}

class _UncoveredWidgetState extends State<UncoveredWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
}

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

  test('skips non-Flutter projects', () async {
    final plain = createTempProject();
    addTearDown(() => plain.deleteSync(recursive: true));
    final result = await gate.run(makeContext(plain, const []));
    expect(result.skipped, isTrue);
  });

  test('skips projects without widgets', () async {
    writeFile(project, 'lib/util.dart', 'int add(int a, int b) => a + b;\n');
    final result = await gate.run(makeContext(project, const []));
    expect(result.skipped, isTrue);
    expect(result.skipReason, 'no widgets found');
  });

  test('fails when widget coverage is below the minimum', () async {
    writeGoldenWidgets(project);
    writeFile(project, 'test/covered_widget_test.dart', '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders', (tester) async {
    await expectLater(
      find.byType(CoveredWidget),
      matchesGoldenFile('covered.png'),
    );
  });
}
''');
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse);
    expect(result.summary, contains('1/2 widgets'));
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.message,
      contains('UncoveredWidget has no golden test'),
    );
  });
}
