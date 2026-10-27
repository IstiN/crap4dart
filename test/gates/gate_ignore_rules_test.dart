import 'package:crap4dart/src/gates/gate.dart';
import 'package:path/path.dart' as p;
import 'package:crap4dart/src/gates/gate_runner.dart';
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
  test('ignore:magic_constants suppresses it but not public_docs', () async {
    final results = await _run({
      'lib/a.dart': _fixture(trailing: ' // ignore:magic_constants'),
    });
    expect(_magic(results).passed, isTrue);
    expect(_docs(results).passed, isFalse);
  });

  test('one rule per marker; several markers combine', () async {
    final results = await _run({
      'lib/a.dart': _fixture(
          trailing: ' // ignore:public_docs // ignore: magic_constants'),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });

  test('a comma-separated list is not a list — it names nothing', () async {
    final results = await _run({
      'lib/a.dart':
          _fixture(trailing: ' // ignore:public_docs,magic_constants'),
    });
    expect(_docs(results).passed, isFalse);
    expect(_magic(results).passed, isFalse);
  });

  test('several ignore comments on one line union', () async {
    final results = await _run({
      'lib/a.dart': _fixture(
          trailing: ' // ignore:public_docs // ignore:magic_constants'),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });

  test('the marker on the line above works', () async {
    final results = await _run({
      'lib/a.dart': _fixture(
          header: '// ignore:public_docs\n// ignore:magic_constants\n',
          trailing: ''),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });

  test('a bare ignore: suppresses every ignorable gate', () async {
    final results = await _run({
      'lib/a.dart': _fixture(trailing: ' // ignore:'),
    });
    expect(_docs(results).passed, isTrue);
    expect(_magic(results).passed, isTrue);
  });
}
