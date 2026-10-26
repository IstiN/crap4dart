part of 'duplication_gate.dart';

/// Inclusive-start, exclusive-end token range inside one file.
typedef _TokenRange = ({int start, int end});

/// The duplication engine: window indexing, fingerprint verification,
/// maximal-extent clone groups, and the greedy longest-first
/// non-overlapping selection (PMD CPD Match semantics).
class _CloneDetector {
  static const int _base = 0x9e3779b97f4a7c15;
  static final int _mask = (1 << 64) - 1;

  /// Detects duplicated windows, marks the involved tokens and returns
  /// the accepted clone groups (longest-first, non-overlapping — the
  /// PMD CPD Match semantics).
  ///
  /// Two passes: the raw pass compares lexemes (Type-1 copy-paste) and
  /// always runs; when `ignore_locals` is enabled a second pass compares
  /// masked values (Type-2 renamed clones). Candidates from both passes
  /// compete in one greedy selection, so a longer renamed clone wins
  /// over the shorter exact copy it contains.
  List<_CloneGroup> detect(
    List<_FileTokens> files,
    DuplicationMatching matching,
  ) {
    final candidates = <_CloneGroup>[];
    if (matching.ignoreLocals) {
      candidates.addAll(
        _collectGroups(files, matching, _rawCodes),
      );
    }
    candidates.addAll(_collectGroups(files, matching, _maskedCodes));

    // Longest clones first, then most occurrences, then position — the
    // selection order that keeps reporting deterministic.
    candidates.sort(_byPriority);
    return _accept(files, candidates);
  }

  /// The reporting order: longest clones first, then most occurrences,
  /// then first position.
  static int _byPriority(_CloneGroup a, _CloneGroup b) {
    final byLength = b.tokenCount.compareTo(a.tokenCount);
    if (byLength != 0) return byLength;
    final byOcc = b.occurrences.length.compareTo(a.occurrences.length);
    if (byOcc != 0) return byOcc;
    final firstA = a.occurrences.first;
    final firstB = b.occurrences.first;
    if (firstA.fileIndex != firstB.fileIndex) {
      return firstA.fileIndex.compareTo(firstB.fileIndex);
    }
    return firstA.startToken.compareTo(firstB.startToken);
  }

  /// Greedily accepts non-overlapping groups and marks their tokens.
  List<_CloneGroup> _accept(
    List<_FileTokens> files,
    List<_CloneGroup> candidates,
  ) {
    final accepted = <_CloneGroup>[];
    final taken = <int, List<_TokenRange>>{};
    for (final group in candidates) {
      if (group.occurrences.any(
        (o) => _overlaps(taken[o.fileIndex], o.startToken, o.endToken),
      )) {
        continue;
      }
      for (final o in group.occurrences) {
        taken
            .putIfAbsent(o.fileIndex, () => [])
            .add((start: o.startToken, end: o.endToken));
        final tokens = files[o.fileIndex].tokens;
        for (var i = o.startToken; i < o.endToken; i++) {
          tokens[i].duplicated = true;
        }
      }
      accepted.add(group);
    }
    return accepted;
  }

  /// Whether [start]..[end) overlaps any accepted range of one file.
  bool _overlaps(List<_TokenRange>? ranges, int start, int end) {
    if (ranges == null) return false;
    return ranges.any((r) => start < r.end && r.start < end);
  }

  /// Token codes from the raw lexemes.
  List<int> _rawCodes(List<_NormalizedToken> tokens) =>
      [for (final t in tokens) t.lexeme.hashCode.toUnsigned(64)];

  /// Token codes from the masked (normalized) values.
  List<int> _maskedCodes(List<_NormalizedToken> tokens) =>
      [for (final t in tokens) t.value.hashCode.toUnsigned(64)];

  /// Indexes all valid windows of a single file.
  void _indexFile(
    _FileTokens file,
    int fileIndex,
    DuplicationMatching matching,
    List<int> Function(List<_NormalizedToken>) codeOf,
    Map<int, List<_TokenPos>> occurrences,
  ) {
    final tokens = file.tokens;
    final n = tokens.length;
    if (n < matching.minTokens) return;

    final minTokens = matching.minTokens;
    final minLines = matching.minLines;
    final lines = tokens.map((t) => t.line).toList();
    final codes = codeOf(tokens);
    final pow = _modPow(_base, minTokens - 1);

    var hash = 0;
    for (var i = 0; i < minTokens; i++) {
      hash = ((hash * _base) + codes[i]) & _mask;
    }
    _recordIfValid(occurrences, hash, fileIndex, 0, lines, minTokens, minLines);

    for (var start = 1; start <= n - minTokens; start++) {
      final removed = (codes[start - 1] * pow) & _mask;
      hash = (hash - removed) & _mask;
      hash = ((hash * _base) + codes[start + minTokens - 1]) & _mask;
      _recordIfValid(
        occurrences,
        hash,
        fileIndex,
        start,
        lines,
        minTokens,
        minLines,
      );
    }
  }

