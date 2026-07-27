import 'dart:io';

import 'package:crap4dart/src/gates/loc_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = LocGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('passes when files are within the limit', () async {
    writeFile(project, 'lib/a.dart', 'void main() {}\n');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
    expect(result.skipped, isFalse);
    expect(result.violations, isEmpty);
  });

  test('fails files longer than max_lines', () async {
    final content = List.filled(150, '// filler\n').join();
    writeFile(project, 'lib/big.dart', content);
    final result = await gate.run(
      makeContext(
        project,
        ['lib/big.dart'],
        configYaml: 'gates:\n  loc:\n    max_lines: 100\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.file, 'lib/big.dart');
    expect(result.violations.single.message, contains('150 lines > max 100'));
  });

  test('honors the exclude globs', () async {
    final content = List.filled(150, '// filler\n').join();
    writeFile(project, 'lib/big.g.dart', content);
    final result = await gate.run(
      makeContext(
        project,
        ['lib/big.g.dart'],
        configYaml: 'gates:\n  loc:\n    max_lines: 100\n',
      ),
    );
    expect(result.passed, isTrue);
  });
}
