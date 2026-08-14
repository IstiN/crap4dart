import 'package:crap4dart/src/gates/complexity_gate.dart';
import 'package:crap4dart/src/gates/method_size_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('complexity entries override the threshold per path', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final branches = List.generate(10, (i) => 'if (x > $i) { x++; }').join('');
    writeFile(project, 'lib/gen/tables.dart', '''
int tables(int x) {
  $branches
  return x;
}
''');
    final result = await ComplexityGate().run(
      makeContext(
        project,
        ['lib/gen/tables.dart'],
        configYaml: '''
gates:
  complexity:
    max_complexity: 5
    entries:
      - max_complexity: 15
        paths: ['lib/gen/**']
''',
      ),
    );
    expect(result.passed, isTrue);
  });

  test('method_size entries override limits per path', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/test_helpers.dart', '''
int helper(int a) {
  return a;
}
''');
    final result = await MethodSizeGate().run(
      makeContext(
        project,
        ['lib/test_helpers.dart'],
        configYaml: '''
gates:
  method_size:
    max_params: 2
    entries:
      - max_params: 6
        paths: ['lib/test_helpers.dart']
''',
      ),
    );
    expect(result.passed, isTrue);
  });
}
