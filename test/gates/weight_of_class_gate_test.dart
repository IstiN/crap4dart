import 'package:crap4dart/src/gates/weight_of_class_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('weight_of_class fails data-heavy classes', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/dto.dart', '''
class Dto {
  String a = '';
  String b = '';
  String c = '';
  String d = '';
  void behave() {}
}
''');
    writeFile(project, 'lib/service.dart', '''
class Service {
  int x = 0;
  int a() => 1;
  int b() => 2;
  int c() => 3;
  int d() => 4;
}
''');
    final result = await WeightOfClassGate().run(
      makeContext(
        project,
        ['lib/dto.dart', 'lib/service.dart'],
        configYaml: 'gates:\n  weight_of_class:\n    enabled: true\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.file, 'lib/dto.dart');
    expect(result.violations.single.message, contains('weight='));
  });
}
