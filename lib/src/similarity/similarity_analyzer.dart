import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'shingles.dart';
import 'similarity_profile.dart';

/// One analyzed file: its (project-relative) path and shingle set.
class SimilarityFile {
  /// Creates a [SimilarityFile].
  const SimilarityFile({required this.path, required this.shingles});

  /// Project-relative path.
  final String path;

  /// The file's shingle set (empty when below the shingle floor).
  final Set<String> shingles;

  @override
  String toString() => path;
}

/// A pair of files whose similarity crosses at least one threshold.
class SimilarityPair {
  /// Creates a [SimilarityPair].
  const SimilarityPair({
    required this.a,
    required this.b,
    required this.jaccard,
    required this.containment,
  });

  /// First file (path), lexicographically before [b].
  final String a;

  /// Second file (path).
  final String b;

  /// Jaccard similarity of the pair's shingle sets.
  final double jaccard;

  /// Containment of the smaller set in the larger one.
  final double containment;

  @override
  String toString() => '$a <-> $b (jaccard ${jaccard.toStringAsFixed(2)}, '
      'containment ${containment.toStringAsFixed(2)})';
}

/// A connected group of similar files (transitively merged pairs).
class SimilarityCluster {
  /// Creates a [SimilarityCluster].
  const SimilarityCluster({required this.files, required this.pairs});

  /// Member paths, sorted.
  final List<String> files;

  /// The threshold-crossing pairs inside the cluster.
  final List<SimilarityPair> pairs;

  @override
  String toString() => '${files.length} files (${files.first}…)';
}

/// The outcome of a similarity scan.
class SimilarityReport {
  /// Creates a [SimilarityReport].
  const SimilarityReport({
    required this.scanned,
    required this.skipped,
    required this.pairs,
    required this.clusters,
  });

  /// Number of files read and analyzed.
  final int scanned;

  /// Files skipped for carrying fewer shingles than the floor.
  final int skipped;

  /// Threshold-crossing pairs, sorted by Jaccard descending.
  final List<SimilarityPair> pairs;

  /// Clusters (groups of ≥ 2 files), largest first.
  final List<SimilarityCluster> clusters;

  /// The paths inside all clusters.
  Iterable<String> get clusteredPaths => clusters.expand((c) => c.files);

  /// Whether nothing crossed the thresholds.
  bool get clean => pairs.isEmpty;

  /// The strongest pair metrics [path] participates in, or `null`.
  (double, double)? metricsFor(String path) {
    (double, double)? best;
    for (final pair in pairs) {
      if (pair.a != path && pair.b != path) continue;
      final candidate = (pair.jaccard, pair.containment);
      if (best == null || candidate.$1 > best.$1) best = candidate;
    }
    return best;
  }
}

/// Union-find over analyzed file indices.
class _UnionFind {
  final Map<String, String> _parent = {};

  void add(String item) => _parent[item] = item;

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

  void union(String a, String b) {
    final ra = _find(a);
    final rb = _find(b);
    if (ra != rb) _parent[rb] = ra;
  }
}

/// Scans directories for text files and clusters near-duplicate
/// content by shingle similarity.
class SimilarityAnalyzer {
  /// Creates a [SimilarityAnalyzer].
  const SimilarityAnalyzer();

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

  /// Whether [path] matches any compiled glob.
  static bool _matchesAny(List<Glob> globs, String path) =>
      globs.any((glob) => glob.matches(path));

  /// The path of [absolute] relative to the project root.
  static String _relative(Directory root, String absolute) =>
      p.relative(absolute, from: root.path);

  /// All pairs crossing either threshold, strongest first.
  static List<SimilarityPair> _pairsOverThresholds(
    List<SimilarityFile> files,
    double jaccardThreshold,
    double containmentThreshold,
  ) {
    final pairs = <SimilarityPair>[];
    for (var i = 0; i < files.length; i++) {
      for (var j = i + 1; j < files.length; j++) {
        final a = files[i];
        final b = files[j];
        final jScore = jaccard(a.shingles, b.shingles);
        if (jScore < jaccardThreshold &&
            containment(a.shingles, b.shingles) < containmentThreshold) {
          continue;
        }
        pairs.add(SimilarityPair(
          a: a.path,
          b: b.path,
          jaccard: jScore,
          containment: containment(a.shingles, b.shingles),
        ));
      }
    }
    pairs.sort((x, y) => y.jaccard.compareTo(x.jaccard));
    return pairs;
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
}
