import 'dart:io';

import 'package:crap4dart/src/gates/file_naming_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = FileNamingGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('honors extra allowed stems case-insensitively', () async {
    writeFile(project, 'lib/mqtt5.dart', 'void f() {}\n');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/mqtt5.dart'],
        configYaml: 'gates:\n  file_naming:\n    allow: [MQTT5]\n',
      ),
    );
    expect(result.passed, isTrue);
  });

  test('only the whole stem can be allowlisted', () async {
    writeFile(project, 'lib/report2.dart', 'void f() {}\n');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/report2.dart'],
        configYaml: 'gates:\n  file_naming:\n    allow: [report]\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.file, 'lib/report2.dart');
  });

  test('non-Dart files are not flagged', () async {
    final files = ['assets/numbers1.json', 'docs/part2.md'];
    for (final f in files) {
      writeFile(project, f, 'x\n');
    }
    final result = await gate.run(makeContext(project, files));
    expect(result.passed, isTrue);
  });
}
