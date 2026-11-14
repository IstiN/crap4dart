import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'shingles.dart';
import 'similarity_profile.dart';

/// The strongest pair metrics of one file: best Jaccard and
/// containment across all pairs it participates in.
typedef SimilarityMetrics = ({double jaccard, double containment});

/// One analyzed file: its (project-relative) path and shingle set.
class SimilarityFile {
  /// Project-relative path.
  final String path;

  /// The file's shingle hash set (empty when below the shingle floor).
  final Set<int> shingles;

  /// Creates a [SimilarityFile].
  const SimilarityFile({required this.path, required this.shingles});

  @override
  String toString() => path;
}

/// A pair of files whose similarity crosses at least one threshold.
class SimilarityPair {
  /// First file (path), lexicographically before [b].
  final String a;

  /// Second file (path).
  final String b;

  /// Jaccard similarity of the pair's shingle sets.
  final double jaccard;

  /// Containment of the smaller set in the larger one.
  final double containment;

  /// Creates a [SimilarityPair].
  const SimilarityPair({
    required this.a,
    required this.b,
    required this.jaccard,
    required this.containment,
  });

  @override
  String toString() => '$a <-> $b (jaccard ${jaccard.toStringAsFixed(2)}, '
      'containment ${containment.toStringAsFixed(2)})';
}

/// A connected group of similar files (transitively merged pairs).
class SimilarityCluster {
  /// Member paths, sorted.
  final List<String> files;

  /// The threshold-crossing pairs inside the cluster.
  final List<SimilarityPair> pairs;

  /// Creates a [SimilarityCluster].
  const SimilarityCluster({required this.files, required this.pairs});

  @override
  String toString() => '${files.length} files (${files.first}…)';
}

/// The outcome of a similarity scan.
class SimilarityReport {
  /// Number of files read and analyzed.
  final int scanned;

  /// Files skipped for carrying fewer shingles than the floor.
  final int skipped;

  /// Threshold-crossing pairs, sorted by Jaccard descending.
  final List<SimilarityPair> pairs;

  /// Clusters (groups of ≥ 2 files), largest first.
  final List<SimilarityCluster> clusters;

  /// Creates a [SimilarityReport].
  const SimilarityReport({
    required this.scanned,
    required this.skipped,
    required this.pairs,
    required this.clusters,
  });

  /// The paths inside all clusters.
  Iterable<String> get clusteredPaths => clusters.expand((c) => c.files);

  /// Whether nothing crossed the thresholds.
  bool get clean => pairs.isEmpty;

  /// The strongest pair metrics [path] participates in, or `null`.
  SimilarityMetrics? metricsFor(String path) {
    SimilarityMetrics? best;
    for (final pair in pairs) {
      if (pair.a != path && pair.b != path) continue;
      final candidate = (
        jaccard: pair.jaccard,
        containment: pair.containment,
      );
      if (best == null || candidate.jaccard > best.jaccard) {
        best = candidate;
      }
    }
    return best;
  }
}

/// The scan scope matched more files than [SimilarityAnalyzer
/// .maxScanFiles]; thrown instead of exhausting memory on the shingle
/// index. Narrows the gate's `include`/`dirs` or extends its
/// `exclude`.
class SimilarityScanTooLargeException implements Exception {
  /// Number of files the scope matched.
  final int matched;

  /// The ceiling that was exceeded.
  final int max;

  /// Creates a [SimilarityScanTooLargeException].
  const SimilarityScanTooLargeException(this.matched, this.max);

  @override
  String toString() =>
      'similarity scan scope matches $matched files, above the $max-file '
      'safety cap: narrow `include`/`dirs` or extend `exclude`';
}

/// Union-find over analyzed file indices.
class _UnionFind {
  final Map<String, String> _parent = {};

  void add(String item) => _parent[item] = item;

  void union(String a, String b) {
    final ra = _find(a);
    final rb = _find(b);
    if (ra != rb) _parent[rb] = ra;
  }

  String _find(String item) {
    var root = item;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    // Path compression.
    while (_parent[item] != root) {
      final next = _parent[item]!;
      _parent[item] = root;
      item = next;
    }
    return root;
  }
}

/// Scans directories for text files and clusters near-duplicate
/// content by shingle similarity.
class SimilarityAnalyzer {
  /// Hard ceiling on the number of files one scan analyzes. Beyond
  /// this the scan is almost certainly an over-broad `include`/`dirs`
  /// scope (vendored checkouts, generated corpora) that would exhaust
  /// memory on the shingle index; [analyze] throws
  /// [SimilarityScanTooLargeException] instead of crashing the whole
  /// check run.
  static const int maxScanFiles = 20000;

  /// Shingle hashes shared by more files than this carry no duplicate
  /// signal (boilerplate) and are skipped when building pair
  /// candidates.
  static const int _maxPostings = 100;

  /// Creates a [SimilarityAnalyzer].
  const SimilarityAnalyzer();

  /// Whether [path] matches any compiled glob.
  static bool _matchesAny(List<Glob> globs, String path) =>
      globs.any((glob) => glob.matches(path));

  /// The path of [absolute] relative to the project root.
  static String _relative(Directory root, String absolute) =>
      p.relative(absolute, from: root.path);

