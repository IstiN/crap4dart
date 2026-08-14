import 'package:crap4dart/src/gates/class_size_gate.dart';
import 'package:crap4dart/src/gates/nesting_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('nesting passes shallow methods and fails deep ones', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/shallow.dart', '''
void shallow() {
  if (true) {
    print(1);
  }
}
''');
    writeFile(project, 'lib/deep.dart', '''
void deep() {
  if (true) {
    for (var i = 0; i < 3; i++) {
      while (true) {
        try {
          if (true) {
            print(1);
          }
        } on Exception {
          rethrow;
        }
      }
    }
  }
}
''');
    final result = await NestingGate().run(
      makeContext(
        project,
        ['lib/shallow.dart', 'lib/deep.dart'],
        configYaml: 'gates:\n  nesting:\n    max_nesting: 4\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.file, 'lib/deep.dart');
    expect(result.violations.single.message, contains('nesting='));
  });

  test('class_size fails classes over max_methods and max_wmc', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final methods = List.generate(
      12,
      (i) => '  int m$i(int x) { return x > $i ? x : -x; }',
    ).join('\n');
    writeFile(project, 'lib/god.dart', 'class God {\n$methods\n}\n');
    writeFile(project, 'lib/ok.dart', '''
class Ok {
  int a(int x) {
    if (x > 0) return x;
    return 0;
  }
}
''');
    final result = await ClassSizeGate().run(
      makeContext(
        project,
        ['lib/god.dart', 'lib/ok.dart'],
        configYaml:
            'gates:\n  class_size:\n    max_methods: 10\n    max_wmc: 10\n',
      ),
    );
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).toList();
    expect(messages.any((m) => m.contains('12 methods')), isTrue);
    expect(messages.any((m) => m.contains('WMC=')), isTrue);
    expect(result.violations.every((v) => v.file == 'lib/god.dart'), isTrue);
  });
}
