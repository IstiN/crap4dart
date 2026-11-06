import 'dart:io';

import 'package:crap4dart/src/gates/content/golden_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

/// Minimal widget so the gate does not skip on "no widgets found".
const _widget = '''
import 'package:flutter/material.dart';

class SampleWidget extends StatelessWidget {
  const SampleWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

/// A golden test that never varies theme or viewport.
const _flatGoldenTest = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture/sample_widget.dart';

void main() {
  testWidgets('sample golden', (tester) async {
    await tester.pumpWidget(const SampleWidget());
    await expectLater(find.byType(SampleWidget),
        matchesGoldenFile('goldens/sample.png'));
  });
}
''';

/// A golden test exercising both matrix axes (theme + viewport).
const _matrixGoldenTest = '''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture/sample_widget.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final surfaceSize in [phoneSize, desktopSize]) {
      testWidgets('sample \${brightness.name} \$surfaceSize',
          (tester) async {
        tester.view.physicalSize = surfaceSize;
        await tester.pumpWidget(SampleWidget(theme: ThemeData(
          brightness: brightness,
        )));
        await expectLater(find.byType(SampleWidget),
            matchesGoldenFile('goldens/sample.png'));
      });
    }
  }
}
''';

const _matrixConfig = '''
gates:
  golden:
    require_viewport_matrix: true
''';

void main() {
  const gate = GoldenGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
    makeFlutterProject(project);
    writeFile(project, 'lib/sample_widget.dart', _widget);
    writeFile(project, 'test/sample_golden_test.dart', _flatGoldenTest);
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('flags golden tests without theme and viewport variation', () async {
    final result = await gate.run(
      makeContext(project, const [], configYaml: _matrixConfig),
    );
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).join('\n');
    expect(messages, contains('never varies theme'));
    expect(messages, contains('viewport (phone/desktop)'));
    expect(
      result.violations.map((v) => v.file).toSet(),
      {'test/sample_golden_test.dart'},
    );
  });

  test('passes golden tests that vary both axes', () async {
    writeFile(project, 'test/sample_golden_test.dart', _matrixGoldenTest);
    final result = await gate.run(
      makeContext(project, const [], configYaml: _matrixConfig),
    );
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
  });

  test('matrix check is off by default', () async {
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
  });

  test('ignores test files without golden matchers', () async {
    writeFile(project, 'test/unit_test.dart', '''
void main() {
  // plain unit test, no matchesGoldenFile
}
''');
    final result = await gate.run(
      makeContext(project, const [], configYaml: _matrixConfig),
    );
    expect(
      result.violations.where((v) => v.file == 'test/unit_test.dart'),
      isEmpty,
    );
  });
}
