import 'dart:io';

import 'package:crap4dart/src/hooks/hook_installer.dart';
import 'package:test/test.dart';

import 'hook_test_utils.dart';

void main() {
  const installer = HookInstaller();

  late Directory tempDir;

  setUp(() => tempDir = createHooksTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  group('HookInstaller', () {
    test('installs an executable hook with the managed block', () async {
      await createGitRepo(tempDir);
      final path = await installer.installHook(tempDir.path);
      expect(path, hookPath(tempDir));
      expect(File(path).existsSync(), isTrue);
      expect(await isExecutable(path), isTrue);
      final content = File(path).readAsStringSync();
      expect(content, startsWith('#!/bin/sh'));
      expect(content, contains(HookInstaller.beginMarker));
      expect(content, contains('command -v crap4dart'));
      expect(content, contains('check --staged'));
      expect(content, contains('dart run bin/crap4dart.dart'));
      expect(content, isNot(contains('test --coverage')));
    });

    test('runTests adds the coverage test command', () async {
      await createGitRepo(tempDir);
      await installer.installHook(tempDir.path, runTests: true);
      final content = File(hookPath(tempDir)).readAsStringSync();
      expect(content, contains('dart test --coverage || exit 1'));
    });

    test('re-installation replaces the managed block', () async {
      await createGitRepo(tempDir);
      await installer.installHook(tempDir.path);
      await installer.installHook(tempDir.path, runTests: true);
      final content = File(hookPath(tempDir)).readAsStringSync();
      expect(content, contains('dart test --coverage || exit 1'));
      expect(
        HookInstaller.beginMarker.allMatches(content),
        hasLength(1),
      );
    });

    test('throws outside a git repository', () {
      expect(
        () => installer.installHook(tempDir.path),
        throwsA(
          isA<HookInstallException>().having(
            (e) => e.message,
            'message',
            'not a git repository',
          ),
        ),
      );
    });
  });
}
