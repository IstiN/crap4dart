import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'cli/cli_test_utils.dart';
import 'similarity/similarity_fixtures.dart';

void _writeMd(Directory workDir, String relative, String content) {
  File('${workDir.path}/$relative').createSync(recursive: true);
  File('${workDir.path}/$relative').writeAsStringSync(content);
}

void main() {
  group('similarity command json', () {
    test('json output is valid JSON with the report shape', () async {
      final workDir = createCliTestProject();
      addTearDown(() => workDir.deleteSync(recursive: true));
      _writeMd(workDir, 'a.md', proseA);
      _writeMd(workDir, 'b.md', proseA);
      final result = await runCliInProcess(workDir, [
        'similarity',
        '--format',
        'json',
        '--jaccard',
        '0.5',
        '--min-shingles',
        '10',
      ]);
      expect(result.exitCode, 0);
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(decoded['scanned'], 2);
      expect(decoded['pairs'], hasLength(1));
      expect(decoded['pairs'].first['jaccard'], 1.0);
      expect(decoded['clusters'].first['files'], hasLength(2));
      expect(
        (decoded['thresholds'] as Map<String, dynamic>)['jaccard'],
        0.5,
      );
    });
  });
}
