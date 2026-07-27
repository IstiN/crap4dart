import 'dart:io';

import 'package:crap4dart/src/hooks/ci_installer.dart';
import 'package:crap4dart/src/hooks/hook_installer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'hook_test_utils.dart';

void main() {
  const ci = CiInstaller();

  late Directory tempDir;

  setUp(() => tempDir = createHooksTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  String workflowPath() =>
      p.join(tempDir.path, '.github', 'workflows', 'quality.yml');

  group('CiInstaller', () {
    test('creates a Dart workflow for pure Dart projects', () {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: fixture\n');
      final path = ci.installCi(tempDir.path);
      expect(path, workflowPath());
      final content = File(path).readAsStringSync();
      expect(content, contains('dart-lang/setup-dart'));
      expect(content, contains('dart pub get'));
      expect(content, contains('dart test --coverage=coverage'));
      expect(content, contains('format_coverage'));
      expect(content, contains('crap4dart check --all'));
      expect(content, contains('crap4dart analyze'));
      expect(content, isNot(contains('flutter-action')));
    });

    test('creates a Flutter workflow for Flutter projects', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: fixture\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
      ci.installCi(tempDir.path);
      final content = File(workflowPath()).readAsStringSync();
      expect(content, contains('subosito/flutter-action'));
      expect(content, contains('flutter pub get'));
      expect(content, contains('flutter test --coverage'));
      expect(content, isNot(contains('format_coverage')));
    });

    test('does not overwrite an existing workflow without force', () {
      Directory(p.dirname(workflowPath())).createSync(recursive: true);
      File(workflowPath()).writeAsStringSync('custom: true\n');
      expect(
        () => ci.installCi(tempDir.path),
        throwsA(isA<HookInstallException>()),
      );
      expect(File(workflowPath()).readAsStringSync(), 'custom: true\n');
      ci.installCi(tempDir.path, force: true);
      expect(
        File(workflowPath()).readAsStringSync(),
        contains('name: Quality'),
      );
    });
  });
}