  /// Records a window only when it spans at least [minLines] lines.
  void _recordIfValid(
    Map<int, List<_TokenPos>> occurrences,
    int hash,
    int fileIndex,
    int start,
    List<int> lines,
    int minTokens,
    int minLines,
  ) {
    final firstLine = lines[start];
    final lastLine = lines[start + minTokens - 1];
    if (lastLine - firstLine + 1 < minLines) return;
    occurrences.putIfAbsent(hash, () => <_TokenPos>[]).add(
          _TokenPos(fileIndex, start),
        );
  }

  /// Turns the window index into clone-group candidates for one pass.
  ///
  /// Every bucket of at least two window positions becomes one candidate:
  /// the windows are verified against the bucket reference by actual code
  /// equality (Rabin-Karp fingerprints can collide), extended to the
  /// maximal extent all occurrences share, and clipped to the common
  /// token count.
  List<_CloneGroup> _collectGroups(
    List<_FileTokens> files,
    DuplicationMatching matching,
    List<int> Function(List<_NormalizedToken>) codeOf,
  ) {
    final occurrences = <int, List<_TokenPos>>{};
    for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
      _indexFile(files[fileIndex], fileIndex, matching, codeOf, occurrences);
    }

    final codeCache = <int, List<int>>{
      for (var i = 0; i < files.length; i++) i: codeOf(files[i].tokens),
    };
    final groups = <_CloneGroup>[];
    for (final positions in occurrences.values) {
      if (positions.length < 2) continue;
      final group = _groupFromBucket(files, positions, codeCache, matching);
      if (group != null) groups.add(group);
    }
    return groups;
  }

  /// Builds one candidate clone group from a bucket of window
  /// positions, or null when the bucket holds no real duplicate of at
  /// least [DuplicationMatching.minLines] lines.
  _CloneGroup? _groupFromBucket(
    List<_FileTokens> files,
    List<_TokenPos> positions,
    Map<int, List<int>> codeCache,
    DuplicationMatching matching,
  ) {
    final ref = positions.first;
    final refCodes = codeCache[ref.fileIndex]!;
    final extents = <_TokenRange>[];
    final occs = <_TokenPos>[];
    for (final pos in positions) {
      final codes = codeCache[pos.fileIndex]!;
      if (!_sameWindow(
        codes,
        pos.tokenIndex,
        refCodes,
        ref.tokenIndex,
        matching.minTokens,
      )) {
        continue; // fingerprint collision, not a real duplicate
      }
      occs.add(pos);
      extents.add(
        _extent(
          codes,
          pos.tokenIndex,
          refCodes,
          ref.tokenIndex,
          matching.minTokens,
        ),
      );
    }
    if (occs.length < 2) return null;
    // The reference must not extend against itself — that would grow
    // its extent over the whole file. The common length therefore
    // comes from the other occurrences; the reference is anchored at
    // its own window and clipped to the same length.
    var commonLen = matching.minTokens;
    for (var i = 1; i < extents.length; i++) {
      final (s, e) = (extents[i].start, extents[i].end);
      commonLen = min(commonLen, e - s);
    }
    final refLines = files[occs.first.fileIndex].tokens;
    final refStart = occs.first.tokenIndex;
    final lineSpan =
        refLines[refStart + commonLen - 1].line - refLines[refStart].line + 1;
    if (lineSpan < matching.minLines) return null;
    return _CloneGroup([
      _CloneOccurrence(
        occs.first.fileIndex,
        refStart,
        refStart + commonLen,
      ),
      for (var i = 1; i < occs.length; i++)
        _CloneOccurrence(
          occs[i].fileIndex,
          extents[i].start,
          extents[i].start + commonLen,
        ),
    ]);
  }

  /// Whether the two token windows are equal by code.
  bool _sameWindow(
    List<int> a,
    int aStart,
    List<int> b,
    int bStart,
    int length,
  ) {
    for (var i = 0; i < length; i++) {
      if (a[aStart + i] != b[bStart + i]) return false;
    }
    return true;
  }

  /// Maximal extent of the window at [curStart] shared with the
  /// reference window at [refStart]: grown left and right while the
  /// surrounding codes match.
  _TokenRange _extent(
    List<int> cur,
    int curStart,
    List<int> ref,
    int refStart,
    int minTokens,
  ) {
    var start = curStart;
    var refS = refStart;
    while (start > 0 && refS > 0 && cur[start - 1] == ref[refS - 1]) {
      start--;
      refS--;
    }
    var end = curStart + minTokens;
    var refE = refStart + minTokens;
    while (end < cur.length && refE < ref.length && cur[end] == ref[refE]) {
      end++;
      refE++;
    }
    return (start: start, end: end);
  }

  /// Computes `base^exp mod 2^64`.
  int _modPow(int base, int exp) {
    var result = 1 & _mask;
    var b = base & _mask;
    var e = exp;
    while (e > 0) {
      if (e & 1 == 1) result = (result * b) & _mask;
      b = (b * b) & _mask;
      e >>= 1;
    }
    return result;
  }
}
