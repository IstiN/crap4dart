import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'gate_test_utils.dart';

/// Two ignorable gates violating the same line: `public_docs` (public
/// class without dartdoc) and `magic_constants` (hex color outside a
/// constant).
String _fixture({required String trailing, String? header}) =>
    "${header ?? ''}class Big { int color = 0xFF00FF00; }$trailing\n";

String _config() => '''
gates:
  public_docs:
    ignorable: true
  magic_constants:
    ignorable: true
''';

Future<Map<String, GateResult>> _run(Map<String, String> files) async {
  final project = createTempProject();
  addTearDown(() => project.deleteSync(recursive: true));
  for (final entry in files.entries) {
    writeFile(project, entry.key, entry.value);
  }
  final run = await GateRunner().run(
    makeContext(
      project,
      files.keys.map((f) => p.join(project.path, f)).toList(),
      configYaml: _config(),
    ),
  );
  return {for (final r in run.results) r.gateId: r};
}

GateResult _docs(Map<String, GateResult> results) => results['public_docs']!;
GateResult _magic(Map<String, GateResult> results) =>
    results['magic_constants']!;

void main() {
  test('ignore-file: suppresses the named gates file-wide', () async {
    final results = await _run({
      'lib/a.dart':
          _fixture(header: '// ignore-file:public_docs\n', trailing: ''),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isFalse);
  });

  test('a bare ignore-file: suppresses everything ignorable', () async {
    final results = await _run({
      'lib/a.dart': _fixture(header: '// ignore-file:\n', trailing: ''),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });

  test('legacy crap:ignore markers keep suppressing all gates', () async {
    final results = await _run({
      'lib/a.dart': _fixture(trailing: ' // crap:ignore'),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });

  test('an unknown gate id in the list matches nothing', () async {
    final results = await _run({
      'lib/a.dart': _fixture(trailing: ' // ignore:magic_constants_typo'),
    });
    expect(_magic(results).passed, isFalse);
    expect(_docs(results).passed, isFalse);
  });
}
