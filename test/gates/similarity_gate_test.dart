import 'package:crap4dart/src/gates/similarity/similarity_gate.dart';
import 'package:test/test.dart';

import '../similarity/similarity_fixtures.dart';
import 'gate_test_utils.dart';

const String enabledYaml =
    'gates:\n  similarity:\n    enabled: true\n    min_shingles: 10\n';

void main() {
  group('similarity gate', () {
    test('clean corpus passes with a scanned-files summary', () async {
      final root = createTempProject();
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'docs/a.md', proseA);
      writeFile(root, 'docs/c.md', proseC);
      final result = await const SimilarityGate().run(
        makeContext(root, [], configYaml: enabledYaml),
      );
      expect(result.passed, isTrue);
      expect(result.summary, contains('2 files scanned'));
      expect(result.summary, contains('no similar files'));
    });
    test('near-duplicate files produce one violation per file', () async {
      final root = createTempProject();
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'docs/a.md', proseA);
      writeFile(root, 'docs/b.md', proseA);
      final result = await const SimilarityGate().run(
        makeContext(root, [], configYaml: enabledYaml),
      );
      expect(result.passed, isFalse);
      expect(result.violations, hasLength(2));
      expect(
        result.violations.map((v) => v.file),
        containsAll(['docs/a.md', 'docs/b.md']),
      );
      final message = result.violations.first.message;
      expect(message, contains('similar to'));
      expect(message, contains('jaccard 1.00'));
      expect(result.summary, contains('1 similar-file clusters'));
    });
    test('exclude globs are honored', () async {
      final root = createTempProject();
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'docs/a.md', proseA);
      writeFile(root, 'generated/b.md', proseA);
      final result = await const SimilarityGate().run(
        makeContext(
          root,
          [],
          configYaml: 'gates:\n'
              '  similarity:\n'
              '    enabled: true\n'
              '    min_shingles: 10\n'
              '    exclude: ["generated/**"]\n',
        ),
      );
      expect(result.passed, isTrue);
      expect(result.summary, contains('1 files scanned'));
    });
    test('dirs limit the scan roots', () async {
      final root = createTempProject();
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'docs/a.md', proseA);
      writeFile(root, 'other/b.md', proseA);
      final result = await const SimilarityGate().run(
        makeContext(
          root,
          [],
          configYaml: 'gates:\n'
              '  similarity:\n'
              '    enabled: true\n'
              '    min_shingles: 10\n'
              '    dirs: [other]\n',
        ),
      );
      expect(result.passed, isTrue);
      expect(result.summary, contains('1 files scanned'));
    });
  });
}