  /// All pairs crossing either threshold, strongest first.
  ///
  /// Comparisons are candidate-pruned through an inverted shingle
  /// index: a pair can only cross a positive threshold when the two
  /// files share at least one shingle hash, so exact Jaccard /
  /// containment run on candidate pairs only. The naive all-pairs loop
  /// is quadratic in the file count and made large trees effectively
  /// hang (IstiN/crap4dart#34).
  static List<SimilarityPair> _pairsOverThresholds(
    List<SimilarityFile> files,
    double jaccardThreshold,
    double containmentThreshold,
  ) {
    final pairs = <SimilarityPair>[];
    for (final (a, b) in _candidates(files)) {
      final jScore = jaccard(a.shingles, b.shingles);
      final cScore = containment(a.shingles, b.shingles);
      if (jScore < jaccardThreshold && cScore < containmentThreshold) {
        continue;
      }
      pairs.add(SimilarityPair(
        a: a.path,
        b: b.path,
        jaccard: jScore,
        containment: cScore,
      ));
    }
    pairs.sort((x, y) => y.jaccard.compareTo(x.jaccard));
    return pairs;
  }

  /// Unique file pairs sharing at least one shingle hash, via an
  /// inverted index. Pairs are emitted in index order; deduplicated
  /// with a set of flattened (i, j) keys that grows with the candidate
  /// count, not the quadratic pair space.
  static Iterable<(SimilarityFile, SimilarityFile)> _candidates(
    List<SimilarityFile> files,
  ) sync* {
    final index = <int, List<int>>{};
    for (var i = 0; i < files.length; i++) {
      for (final hash in files[i].shingles) {
        index.putIfAbsent(hash, () => []).add(i);
      }
    }
    final seen = <int>{};
    final width = files.length;
    for (final postings in index.values) {
      if (postings.length < 2 || postings.length > _maxPostings) {
        continue;
      }
      for (var x = 0; x < postings.length; x++) {
        for (var y = x + 1; y < postings.length; y++) {
          final i = postings[x];
          final j = postings[y];
          if (!seen.add(i * width + j)) continue;
          yield (files[i], files[j]);
        }
      }
    }
  }

  /// Transitive clusters of the threshold-crossing pairs, largest
  /// first.
  static List<SimilarityCluster> _clusters(
    List<SimilarityFile> files,
    List<SimilarityPair> pairs,
  ) {
    final union = _UnionFind();
    for (final file in files) {
      union.add(file.path);
    }
    for (final pair in pairs) {
      union.union(pair.a, pair.b);
    }
    final groups = <String, List<String>>{};
    for (final file in files) {
      groups.putIfAbsent(union._find(file.path), () => []).add(file.path);
    }
    final clusters = [
      for (final members in groups.values)
        if (members.length > 1)
          SimilarityCluster(
            files: members..sort(),
            pairs: [
              for (final pair in pairs)
                if (members.contains(pair.a) && members.contains(pair.b)) pair,
            ],
          ),
    ]..sort((a, b) => b.files.length.compareTo(a.files.length));
    return clusters;
  }

  /// Analyzes [dirs] (project-relative, recursive) under [root],
  /// keeping files matching [include] and dropping [exclude] globs.
  ///
  /// Files with fewer than [minShingles] shingles are skipped — tiny
  /// files carry no reliable signal. Pairs cross when Jaccard ≥
  /// [jaccardThreshold] OR containment ≥ [containmentThreshold].
  SimilarityReport analyze(
    Directory root, {
    required List<String> dirs,
    required List<String> include,
    required List<String> exclude,
    required double jaccardThreshold,
    required double containmentThreshold,
    required int minShingles,
  }) {
    final files = _collect(
      root,
      dirs,
      [for (final pattern in include) Glob(pattern)],
      [for (final pattern in exclude) Glob(pattern)],
    );
    if (files.length > maxScanFiles) {
      throw SimilarityScanTooLargeException(files.length, maxScanFiles);
    }
    final analyzed = <SimilarityFile>[];
    var skipped = 0;
    for (final entry in files) {
      final shingles = shinglesFor(
        entry.readAsStringSync(),
        SimilarityProfiles.profileFor(entry.path),
      );
      if (shingles.length < minShingles) {
        skipped++;
        continue;
      }
      analyzed.add(SimilarityFile(
        path: _relative(root, entry.path),
        shingles: shingles,
      ));
    }
    final pairs = _pairsOverThresholds(
      analyzed,
      jaccardThreshold,
      containmentThreshold,
    );
    return SimilarityReport(
      scanned: analyzed.length,
      skipped: skipped,
      pairs: pairs,
      clusters: _clusters(analyzed, pairs),
    );
  }

  /// Non-excluded files matching [include] under [dirs], sorted by
  /// project-relative path.
  List<File> _collect(
    Directory root,
    List<String> dirs,
    List<Glob> include,
    List<Glob> exclude,
  ) {
    final collected = <File>[];
    for (final dir in dirs) {
      final directory = Directory(
        p.isAbsolute(dir) ? dir : p.join(root.path, dir),
      );
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relative = _relative(root, entity.path);
        if (!_matchesAny(include, relative)) continue;
        if (_matchesAny(exclude, relative)) continue;
        collected.add(entity);
      }
    }
    collected.sort(
      (a, b) => _relative(root, a.path).compareTo(_relative(root, b.path)),
    );
    return collected;
  }
}
