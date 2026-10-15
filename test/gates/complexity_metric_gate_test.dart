import 'dart:io';
import 'package:crap4dart/src/gates/complexity_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = ComplexityGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('metric: cognitive scores flat chains cheaply', () async {
    writeFile(project, 'lib/a.dart', '''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  } else if (x < 10) {
    return 'small';
  } else if (x < 100) {
    return 'medium';
  }
  return 'large';
}
''');
    const cognitiveConfig = 'gates:\n  complexity:\n'
        '    metric: cognitive\n'
        '    max_complexity: 2\n';
    final cognitive = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: cognitiveConfig),
    );
    expect(cognitive.passed, isFalse);
    expect(
        cognitive.violations.single.message, contains('cognitive=4 > max 2'));
    expect(cognitive.summary, contains('cognitive limit'));
  });

  test('metric: cyclomatic stays the default and reports CC', () async {
    writeFile(project, 'lib/a.dart', '''
int f(int x) => x > 0 ? 1 : 0;
''');
    const cyclomaticConfig = 'gates:\n  complexity:\n'
        '    metric: cyclomatic\n'
        '    max_complexity: 1\n';
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: cyclomaticConfig),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('CC=2 > max 1'));
    expect(result.summary, contains('cyclomatic limit'));
  });
}
