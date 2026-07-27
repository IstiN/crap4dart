@Timeout.factor(2)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  String badgePath() => p.join(tempDir.path, 'badges', 'crap.svg');

  group('crap4dart analyze --badge', () {
    test('writes a green SVG badge below the threshold', () async {
      writeMiniProject(tempDir, lcov: fullCoverageLcov);
      final result = await runCliInProcess(
        tempDir,
        ['analyze', '--badge', badgePath()],
      );
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Badge written to ${badgePath()}'));
      expect(result.stderr, contains('![CRAP](${badgePath()})'));
      final svg = File(badgePath()).readAsStringSync();
      expect(svg, contains('<svg '));
      expect(svg, contains('</svg>'));
      expect(svg, contains('fill="#4c1"'));
      expect(svg, contains('>3.00</text>'));
    });

    test('writes a badge even when the threshold is exceeded', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      final result = await runCliInProcess(
        tempDir,
        ['analyze', '--badge', badgePath()],
      );
      expect(result.exitCode, 2);
      // The badge reflects the actual state (8.0 < 12.00 <= 16.0 → yellow).
      final svg = File(badgePath()).readAsStringSync();
      expect(svg, contains('fill="#dfb317"'));
      expect(svg, contains('>12.00</text>'));
    });

    test('writes an N/A badge when coverage is missing', () async {
      writeMiniProject(tempDir, lcov: '');
      File(p.join(tempDir.path, 'coverage', 'lcov.info')).deleteSync();
      final result = await runCliInProcess(
        tempDir,
        ['analyze', '--badge', badgePath()],
      );
      expect(result.exitCode, 0);
      final svg = File(badgePath()).readAsStringSync();
      expect(svg, contains('fill="#9f9f9f"'));
      expect(svg, contains('>N/A</text>'));
    });

    test('works together with --format json', () async {
      writeMiniProject(tempDir, lcov: fullCoverageLcov);
      final result = await runCliInProcess(
        tempDir,
        ['analyze', '--format', 'json', '--badge', badgePath()],
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), startsWith('{'));
      expect(File(badgePath()).existsSync(), isTrue);
    });
  });
}
