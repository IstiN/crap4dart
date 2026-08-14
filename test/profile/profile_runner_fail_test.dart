import 'dart:io';

import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:test/test.dart';

import 'profile_runner_run_test.dart' show createProfiledProject, timingJson;

void main() {
  test('run returns null without a pubspec (no package name)', () async {
    final root = Directory.systemTemp.createTempSync('crap4dart_profile_err_');
    addTearDown(() => root.deleteSync(recursive: true));
    const runner = ProfileRunner();
    final result = await runner.run(root.path);
    expect(result, isNull);
  });

  test('run returns null when the fake test run writes no output', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async =>
          ProcessResult(0, 1, '', 'tests failed'),
    );
    final result = await runner.run(root.path);
    expect(result, isNull);
  });

  test('run instruments lib and reports missing-method tolerances', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    // Timing keys that do not map to real methods must not crash parsing.
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        final output = environment!['CRAP_PROFILE_OUTPUT']!;
        File(output).writeAsStringSync(timingJson);
        return ProcessResult(0, 0, 'ok', '');
      },
    );
    final result = await runner.run(root.path);
    expect(result!.timings, isNotEmpty);
    // _ensureGitignore must have added profiling entries to .gitignore.
    final gitignore = File('${root.path}/.gitignore').readAsStringSync();
    expect(gitignore, contains('profile-reports/'));
    expect(gitignore, contains('.crap_profile_temp/'));
  });

  test('rewrites package_config.json to point at the temp lib/', () async {
    final root = createProfiledProject();
    addTearDown(() => root.deleteSync(recursive: true));
    // A fake .dart_tool with a package_config.json pointing elsewhere.
    final dartTool = Directory('${root.path}/.dart_tool')..createSync();
    final originalRoot = root.path;
    File('${dartTool.path}/package_config.json').writeAsStringSync('''
{
  "packages": [
    {"name": "testpkg", "rootUri": "../", "packageUri": "lib/"},
    {"name": "other", "rootUri": "../../other", "packageUri": "lib/"}
  ]
}
''');
    var tempRoot = '';
    var rewritten = '';
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        tempRoot = workingDirectory!;
        final output = environment!['CRAP_PROFILE_OUTPUT']!;
        File(output).writeAsStringSync(timingJson);
        // Read before run() deletes the temp dir.
        rewritten =
            File('$tempRoot/.dart_tool/package_config.json').readAsStringSync();
        return ProcessResult(0, 0, 'ok', '');
      },
    );
    await runner.run(root.path);
    final rootUri =
        RegExp('"rootUri":"([^"]*)"').firstMatch(rewritten)!.group(1)!;
    expect(Uri.parse(rootUri).toFilePath(), '$tempRoot/');
    expect(rewritten, contains('"name":"testpkg"'));
    expect(rewritten, contains('"name":"other"'));
    // The original package_config stays untouched.
    final original = File('$originalRoot/.dart_tool/package_config.json');
    expect(original.readAsStringSync(), isNot(contains(tempRoot)));
  });
}
