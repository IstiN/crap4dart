import 'package:crap4dart/src/similarity/shingles.dart';
import 'package:crap4dart/src/similarity/similarity_profile.dart';
import 'package:test/test.dart';

void main() {
  group('tokensFor', () {
    test('code literals become placeholders', () {
      final tokens = tokensFor(
        'final width = 640;\nfinal name = "abc";\n',
        SimilarityProfile.code,
      );
      expect(tokens, containsAll(['final', 'width', 'N', 'name', 'S']));
      expect(tokens, isNot(contains('640')));
    });

    test('prose words are lowercased words of 2+ chars', () {
      final tokens = tokensFor(
        'The Quick brown fox A x1',
        SimilarityProfile.markdown,
      );
      expect(tokens, ['the', 'quick', 'brown', 'fox', 'x1']);
    });
  });
  group('shinglesFor', () {
    test('files shorter than one shingle yield an empty set', () {
      expect(
        shinglesFor('too short', SimilarityProfile.raw),
        isEmpty,
      );
    });

    test('identical content yields identical shingles', () {
      final a = shinglesFor('one two three four five six seven eight nine',
          SimilarityProfile.raw);
      final b = shinglesFor('one two three four five six seven eight nine',
          SimilarityProfile.raw);
      expect(a, equals(b));
      expect(a, hasLength(2)); // 9 tokens → 2 shingles of 8
    });
  });
  group('similarity math', () {
    final a = {'x', 'y', 'z'};
    final b = {'x', 'y', 'q'};
    final big = {'x', 'y', 'z', 'q', 'r', 's'};

    test('jaccard is intersection over union', () {
      expect(jaccard(a, b), closeTo(2 / 4, 1e-9));
      expect(jaccard(a, a), 1.0);
      expect(jaccard(a, {}), 0.0);
    });

    test('containment is intersection over the smaller set', () {
      expect(containment(big, a), 1.0);
      expect(containment(a, b), closeTo(2 / 3, 1e-9));
      expect(containment(a, {}), 0.0);
    });
  });
}
