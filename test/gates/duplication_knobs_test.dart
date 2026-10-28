import 'dart:io';

import 'package:crap4dart/src/gates/quality/duplication_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = DuplicationGate();

  const clonesConfig = 'gates:\n  duplication:\n    report: clones\n';

  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  test('ignore_identifiers detects clones renamed anywhere', () async {
    const template = '''
void NAME(List<String> items, String sep) {
  final buffer = StringBuffer();
  for (final element in items) {
    buffer.write(element.toUpperCase());
    buffer.write(sep);
  }
  print(buffer.toString());
  print(buffer.length);
  print(buffer.isEmpty);
  print(buffer.isNotEmpty);
}
''';
    writeFile(project, 'lib/a.dart', template.replaceAll('NAME', 'first'));
    writeFile(
      project,
      'lib/b.dart',
      template.replaceAll('NAME', 'second').replaceAll('buffer', 'out'),
    );
    const identifiersConfig = 'gates:\n  duplication:\n'
        '    report: clones\n'
        '    ignore_identifiers: true\n';
    final result = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: identifiersConfig),
    );
    expect(result.passed, isFalse, reason: result.violations.toString());
  });

  test('ignore_imports keeps import boilerplate out of clones', () async {
    const imports = '''
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart';
import 'package:glob/glob.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
''';
    const tiny = '''
void tinyFn(List<String> items) {
  final first = items.first;
  final last = items.last;
  print(first);
  print(last);
}
''';
    writeFile(project, 'lib/a.dart', '$imports$tiny');
    writeFile(project, 'lib/b.dart', '$imports$tiny');
    // Without the flag, the import block + function clears min_tokens.
    final raw = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: clonesConfig),
    );
    expect(raw.passed, isFalse, reason: raw.summary);
    // With the flag only the sub-min_tokens function remains.
    const ignoreImports = 'gates:\n  duplication:\n'
        '    report: clones\n'
        '    ignore_imports: true\n';
    final result = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: ignoreImports),
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });
}
