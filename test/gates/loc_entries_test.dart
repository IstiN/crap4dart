import 'package:crap4dart/src/gates/loc_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('loc entries relax the limit for matching paths', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final filler = List.filled(120, '// filler\n').join();
    writeFile(project, 'lib/legacy/big.dart', filler);
    writeFile(project, 'lib/new.dart', '// small\n');
    final result = await LocGate().run(
      makeContext(
        project,
        ['lib/legacy/big.dart', 'lib/new.dart'],
        configYaml: '''
gates:
  loc:
    max_lines: 100
    entries:
      - max_lines: 200
        paths: ['lib/legacy/**']
''',
      ),
    );
    expect(result.passed, isTrue);
  });

  test('loc entries tighten the limit for matching paths', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final filler = List.filled(120, '// filler\n').join();
    writeFile(project, 'lib/src/strict.dart', filler);
    final result = await LocGate().run(
      makeContext(
        project,
        ['lib/src/strict.dart'],
        configYaml: '''
gates:
  loc:
    max_lines: 800
    entries:
      - max_lines: 100
        paths: ['lib/src/**']
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('max 100'));
  });
}
