import 'dart:io';

import 'package:crap4dart/src/gates/external_gate.dart';
import 'package:test/test.dart';

import 'external_tool_fixture.dart';
import 'gate_test_utils.dart';

void main() {
  const gate = ExternalGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('parses Checkstyle XML findings into violations', () async {
    final tool = writeFakeTool(project, ktlintFindingReport);
    writeFile(project, 'android/app/src/main/MainActivity.kt', 'class A\n');
    final result = await gate.run(externalContext(project, tool));
    expect(result.passed, isFalse);
    expect(
        result.violations.single.file, 'android/app/src/main/MainActivity.kt');
    expect(result.violations.single.line, 14);
    expect(result.violations.single.message, contains('LongMethod'));
  });

  test('passes when the tool finds nothing', () async {
    final tool = writeFakeTool(project, emptyReport);
    final result = await gate.run(externalContext(project, tool));
    expect(result.passed, isTrue);
    expect(result.summary, contains('1 tool(s) clean'));
  });

  test('passes with no rules configured', () async {
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue);
    expect(result.summary, contains('no tools configured'));
  });
}
