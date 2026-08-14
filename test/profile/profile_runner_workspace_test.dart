import 'dart:io';

import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:test/test.dart';

/// Timing JSON of one slow method call.
const timingJson = '''
{"Foo.bar": {"calls": 1, "totalMicros": 20000, "minMicros": 20000, "maxMicros": 20000}}
''';

/// Creates a workspace-member project: pubspec with
/// `resolution: workspace`, a lib and a test dir.
Directory createWorkspaceMemberProject() {
  final root = Directory.systemTemp.createTempSync('crap4dart_ws_test_');
  File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: wsmember
resolution: workspace
''');
  Directory('${root.path}/lib').createSync();
  File('${root.path}/lib/a.dart').writeAsStringSync('''
class Foo {
  void bar() {
    print('x');
  }
}
''');
  Directory('${root.path}/test').createSync();
  File('${root.path}/test/a_test.dart').writeAsStringSync('void main() {}\n');
  return root;
}

void main() {
  test('run profiles a workspace member via fake pub get', () async {
    final root = createWorkspaceMemberProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final commands = <String>[];
    var tempRoot = '';
    var pubspec = '';
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        commands.add(args.first);
        if (args.first == 'pub') {
          tempRoot = workingDirectory!;
          pubspec = File('$tempRoot/pubspec.yaml').readAsStringSync();
          return ProcessResult(0, 0, '', '');
        }
        final output = environment!['CRAP_PROFILE_OUTPUT']!;
        File(output).writeAsStringSync(timingJson);
        return ProcessResult(0, 0, 'ok', '');
      },
    );
    final result = await runner.run(root.path);
    expect(result, isNotNull);
    expect(result!.timings.single.className, 'Foo');
    // pub get runs before the test command.
    expect(commands.first, 'pub');
    expect(commands.last, 'test');
    // The temp pubspec is standalone: workspace marker stripped.
    expect(pubspec, isNot(contains('resolution: workspace')));
    expect(pubspec, contains('name: wsmember'));
  });

  test('run returns null when pub get fails in a workspace member', () async {
    final root = createWorkspaceMemberProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async =>
          args.first == 'pub'
              ? ProcessResult(0, 1, '', 'no network')
              : ProcessResult(0, 0, 'ok', ''),
    );
    final result = await runner.run(root.path);
    expect(result, isNull);
  });

  test('run swallows unexpected failures and returns null', () async {
    final root = createWorkspaceMemberProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final runner = ProfileRunner(
      runner: (exe, args, {workingDirectory, environment}) async {
        throw const FileSystemException('disk gone');
      },
    );
    final result = await runner.run(root.path);
    expect(result, isNull);
  });
}
