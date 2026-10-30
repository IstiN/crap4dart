import 'package:crap4dart/src/gates/usage/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('config gives each pattern its own cap', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 2; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    for (var i = 0; i < 10; i++) {
      writeFile(project, 'lib/src/generated/g$i.g.dart', '// gen\n');
    }
    final result = await const FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    config:\n'
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

  test('config takes precedence over dirs/max_loose_files', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (var i = 0; i < 3; i++) {
      writeFile(project, 'lib/src/f$i.dart', 'void f() {}\n');
    }
    final result = await const FolderStructureGate().run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib/src]\n'
            '    max_loose_files: 99\n'
            '    config:\n'
            '      lib/src: 2\n',
      ),
    );
    // dirs/max_loose_files are not consulted: the config cap 2 wins.
    expect(result.passed, isFalse, reason: '${result.violations}');
    expect(result.violations.single.message, contains('(max 2)'));
  });
}
