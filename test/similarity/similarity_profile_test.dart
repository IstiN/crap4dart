import 'package:crap4dart/src/similarity/similarity_profile.dart';
import 'package:test/test.dart';

void main() {
  group('profileFor', () {
    test('maps extensions to profiles', () {
      expect(SimilarityProfiles.profileFor('docs/a.md'),
          SimilarityProfile.markdown);
      expect(
          SimilarityProfiles.profileFor('lib/a.dart'), SimilarityProfile.code);
      expect(
          SimilarityProfiles.profileFor('src/a.java'), SimilarityProfile.code);
      expect(SimilarityProfiles.profileFor('data.csv'), SimilarityProfile.raw);
    });
  });
  group('markdown normalization', () {
    test('drops fenced code blocks and punctuation-only lines', () {
      final normalized = normalizeMarkdown(
        '# Title\n'
        '\n'
        'Prose line one.\n'
        '```dart\n'
        'final hidden = 1; // inside a fence\n'
        '```\n'
        'Prose line two.\n',
      );
      expect(normalized, contains('Prose'));
      expect(normalized, isNot(contains('hidden')));
    });
  });
  group('code normalization', () {
    test('strips line/block comments and import-family lines', () {
      final normalized = normalizeCode(
        'import "package:x/x.dart";\n'
        'library foo;\n'
        '// a line comment\n'
        'void main() {\n'
        '  /* block */ final a = 1;\n'
        '}\n',
      );
      expect(normalized, isNot(contains('import')));
      expect(normalized, isNot(contains('line comment')));
      expect(normalized, contains('final a = 1;'));
    });

    test('multi-line block comments survive rejoining after */', () {
      final normalized = normalizeCode(
        '/* one\n'
        'two */ final kept = true;\n',
      );
      expect(normalized, contains('final kept = true;'));
      expect(normalized, isNot(contains('one')));
    });
  });
}
