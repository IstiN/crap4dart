import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

String _docsConfig({required bool ignorable}) => '''
coverage:
  required: false
gates:
  public_docs:
    ignorable: $ignorable
''';

void main() {
  test('ignore markers are ignored unless ignorable is enabled', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final content = '''
// crap:ignore-file
class Big {}
''';
    writeFile(project, 'lib/a.dart', content);
    final strict = await GateRunner().run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: _docsConfig(ignorable: false),
      ),
    );
    final strictDocs =
        strict.results.singleWhere((r) => r.gateId == 'public_docs');
    expect(strictDocs.passed, isFalse,
        reason: 'ignore markers must not suppress without opt-in');

    final lenient = await GateRunner().run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: _docsConfig(ignorable: true),
      ),
    );
    final lenientDocs =
        lenient.results.singleWhere((r) => r.gateId == 'public_docs');
    expect(lenientDocs.passed, isTrue,
        reason: 'crap:ignore-file must suppress when opted in');
  });

  test('per-line crap:ignore suppresses when ignorable is enabled', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', 'void undocumented() {}\n');
    final result = await GateRunner().run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: _docsConfig(ignorable: true),
      ),
    );
    expect(result.passed, isFalse);

    writeFile(
      project,
      'lib/a.dart',
      '// crap:ignore\nvoid undocumented() {}\n',
    );
    final suppressed = await GateRunner().run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: _docsConfig(ignorable: true),
      ),
    );
    final docs =
        suppressed.results.singleWhere((r) => r.gateId == 'public_docs');
    expect(docs.passed, isTrue);
  });
}
