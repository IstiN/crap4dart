import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('similarity config', () {
    test('parses every key strictly', () {
      final config = loader.loadString(
        'gates:\n  similarity:\n'
        '    enabled: true\n'
        '    severity: warning\n'
        '    ignorable: true\n'
        '    dirs: [doc, docs]\n'
        '    include: ["**/*.md", "**/*.dart"]\n'
        '    min_shingles: 30\n'
        '    jaccard: 0.6\n'
        '    containment: 0.9\n'
        '    exclude: ["generated/**"]\n',
      );
      final similarity = config.gates.similarity;
      expect(similarity.enabled, isTrue);
      expect(similarity.severity, GateSeverity.warning);
      expect(similarity.ignorable, isTrue);
      expect(similarity.dirs, ['doc', 'docs']);
      expect(similarity.include, ['**/*.md', '**/*.dart']);
      expect(similarity.minShingles, 30);
      expect(similarity.jaccard, 0.6);
      expect(similarity.containment, 0.9);
      expect(similarity.exclude, ['generated/**']);
    });

    test('defaults: disabled, conservative thresholds', () {
      final similarity = loader.loadString('').gates.similarity;
      expect(similarity.enabled, isFalse);
      expect(similarity.severity, GateSeverity.error);
      expect(similarity.jaccard, 0.8);
      expect(similarity.containment, 0.95);
      expect(similarity.minShingles, 50);
      expect(similarity.dirs, ['.']);
      expect(similarity.include, ['**/*.md']);
    });

    test('unknown keys fail with the full path', () {
      expect(
        () => loader.loadString(
          'gates:\n  similarity:\n    treshold: 0.5\n',
        ),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.similarity.treshold',
          ),
        ),
      );
    });

    test('jaccard must be a number', () {
      expect(
        () => loader.loadString(
          'gates:\n  similarity:\n    jaccard: high\n',
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
