import 'package:crap4dart/src/gates/usage/folder_structure_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
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
            '    config:\n'
            "      'lib/src/**': 10\n"
            "      'lib/src/*': 1\n",
      ),
    );
    // tools matches both patterns; the first (cap 10) wins.
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('without config the list form applies unchanged', () async {
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
