import 'package:crap4dart/src/gates/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('exclude removes files from the count', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    writeFile(project, 'lib/src/huge.g.dart', '// generated\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_files: 3\n'
            "    exclude: ['**.g.dart']\n",
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('deprecated max_loose_files alias keeps old configs working', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/a.dart', 'void a() {}\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_loose_files: 5\n',
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
