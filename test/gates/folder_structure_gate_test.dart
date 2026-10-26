import 'package:crap4dart/src/gates/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('folder_structure flags loose-file sprawl', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/a.dart', 'void a() {}\n');
    writeFile(project, 'lib/src/b.dart', 'void b() {}\n');
    writeFile(project, 'lib/src/c.dart', 'void c() {}\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  folder_structure:\n    dirs: [lib/src]\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('3 loose .dart files'));
    expect(result.violations.single.message, contains('lib/src'));
  });

  test('folder_structure passes organized directories', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/web_search/search.dart', 'void s() {}\n');
    writeFile(project, 'lib/src/tools/ask.dart', 'void a() {}\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  folder_structure:\n    dirs: [lib/src]\n',
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('files in subdirectories never count toward the parent', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    // The parent holds 1 direct file; its subdir holds 20. A parent is
    // judged on its own contents only — nested dirs are the organized
    // form, and subtree sums would turn every project root into a mess.
    writeFile(project, 'lib/README.dart', '// entry\n');
    for (var i = 0; i < 20; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib]\n'
            '    max_loose_files: 2\n',
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
