import 'dart:io';

import 'package:crap4dart/src/similarity/similarity_analyzer.dart';
import 'package:test/test.dart';

import 'similarity_fixtures.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('sim_cluster_'));
  tearDown(() => root.deleteSync(recursive: true));

  SimilarityReport analyze({
    List<String> include = const ['**/*.md'],
    List<String> exclude = const ['.git/**'],
    double jaccard = 0.5,
    double containment = 0.85,
    int minShingles = 10,
  }) =>
      const SimilarityAnalyzer().analyze(
        root,
        dirs: ['.'],
        include: include,
        exclude: exclude,
        jaccardThreshold: jaccard,
        containmentThreshold: containment,
        minShingles: minShingles,
      );

  test('exact duplicates cluster with jaccard 1.0', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/b.md').writeAsStringSync(proseA);
    final report = analyze();
    expect(report.scanned, 2);
    expect(report.clusters, hasLength(1));
    expect(report.pairs.single.jaccard, 1.0);
    expect(report.clusteredPaths, containsAll(['a.md', 'b.md']));
  });
  test('near-duplicates cross the threshold, unrelated files do not', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/b.md').writeAsStringSync(proseB);
    File('${root.path}/c.md').writeAsStringSync(proseC);
    final report = analyze();
    expect(report.pairs, hasLength(1));
    expect(report.pairs.single.a, 'a.md');
    expect(report.pairs.single.b, 'b.md');
    // k=8 shingles: two scattered word changes cost ~16 of ~39
    // shingles — near-duplicates land around 0.5, well above the 0.5
    // threshold, while unrelated prose stays near 0.
    expect(report.pairs.single.jaccard, greaterThan(0.4));
  });
  test('transitive pairs merge into one cluster', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/b.md').writeAsStringSync(proseA);
    File('${root.path}/c.md').writeAsStringSync(proseA);
    final report = analyze();
    expect(report.clusters.single.files, hasLength(3));
  });
  test('containment catches a small file copied into a big one', () {
    File('${root.path}/small.md').writeAsStringSync(proseA);
    File('${root.path}/big.md')
        .writeAsStringSync('$proseA\n\n$proseC\n\n$proseB');
    final report = analyze(jaccard: 0.9, containment: 0.85);
    expect(report.pairs, hasLength(1));
    expect(report.pairs.single.containment, greaterThan(0.85));
    expect(report.pairs.single.jaccard, lessThan(0.9));
  });
  test('metricsFor returns the strongest pair of a file', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/b.md').writeAsStringSync(proseA);
    File('${root.path}/c.md').writeAsStringSync(proseC);
    final report = analyze();
    expect(report.metricsFor('a.md')?.$1, 1.0);
    expect(report.metricsFor('c.md'), isNull);
  });
}
