import 'package:crap4dart/src/gates/usage/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('max_loose_files counts only the directory itself', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 5; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_loose_files: 4\n',
      ),
    );
    expect(result.passed, isFalse, reason: '${result.violations}');
    expect(result.violations.single.message,
        contains('5 loose .dart files directly in lib/src'));
    expect(result.violations.single.message, contains('max 4'));
  });

  test('generated siblings collapse into one logical unit', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/magic.dart', 'void m() {}\n');
    writeFile(project, 'lib/src/magic.g.dart', '// generated\n');
    writeFile(project, 'lib/src/magic.freezed.dart', '// generated\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_loose_files: 2\n',
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('dirs glob expands to matching directories', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/one/f$i.dart', 'void f() {}\n');
    }
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/two/g$i.dart', 'void g() {}\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            "    dirs: ['lib/src/*']\n"
            '    max_loose_files: 2\n',
      ),
    );
    expect(result.passed, isFalse, reason: '${result.violations}');
    expect(result.violations, hasLength(2));
    expect(
      result.violations.map((v) => v.file).toSet(),
      {'lib/src/one', 'lib/src/two'},
    );
  });
}
