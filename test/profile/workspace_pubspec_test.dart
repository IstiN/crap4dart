import 'dart:io';

import 'package:crap4dart/src/profile/workspace_pubspec.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('workspace_pubspec_test_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  Directory memberOf(String workspacePubspec) {
    final workspaceRoot = Directory('${root.path}/ws')..createSync();
    File('${workspaceRoot.path}/pubspec.yaml')
        .writeAsStringSync(workspacePubspec);
    final member = Directory('${workspaceRoot.path}/pkgs/member')
      ..createSync(recursive: true);
    File('${member.path}/pubspec.yaml').writeAsStringSync('''
name: member
resolution: workspace
''');
    return member;
  }

  test('extracts overrides body up to the next top-level key', () {
    final member = memberOf('''
workspace:
  - pkgs/member

dependency_overrides:
  args: ^2.0.0
  path: ../shared

dev_dependencies:
  lints: ^5.0.0
''');
    final overrides = WorkspacePubspec(member.path).dependencyOverrides();
    expect(overrides, isNotNull);
    expect(overrides, contains('args: ^2.0.0'));
    expect(overrides, isNot(contains('lints')));
  });

  test('returns null when the workspace has no overrides', () {
    final member = memberOf('workspace:\n  - pkgs/member\n');
    expect(
      WorkspacePubspec(member.path).dependencyOverrides(),
      isNull,
    );
  });

  test('returns null without a workspace ancestor', () {
    final member = Directory('${root.path}/plain')..createSync(recursive: true);
    File('${member.path}/pubspec.yaml').writeAsStringSync('name: standalone\n');
    expect(
      WorkspacePubspec(member.path).dependencyOverrides(),
      isNull,
    );
  });

  test('writeStandalone strips the marker and absolutizes path deps', () async {
    final member = memberOf('workspace:\n  - pkgs/member\n');
    File('${member.path}/pubspec.yaml').writeAsStringSync('''
name: member
resolution: workspace
dependencies:
  shared:
    path: ../../shared
''');
    final temp = Directory('${root.path}/temp')..createSync();
    WorkspacePubspec(member.path).writeStandalone(temp);
    final rewritten = File('${temp.path}/pubspec.yaml').readAsStringSync();
    expect(rewritten, isNot(contains('resolution: workspace')));
    expect(rewritten, contains(root.path));
    expect(rewritten, isNot(contains('../')));
  });
}
