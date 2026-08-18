import 'dart:io';

import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:test/test.dart';

/// Timing JSON written by the fake test run into the output file.
const timingJson = '''
{
  "Foo.bar": {"calls": 2, "totalMicros": 500, "minMicros": 100, "maxMicros": 400},
  "topLevel": {"calls": 1, "totalMicros": 50, "minMicros": 50, "maxMicros": 50}
}
''';

/// Builds a minimal profiled project: pubspec, lib and test dirs.
Directory createProfiledProject() {
  final root = Directory.systemTemp.createTempSync('crap4dart_profile_run_');
  File('${root.path}/pubspec.yaml').writeAsStringSync('name: testpkg\n');
  Directory('${root.path}/lib').createSync();
  File('${root.path}/lib/a.dart').writeAsStringSync('''
class Foo {
  void bar() {
    print('x');
  }
}
''');
  Directory('${root.path}/test').createSync();
  File('${root.path}/test/a_test.dart').writeAsStringSync("void main() {}\n");
  return root;
}

/// Fake `dart test` that writes timing JSON to $CRAP_PROFILE_OUTPUT.
Future<ProcessResult> fakeTestRun(
  Map<String, String>? environment, [
  String timing = timingJson,
]) async {
  final output = environment!['CRAP_PROFILE_OUTPUT']!;
  File(output).writeAsStringSync(timing);
  return ProcessResult(0, 0, 'ok', '');
}

/// Runner double that records the spawned test args and writes timing JSON.
ProfileRunner capturingRunner(List<List<String>> captured) => ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        captured.add(args);
        final output = environment!['CRAP_PROFILE_OUTPUT']!;
        File(output).writeAsStringSync(timingJson);
        return ProcessResult(0, 0, 'ok', '');
      },
    );

void main() {
  test('run returns parsed timings sorted by total time', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        expect(exe, 'dart');
        expect(workingDirectory, contains('.crap_profile_temp'));
        return fakeTestRun(environment);
      },
    );
    final result = await runner.run(root.path);
    expect(result, isNotNull);
    expect(result!.timings, hasLength(2));
    expect(result.timings.first.className, 'Foo');
    expect(result.timings.first.totalMicros, 500);
    expect(result.timings.last.className, '(top-level)');
    expect(Directory('${root.path}/.crap_profile_temp').existsSync(), isFalse,
        reason: 'temp dir must be cleaned up');
  });

  test('run forwards filter flags to dart test', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final captured = <List<String>>[];
    await capturingRunner(captured).run(
      root.path,
      filter: const TestFilter(
        name: 'golden',
        tags: ['integration'],
        excludeTags: ['slow'],
        paths: ['test/a_test.dart'],
      ),
    );
    final args = captured.single;
    // `test` stays as the subcommand; with explicit paths it must NOT also
    // act as a whole-suite directory selector (flutter treats a bare `test`
    // positional as one). Only the requested file is passed as selector.
    expect(args.first, 'test');
    expect(args.skip(1), isNot(contains('test')),
        reason: 'explicit paths must be the only selectors');
    expect(args, containsAllInOrder(['--compiler', 'source']));
    expect(
        args,
        containsAll([
          '--name',
          'golden',
          '--tags',
          'integration',
          '-x',
          'slow',
          'test/a_test.dart'
        ]));
  });

  test('run keeps default test dir when no explicit paths given', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final captured = <List<String>>[];
    await capturingRunner(captured).run(root.path);
    final args = captured.single;
    expect(args.first, 'test');
    expect(args, contains('--compiler'));
  });
}
