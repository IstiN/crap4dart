import 'dart:io';

import 'package:crap4dart/src/gates/duplication_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = DuplicationGate();

  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  test('respects min_tokens', () async {
    const smallBody = '''
  if (value == null) {
    return;
  }
  for (var i = 0; i < value.length; i++) {
    print(value[i]);
  }
''';
    writeFile(
      project,
      'lib/a.dart',
      'void a(List<String> value) {\n$smallBody}\n'
          '\n'
          'void b(List<String> value) {\n$smallBody}\n',
    );
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n  duplication:\n    min_tokens: 100\n',
      ),
    );
    expect(result.passed, isTrue);
  });

  test('respects min_lines', () async {
    const denseBody = '''
  a(); b(); c(); d(); e(); f(); g(); h(); i(); j();
  k(); l(); m(); n(); o(); p(); q(); r(); s(); t();
  u(); v(); w(); x(); y(); z();
''';
    writeFile(
      project,
      'lib/a.dart',
      'void a() {\n$denseBody}\n'
          '\n'
          'void b() {\n$denseBody}\n',
    );
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n  duplication:\n    min_lines: 10\n',
      ),
    );
    expect(result.passed, isTrue);
  });
}
