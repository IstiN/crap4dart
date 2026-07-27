import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Creates a temp directory and initializes a git repository in it.
Future<Directory> createGitRepo(Directory dir) async {
  final result = await Process.run('git', ['init', dir.path]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return dir;
}

/// Creates a temp directory for hook tests.
Directory createHooksTestProject() =>
    Directory.systemTemp.createTempSync('crap4dart_hooks_test_');

/// Path of the pre-commit hook inside [dir].
String hookPath(Directory dir) =>
    p.join(dir.path, '.git', 'hooks', 'pre-commit');

/// Whether [path] has the executable bit set.
Future<bool> isExecutable(String path) async =>
    (await Process.run('test', ['-x', path])).exitCode == 0;
