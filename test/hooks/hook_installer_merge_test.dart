import 'dart:io';

import 'package:crap4dart/src/hooks/hook_installer.dart';
import 'package:test/test.dart';

import 'hook_test_utils.dart';

void main() {
  const installer = HookInstaller();

  late Directory tempDir;

  setUp(() => tempDir = createHooksTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  group('HookInstaller foreign hooks', () {
    test('foreign hook without force throws', () async {
      await createGitRepo(tempDir);
      File(hookPath(tempDir)).writeAsStringSync('#!/bin/sh\necho foreign\n');
      expect(
        () => installer.installHook(tempDir.path),
        throwsA(
          isA<HookInstallException>().having(
            (e) => e.message,
            'message',
            contains('use --force'),
          ),
        ),
      );
    });

    test('foreign hook with force keeps the foreign content', () async {
      await createGitRepo(tempDir);
      File(hookPath(tempDir)).writeAsStringSync('#!/bin/sh\necho foreign\n');
      await installer.installHook(tempDir.path, force: true);
      final content = File(hookPath(tempDir)).readAsStringSync();
      expect(content, contains('echo foreign'));
      expect(content, contains(HookInstaller.beginMarker));
      expect(
        content.indexOf('echo foreign'),
        lessThan(content.indexOf(HookInstaller.beginMarker)),
      );
    });
  });
}
