/// Content profiles for similarity analysis: how a file's raw bytes
/// become comparable text.
///
/// Similarity is a text-level property — no parser is involved — but
/// raw bytes of different languages carry different noise. Profiles
/// strip the noise that makes two *unrelated* files look alike
/// (imports, comments, markdown fences) so the remaining signal is
/// actual content.
enum SimilarityProfile {
  /// Prose documents (markdown): fenced code blocks are dropped, only
  /// the prose words are compared.
  markdown,

  /// Source code: comments and import-family directives are stripped,
  /// literals are replaced with placeholders, identifiers lowercased.
  code,

  /// Anything else: lines compared as-is (trimmed).
  raw,
}

/// Extension → [SimilarityProfile] mapping and the per-profile
/// normalizers.
abstract final class SimilarityProfiles {
  /// Markdown extensions.
  static const Set<String> _markdownExtensions = {
    '.md',
    '.markdown',
    '.mdx',
  };

  /// Source code extensions (any language — the normalizer is
  /// language-agnostic token shaping).
  static const Set<String> _codeExtensions = {
    '.dart',
    '.js',
    '.mjs',
    '.cjs',
    '.ts',
    '.tsx',
    '.jsx',
    '.java',
    '.py',
    '.kt',
    '.kts',
    '.swift',
    '.go',
    '.rs',
    '.c',
    '.h',
    '.cpp',
    '.hpp',
    '.cs',
    '.rb',
    '.php',
    '.scala',
    '.gradle',
    '.groovy',
    '.sh',
    '.sql',
  };

  /// The profile for a file path (by extension), [SimilarityProfile.raw]
  /// for unknown extensions.
  static SimilarityProfile profileFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot).toLowerCase();
    if (_markdownExtensions.contains(ext)) {
      return SimilarityProfile.markdown;
    }
    if (_codeExtensions.contains(ext)) return SimilarityProfile.code;
    return SimilarityProfile.raw;
  }
}

/// Line-comment markers across the [SimilarityProfile.code] extension
/// family.
final RegExp _lineComment = RegExp(r'^\s*(//|#|--|;)');

/// Import-family directives across languages — boilerplate that would
/// otherwise make every file of a project look like every other.
final List<RegExp> _importLines = [
  // dart, js/ts, python, java, kotlin, c#, php, gradle…
  RegExp(r'^\s*(import|export|part|part of|library)\b'),
  RegExp(r'^\s*(from|require|require_once|using|package|include)\b'),
  RegExp(r'^#!'),
];

/// Markdown prose: drops fenced code blocks, keeps heading/list words.
String normalizeMarkdown(String content) {
  final lines = content.split('\n');
  final prose = StringBuffer();
  var inFence = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence || trimmed.isEmpty) continue;
    prose
      ..write(trimmed)
      ..write(' ');
  }
  return prose.toString();
}

/// Source code: strips block/line comments and import-family lines,
/// replaces literals with placeholders, lowercases identifiers.
String normalizeCode(String content) {
  final kept = <String>[];
  var inBlockComment = false;
  for (final raw in content.split('\n')) {
    final opened = inBlockComment;
    final (stripped, stillOpen) =
        _stripBlockComments(raw, inBlockComment: opened);
    inBlockComment = stillOpen;
    if (_isCodeNoise(stripped)) continue;
    kept.add(stripped.trim());
  }
  return kept.join('\n');
}

/// The [line] with its block comments removed; `stillInBlock` carries
/// an unterminated `/*` across lines.
(String, bool) _stripBlockComments(
  String line, {
  required bool inBlockComment,
}) {
  if (inBlockComment) {
    final close = line.indexOf('*/');
    if (close < 0) return ('', true);
    return _stripBlockComments(line.substring(close + 2),
        inBlockComment: false);
  }
  final open = line.indexOf('/*');
  if (open < 0) return (line, false);
  final close = line.indexOf('*/', open + 2);
  if (close < 0) return (line.substring(0, open), true);
  final (rest, stillOpen) = _stripBlockComments(
      line.replaceRange(open, close + 2, ''),
      inBlockComment: false);
  return (rest, stillOpen);
}

/// Whether a stripped code line carries no comparison signal (empty,
/// a line comment, or an import-family directive).
bool _isCodeNoise(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || _lineComment.hasMatch(trimmed)) return true;
  return _importLines.any((pattern) => pattern.hasMatch(trimmed));
}

/// The normalizer for [profile]; markdown and code are shaped, raw
/// content passes through.
String normalize(String content, SimilarityProfile profile) {
  switch (profile) {
    case SimilarityProfile.markdown:
      return normalizeMarkdown(content);
    case SimilarityProfile.code:
      return normalizeCode(content);
    case SimilarityProfile.raw:
      return content;
  }
}
