import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/gates/similarity/similarity_gate.dart';
import 'package:crap4dart/src/similarity/similarity_analyzer.dart';
import 'package:test/test.dart';

import '../gates/gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('default excludes cover scratch and vendored trees', () {
    const defaults = SimilarityGateConfig();
    expect(defaults.exclude, contains('.git/**'));
    expect(defaults.exclude, contains('.dart_tool/**'));
    expect(defaults.exclude, contains('.worktrees/**'));
    expect(defaults.exclude, contains('build/**'));
  });

  test('scan over the file cap throws instead of exhausting memory', () async {
    // Empty files: the cap trips right after collection, before any
    // content is read or shingled.
    for (var i = 0; i < SimilarityAnalyzer.maxScanFiles + 1; i++) {
      writeFile(project, 'docs/f$i.md', '');
    }
    expect(
      () => const SimilarityAnalyzer().analyze(
        project,
        dirs: const ['.'],
        include: const ['**/*.md'],
        exclude: const [],
        jaccardThreshold: 0.5,
        containmentThreshold: 0.85,
        minShingles: 50,
      ),
      throwsA(
        isA<SimilarityScanTooLargeException>().having(
          (e) => e.matched,
          'matched',
          greaterThan(SimilarityAnalyzer.maxScanFiles),
        ),
      ),
    );
  });

  test('gate fails loudly with guidance when the scope is too broad', () async {
    for (var i = 0; i < SimilarityAnalyzer.maxScanFiles + 1; i++) {
      writeFile(project, 'docs/f$i.md', '');
    }
    final result = await const SimilarityGate().run(
      makeContext(
        project,
        [],
        configYaml: 'gates:\n  similarity:\n    enabled: true\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.summary, contains('safety cap'));
  });
}
