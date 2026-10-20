import 'dart:io';

import 'package:test/test.dart';

import 'similarity/similarity_fixtures.dart';

import 'cli/cli_test_utils.dart';

void main() {
  group('similarity command', () {
    test('console report prints clusters and stays informational', () async {
      final workDir = createCliTestProject();
      addTearDown(() => workDir.deleteSync(recursive: true));
      _writeMd(workDir, 'a.md', proseA);
      _writeMd(workDir, 'b.md', proseA);
      _writeMd(workDir, 'c.md', proseC);
      final result = await runCliInProcess(workDir, [
        'similarity',
        '--jaccard',
        '0.5',
        '--min-shingles',
        '10',
        '--containment',
        '0.85',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('cluster 1 — 2 files'));
      expect(result.stdout, contains('a.md'));
      expect(result.stdout, contains('b.md'));
      expect(result.stdout, contains('jaccard 1.00'));
      expect(result.stdout, contains('2 files in 1 clusters'));
    });

    test('clean corpus prints no similar files', () async {
      final workDir = createCliTestProject();
      addTearDown(() => workDir.deleteSync(recursive: true));
      _writeMd(workDir, 'a.md', proseA);
      _writeMd(workDir, 'c.md', proseC);
      final result = await runCliInProcess(workDir, [
        'similarity',
        '--jaccard',
        '0.5',
        '--min-shingles',
        '10',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('no similar files'));
    });

    test('explicit directory argument becomes the scan root', () async {
      final workDir = createCliTestProject();
      addTearDown(() => workDir.deleteSync(recursive: true));
      _writeMd(workDir, 'docs/a.md', proseA);
      _writeMd(workDir, 'docs/b.md', proseA);
      final result = await runCliInProcess(workDir, [
        'similarity',
        'docs',
        '--jaccard',
        '0.5',
        '--min-shingles',
        '10',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('2 files scanned'));
      expect(result.stdout, contains('a.md'));
    });
  });
}

void _writeMd(Directory workDir, String relative, String content) {
  final file = File('${workDir.path}/$relative')..createSync(recursive: true);
  file.writeAsStringSync(content);
}
