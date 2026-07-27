@Timeout.factor(2)
library;

import 'dart:io';

import 'package:crap4dart/src/config/config_loader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  group('crap4dart init', () {
    test('creates a config file that the loader accepts', () async {
      final result = await runCliInProcess(tempDir, ['init']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Created crap4dart.yaml'));
      final file = File(p.join(tempDir.path, 'crap4dart.yaml'));
      expect(file.existsSync(), isTrue);
      // Round-trip: the generated file must be valid for the loader.
      final config = const ConfigLoader().load(tempDir.path);
      expect(config.crap.threshold, 8.0);
      expect(config.gates.golden.enabled, isTrue);
    });

    test('refuses to overwrite without --force', () async {
      expect((await runCliInProcess(tempDir, ['init'])).exitCode, 0);
      final second = await runCliInProcess(tempDir, ['init']);
      expect(second.exitCode, 1);
      expect(second.stderr, contains('already exists'));
    });

    test('--force overwrites an existing config', () async {
      expect((await runCliInProcess(tempDir, ['init'])).exitCode, 0);
      final forced = await runCliInProcess(tempDir, ['init', '--force']);
      expect(forced.exitCode, 0);
    });
  });

  group('crap4dart install', () {
    test('sets up the hook and (with --ci) the workflow', () async {
      final init = await Process.run('git', ['init', tempDir.path]);
      expect(init.exitCode, 0);
      final result = await runCliInProcess(tempDir, ['install', '--ci']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Installed git hook'));
      expect(result.stdout, contains('Installed CI workflow'));
      final hook = File(p.join(tempDir.path, '.git/hooks/pre-commit'));
      expect(hook.existsSync(), isTrue);
      expect(hook.readAsStringSync(), contains('check --staged'));
      expect(
        File(p.join(tempDir.path, '.github/workflows/quality.yml'))
            .existsSync(),
        isTrue,
      );
    });

    test('outside a git repository exits 1', () async {
      final result = await runCliInProcess(tempDir, ['install']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('not a git repository'));
    });
  });
}
