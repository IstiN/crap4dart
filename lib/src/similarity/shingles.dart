import 'similarity_profile.dart';

/// The number of consecutive tokens forming one shingle.
const int shingleSize = 8;

/// Word tokens for prose and raw content: letters/digits runs of 2+
/// characters (latin + cyrillic), lowercased.
final RegExp _wordToken = RegExp('[0-9A-Za-zА-Яа-яЁё]{2,}');

/// Code tokens: identifiers, numbers and quoted strings.
final RegExp _codeToken = RegExp(
  "[A-Za-z_][A-Za-z0-9_]*|'[^']*'|\"[^\"]*\"|\\d+(\\.\\d+)?",
);

/// Number tokens (mapped to a placeholder for code).
final RegExp _number = RegExp(r'^\d');

/// Splits [content] into comparison tokens according to [profile].
///
/// Markdown/raw: prose words. Code: identifiers lowercased, numbers and
/// strings replaced with `N`/`S` placeholders so clones differing only
/// in literal values still match.
List<String> tokensFor(String content, SimilarityProfile profile) {
  switch (profile) {
    case SimilarityProfile.markdown:
    case SimilarityProfile.raw:
      return [
        for (final match in _wordToken.allMatches(content))
          match.group(0)!.toLowerCase(),
      ];
    case SimilarityProfile.code:
      return [
        for (final match in _codeToken.allMatches(content))
          _codeTokenValue(match.group(0)!),
      ];
  }
}

/// The comparison value of one raw code token.
String _codeTokenValue(String token) {
  if (token.startsWith("'") || token.startsWith('"')) return 'S';
  if (_number.hasMatch(token)) return 'N';
  return token.toLowerCase();
}

/// 64-bit FNV-1a of one shingle: the [shingleSize] tokens starting at
/// [start], each terminated by a separator unit so `["ab", "c"]` and
/// `["a", "bc"]` hash differently. Hashing keeps only 8 bytes per
/// shingle instead of the full joined token string — the shingle sets
/// of a large tree otherwise retain multi-GB of strings
/// (IstiN/crap4dart#34). 64-bit FNV makes collisions across a tree's
/// shingle count astronomically unlikely.
/// FNV-1a parameters (64-bit flavor, values kept in 63 bits so the
/// hash compiles and behaves identically on every platform).
const int _fnvOffsetBasis = 0x811c9dc5;
const int _fnvPrime = 0x100000001b3;
const int _shingleSeparator = 0x1f;
const int _hashMask = 0x7fffffffffffffff;

/// Hashes the [shingleSize] tokens starting at [start] to a single
/// 64-bit value.
int shingleHash(List<String> tokens, int start) {
  var hash = _fnvOffsetBasis;
  for (var i = start; i < start + shingleSize; i++) {
    final token = tokens[i];
    for (var k = 0; k < token.length; k++) {
      hash = (hash ^ token.codeUnitAt(k)) * _fnvPrime;
    }
    hash = (hash ^ _shingleSeparator) * _fnvPrime;
  }
  // Keep the value non-negative so the hash behaves identically on
  // every platform.
  return hash & _hashMask;
}

/// The set of [shingleSize]-token shingle hashes of [content] under
/// [profile], or an empty set when there are fewer tokens than one
/// shingle (such files carry no similarity signal).
///
/// The content is normalized for [profile] first (markdown loses its
/// fenced code blocks, code loses comments/imports and keeps literal
/// placeholders) — raw bytes would make unrelated files look alike.
Set<int> shinglesFor(String content, SimilarityProfile profile) {
  final tokens = tokensFor(normalize(content, profile), profile);
  if (tokens.length < shingleSize) return const {};
  return {
    for (var i = 0; i + shingleSize <= tokens.length; i++)
      shingleHash(tokens, i),
  };
}

/// The number of shingle hashes present in both sets.
int intersectionCount(Set<int> a, Set<int> b) {
  final small = a.length <= b.length ? a : b;
  final large = identical(small, a) ? b : a;
  var shared = 0;
  for (final shingle in small) {
    if (large.contains(shingle)) shared++;
  }
  return shared;
}

/// The Jaccard similarity of two shingle hash sets: intersection over
/// union. 1.0 for identical sets, 0.0 for disjoint ones.
double jaccard(Set<int> a, Set<int> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final shared = intersectionCount(a, b);
  return shared / (a.length + b.length - shared);
}

/// The containment of the smaller set in the larger one: how much of
/// the smaller file's content the larger one reproduces. Catches the
/// "file A is largely a copy of big file B" case where Jaccard stays
/// low.
double containment(Set<int> a, Set<int> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return intersectionCount(a, b) / (a.length <= b.length ? a.length : b.length);
}
