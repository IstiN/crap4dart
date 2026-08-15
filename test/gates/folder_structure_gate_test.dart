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
    writeFile(project, 'lib/src/web_search/search.dart', 'void s() {}\n');
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

  test('folder_structure honors max_loose_files', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/one.dart', 'void one() {}\n');
    writeFile(project, 'lib/two.dart', 'void two() {}\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  folder_structure:\n    max_loose_files: 3\n',
      ),
    );
    expect(result.passed, isTrue);
  });
}
