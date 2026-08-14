import 'package:crap4dart/src/gates/banned_imports_gate.dart';
import 'package:crap4dart/src/gates/gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('banned_imports flags imports forbidden by rules', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'pubspec.yaml', 'name: myapp\n');
    writeFile(project, 'lib/ui/page.dart', '''
import 'package:myapp/src/data/repo.dart';
import 'dart:io';

void build() {}
''');
    writeFile(project, 'lib/data/other.dart', '''
import 'package:myapp/src/data/repo.dart';

void x() {}
''');
    final result = await BannedImportsGate().run(
      makeContext(
        project,
        ['lib/ui/page.dart', 'lib/data/other.dart'],
        configYaml: '''
gates:
  banned_imports:
    rules:
      - from: 'lib/ui/**'
        forbid:
          - '**/data/**'
          - 'dart:io'
        message: UI must not touch data or IO
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
    expect(
      result.violations.every((v) => v.file == 'lib/ui/page.dart'),
      isTrue,
    );
    expect(
      result.violations.every((v) => v.message.contains('banned')),
      isTrue,
    );
  });

  test('banned_imports passes with no rules', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', "import 'dart:io';\nvoid a() {}\n");
    final result =
        await BannedImportsGate().run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  _packageUriResolutionTests();
  _relativeImportResolutionTests();
}

/// How `package:` import URIs resolve to project-relative paths.
void _packageUriResolutionTests() {
  test('package:<self> imports match rules by their resolved path', () async {
    final result = await _runOverSingleImport(
      importLine: 'import \'package:myapp/src/data/repo.dart\';',
      forbid: ['lib/src/data/**'],
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.file, 'lib/ui/page.dart');
    expect(
      result.violations.single.message,
      contains('package:myapp/src/data/repo.dart'),
    );
  });

  test('package:<other> imports never match by resolved path', () async {
    final result = await _runOverSingleImport(
      importLine: 'import \'package:other/src/data/repo.dart\';',
      forbid: ['lib/src/data/**'],
    );
    expect(result.passed, isTrue);
    expect(result.summary, contains('comply'));
  });
}

/// How relative import URIs resolve against the importing file.
void _relativeImportResolutionTests() {
  test('relative imports resolve against the importing file directory',
      () async {
    final result = await _runOverSingleImport(
      importLine: 'import \'../data/repo.dart\';',
      forbid: ['lib/data/**'],
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.message,
      contains('../data/repo.dart'),
    );
  });
}

/// Runs the gate over one `lib/ui/page.dart` importing [importLine],
/// forbidden by [forbid] globs, in a `name: myapp` project.
Future<GateResult> _runOverSingleImport({
  required String importLine,
  required List<String> forbid,
}) async {
  final project = createTempProject();
  addTearDown(() => project.deleteSync(recursive: true));
  writeFile(project, 'pubspec.yaml', 'name: myapp\n');
  writeFile(project, 'lib/ui/page.dart', '''
$importLine

void build() {}
''');
  final forbidYaml = [for (final f in forbid) '          - \'$f\''].join('\n');
  return BannedImportsGate().run(
    makeContext(
      project,
      ['lib/ui/page.dart'],
      configYaml: '''
gates:
  banned_imports:
    rules:
      - from: 'lib/ui/**'
        forbid:
$forbidYaml
''',
    ),
  );
}
