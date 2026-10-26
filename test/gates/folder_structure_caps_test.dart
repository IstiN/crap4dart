import 'package:crap4dart/src/gates/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('dirs map gives each pattern its own cap', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 2; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    for (var i = 0; i < 10; i++) {
      writeFile(project, 'lib/src/generated/g$i.g.dart', '// gen\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs:\n'
            '      lib/src: 1\n'
            "      'lib/src/generated/**': 20\n",
      ),
    );
    // lib/src holds 2 units (cap 1) — flagged; generated holds 10
    // units but is stem-collapsed to 1 (cap 20) — clean.
    expect(result.passed, isFalse, reason: '${result.violations}');
    expect(result.violations.single.file, 'lib/src');
    expect(result.violations.single.message, contains('(max 1)'));
  });

  test('the list form keeps working unchanged', () async {
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

  test('a directory matched by several patterns uses the first cap', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/tools/f$i.dart', 'void f() {}\n');
    }
    final result = await FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs:\n'
            "      'lib/src/**': 10\n"
            "      'lib/src/*': 1\n",
      ),
    );
    // tools matches both patterns; the first (cap 10) wins.
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
