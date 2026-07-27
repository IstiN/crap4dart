import 'dart:io';

import 'package:crap4dart/src/files/changed_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli/cli_test_utils.dart';

void main() {
  const finder = ChangedFilesFinder();

  late Directory repo;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('crap4dart_changed_test_');
  });

  tearDown(() {
    repo.deleteSync(recursive: true);
  });

  Future<ProcessResult> git(List<String> args) =>
      Process.run('git', args, workingDirectory: repo.path);

  void write(String relative, [String content = 'void f() {}\n']) {
    final file = File(p.join(repo.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  test('finds modified, added and untracked Dart files, sorted', () async {
    write('lib/tracked.dart');
    write('README.md', 'text\n'); // not Dart
    await gitInitAndCommit(repo, 'base');
    write('lib/tracked.dart', 'void changed() {}\n'); // modified
    write('lib/b.dart'); // untracked
    final files = await finder.find(repo.path);
    expect(files, ['lib/b.dart', 'lib/tracked.dart']);
  });

  test('staged mode returns only staged Dart files', () async {
    await gitInitAndCommit(repo, 'base');
    write('lib/staged.dart');
    write('lib/unstaged.dart');
    await git(['add', 'lib/staged.dart']);
    final files = await finder.find(repo.path, staged: true);
    expect(files, ['lib/staged.dart']);
  });

  test('renames keep the new path', () async {
    write('lib/old.dart');
    await gitInitAndCommit(repo, 'base');
    await git(['mv', 'lib/old.dart', 'lib/renamed.dart']);
    // Unstaged porcelain reports "R old -> new"; keep the new path.
    final files = await finder.find(repo.path);
    expect(files, ['lib/renamed.dart']);
  });

  test('quoted paths with spaces are unquoted', () async {
    write('lib/tracked.dart');
    await gitInitAndCommit(repo, 'base');
    write('lib/my file.dart');
    final files = await finder.find(repo.path);
    expect(files, ['lib/my file.dart']);
  });

  test('throws outside a git repository', () {
    expect(
      () => finder.find(repo.path),
      throwsA(isA<ProcessException>()),
    );
  });
}
