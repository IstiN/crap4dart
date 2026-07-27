import 'dart:io';

import 'package:path/path.dart' as p;

/// Path to the crap4dart executable under test.
final String binScript = p.normalize(
  p.join(Directory.current.path, 'bin', 'crap4dart.dart'),
);

/// Creates a temporary project directory for CLI tests.
Directory createCliTestProject() =>
    Directory.systemTemp.createTempSync('crap4dart_cli_test_');

/// Runs the crap4dart CLI in [workDir] with [args].
Future<ProcessResult> runCli(Directory workDir, List<String> args) =>
    Process.run(
      'dart',
      ['run', binScript, ...args],
      workingDirectory: workDir.path,
    );

/// LCOV fixture: `risky()` in lib/sample.dart fully uncovered.
const String zeroCoverageLcov = '''
SF:lib/sample.dart
DA:1,0
DA:2,0
DA:3,0
DA:4,0
DA:5,0
DA:7,0
end_of_record
''';

/// LCOV fixture: `risky()` in lib/sample.dart fully covered.
const String fullCoverageLcov = '''
SF:lib/sample.dart
DA:1,1
DA:2,1
DA:3,1
DA:4,1
DA:5,1
DA:7,1
end_of_record
''';

/// Writes the shared mini project: lib/sample.dart with `risky()` (CC 3)
/// and coverage/lcov.info with the given [lcov] content.
void writeMiniProject(Directory root, {required String lcov}) {
  Directory(p.join(root.path, 'lib')).createSync();
  File(p.join(root.path, 'lib', 'sample.dart')).writeAsStringSync('''
int risky(int x) {
  if (x > 0) {
    return x;
  } else if (x < 0) {
    return -x;
  }
  return 0;
}
''');
  Directory(p.join(root.path, 'coverage')).createSync();
  File(p.join(root.path, 'coverage', 'lcov.info')).writeAsStringSync(lcov);
}

/// Writes a minimal project that passes all enabled gates.
void writeCleanProject(Directory root) {
  Directory(p.join(root.path, 'lib')).createSync();
  File(p.join(root.path, 'lib', 'a.dart')).writeAsStringSync('''
/// A documented function.
void documented() {}
''');
  File(p.join(root.path, 'crap4dart.yaml')).writeAsStringSync('''
coverage:
  required: false
''');
}

/// Initializes a git repository in [root] and commits everything.
Future<void> gitInitAndCommit(Directory root, String message) async {
  Future<void> git(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: root.path);
    if (result.exitCode != 0) {
      throw StateError('git ${args.first} failed: ${result.stderr}');
    }
  }

  await git(['init', '.']);
  await git(['add', '.']);
  await git([
    '-c',
    'user.email=test@example.com',
    '-c',
    'user.name=test',
    'commit',
    '-qm',
    message,
  ]);
}
