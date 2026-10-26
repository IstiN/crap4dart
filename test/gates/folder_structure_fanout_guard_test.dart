import 'package:crap4dart/src/gates/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('exclude removes files and whole subtrees from the fan-out count',
      () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    writeFile(project, 'lib/src/generated/huge.g.dart', '// gen\n');
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_loose_files: 5\n'
            '    max_files: 3\n'
            "    exclude: ['**/generated/**']\n",
      ),
    );
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('loose count collapses generated siblings too', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/magic.dart', 'void m() {}\n');
    writeFile(project, 'lib/src/magic.g.dart', '// generated\n');
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

  test('no max_files keeps the fan-out check disabled', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 10; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  folder_structure:\n    dirs: [lib/src]\n',
      ),
    );
    expect(result.passed, isFalse); // loose sprawl still applies
    expect(
      result.violations.every((v) => v.message.contains('loose')),
      isTrue,
    );
  });
}
