import 'dart:io';

import 'package:crap4dart/src/similarity/similarity_analyzer.dart';
import 'package:test/test.dart';

import 'similarity_fixtures.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('sim_filter_'));
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

  test('files below the shingle floor are skipped', () {
    File('${root.path}/tiny.md').writeAsStringSync('too short');
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/c.md').writeAsStringSync(proseC);
    final report = analyze(minShingles: 20);
    expect(report.scanned, 2);
    expect(report.skipped, 1);
  });
  test('exclude globs drop files from the scan', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    Directory('${root.path}/generated').createSync();
    File('${root.path}/generated/b.md').writeAsStringSync(proseA);
    final report = analyze(exclude: ['generated/**']);
    expect(report.scanned, 1);
    expect(report.clean, isTrue);
  });
  test('include globs limit the scan to matching files', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/a.txt').writeAsStringSync(proseA);
    final report = analyze(include: ['*.txt']);
    expect(report.scanned, 1);
  });
  test('clean corpora report clean', () {
    File('${root.path}/a.md').writeAsStringSync(proseA);
    File('${root.path}/c.md').writeAsStringSync(proseC);
    expect(analyze().clean, isTrue);
    expect(analyze().clusters, isEmpty);
  });
}
