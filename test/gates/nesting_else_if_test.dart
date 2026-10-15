import 'package:crap4dart/src/gates/nesting_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('else-if chains are flat, not nested', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/chain.dart', '''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  } else if (x < 10) {
    return 'small';
  } else if (x < 100) {
    return 'medium';
  } else if (x < 1000) {
    return 'large';
  }
  return 'huge';
}
''');
    final result = await NestingGate().run(
      makeContext(
        project,
        ['lib/chain.dart'],
        configYaml: 'gates:\n  nesting:\n    max_nesting: 3\n',
      ),
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('an if nested in an else block is still nesting', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/nested.dart', '''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else {
    if (x == 0) {
      return 'zero';
    } else {
      if (x < 10) {
        return 'small';
      }
    }
  }
  return 'large';
}
''');
    final result = await NestingGate().run(
      makeContext(
        project,
        ['lib/nested.dart'],
        configYaml: 'gates:\n  nesting:\n    max_nesting: 2\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('nesting=3'));
  });
}
