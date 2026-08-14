import 'dart:io';

import 'package:crap4dart/src/cli/runner.dart';
import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:path/path.dart' as p;

/// Path to the crap4dart executable under test.
final String binScript = p.normalize(
  p.join(Directory.current.path, 'bin', 'crap4dart.dart'),
);

/// Creates a temporary project directory for CLI tests.
Directory createCliTestProject() =>
    Directory.systemTemp.createTempSync('crap4dart_cli_test_');

/// Runs the crap4dart CLI in [workDir] with [args] as a subprocess.
///
/// Used only for smoke tests of the real binary; prefer
/// [runCliInProcess] so coverage is attributed to the test run.
Future<ProcessResult> runCli(Directory workDir, List<String> args) =>
    Process.run(
      'dart',
      ['run', binScript, ...args],
      workingDirectory: workDir.path,
    );

/// Outcome of an in-process CLI invocation.
class CliResult {
  /// Creates a [CliResult].
  const CliResult(this.exitCode, this.stdout, this.stderr);

  /// The exit code returned by the runner.
  final int exitCode;

  /// Everything written to stdout.
  final String stdout;

  /// Everything written to stderr.
  final String stderr;
}

/// Runs the crap4dart CLI with [args] in the current process, with
/// [workDir] as the project root and stdout/stderr captured.
Future<CliResult> runCliInProcess(Directory workDir, List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await IOOverrides.runZoned(
    () => Crap4DartRunner(projectRoot: workDir.path).run(args),
    stdout: () => _BufferStdout(out),
    stderr: () => _BufferStdout(err),
  );
  return CliResult(code, out.toString(), err.toString());
}

/// A [Stdout] that appends everything to a [StringBuffer]. Members the
/// runner never calls are silent no-ops.
class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Builds a project whose fake instrumented run reports `Foo.bar` timing.
Directory createCliProfileProject() {
  final root = createCliTestProject();
  File('${root.path}/pubspec.yaml').writeAsStringSync('name: myapp\n');
  Directory('${root.path}/lib').createSync();
  File('${root.path}/lib/a.dart').writeAsStringSync('''
class Foo {
  void bar() {
    print('x');
  }
}
''');
  return root;
}

/// Timing JSON of a single slow `Foo.bar` call (20 ms).
const String slowTiming = '''
{"Foo.bar": {"calls": 1, "totalMicros": 20000, "minMicros": 20000, "maxMicros": 20000}}
''';

/// A fake `dart test` that writes [slowTiming] to the output file.
Future<ProcessResult> fakeSlowRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final output = environment!['CRAP_PROFILE_OUTPUT']!;
  File(output).writeAsStringSync(slowTiming);
  return ProcessResult(0, 0, 'ok', '');
}

/// Like [fakeSlowRunner], but records the `dart test` arguments.
ProcessRunner capturingSlowRunner(List<List<String>> captured) =>
    (exe, args, {workingDirectory, environment}) async {
      captured.add(args);
      final output = environment!['CRAP_PROFILE_OUTPUT']!;
      File(output).writeAsStringSync(slowTiming);
      return ProcessResult(0, 0, 'ok', '');
    };

/// Like [runCliInProcess] but injects a fake [ProfileRunner].
Future<CliResult> runCliInProcessWithProfile(
  Directory workDir,
  List<String> args,
  ProcessRunner processRunner,
) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await IOOverrides.runZoned(
    () => Crap4DartRunner(
      projectRoot: workDir.path,
      profileRunner: ProfileRunner(runner: processRunner),
    ).run(args),
    stdout: () => _BufferStdout(out),
    stderr: () => _BufferStdout(err),
  );
  return CliResult(code, out.toString(), err.toString());
}

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
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
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
    '-q',
    '--allow-empty',
    '-m',
    message,
  ]);
}
