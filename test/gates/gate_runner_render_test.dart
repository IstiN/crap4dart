import 'dart:io';

import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', '''
/// A documented function.
void documented() {}
''');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('render shows status lines and truncates long violation lists',
      () async {
    for (var i = 0; i < 25; i++) {
      writeFile(project, 'lib/file_$i.dart', 'void undocumented$i() {}\n');
    }
    final runner = GateRunner();
    final files = [
      for (var i = 0; i < 25; i++) 'lib/file_$i.dart',
    ];
    final result = await runner.run(
      makeContext(project, files),
      only: {'public_docs'},
    );
    final output = runner.render(result);
    expect(output, contains('[FAIL] public_docs'));
    expect(output, contains('... and 5 more'));
    expect(output, contains('1 failed'));
  });

  test('render marks skipped gates', () async {
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/a.dart'], configYaml: '''
coverage:
  required: false
gates:
  golden:
    enabled: false
'''),
    );
    final output = runner.render(result);
    expect(output, contains('[SKIP] golden: disabled in config'));
    expect(output, contains('[PASS] loc'));
  });
}
