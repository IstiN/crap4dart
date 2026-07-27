import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:crap4dart/src/coverage/method_coverage.dart';
import 'package:test/test.dart';

void main() {
  const calculator = MethodCoverageCalculator();

  MethodInfo method(int start, int end) => MethodInfo(
        className: 'A',
        methodName: 'm',
        startLine: start,
        endLine: end,
        filePath: 'lib/a.dart',
      );

  FileCoverage file({
    Map<int, int>? hits,
    List<BranchHit> branches = const [],
  }) {
    final coverage = FileCoverage(path: 'lib/a.dart');
    if (hits != null) coverage.lineHits.addAll(hits);
    coverage.branches.addAll(branches);
    return coverage;
  }

  group('lineCoverage', () {
    test('computes covered/total within the method range', () {
      final coverage = file(hits: {2: 1, 3: 0, 4: 5, 9: 1});
      expect(calculator.lineCoverage(method(2, 4), coverage), 2 / 3);
    });

    test('returns 0 when nothing is covered', () {
      final coverage = file(hits: {2: 0, 3: 0});
      expect(calculator.lineCoverage(method(1, 5), coverage), 0.0);
    });

    test('returns 1 when everything is covered', () {
      final coverage = file(hits: {2: 1, 3: 9});
      expect(calculator.lineCoverage(method(1, 5), coverage), 1.0);
    });

    test('returns null when no DA records fall in the range', () {
      final coverage = file(hits: {10: 1, 11: 0});
      expect(calculator.lineCoverage(method(2, 4), coverage), isNull);
    });
  });

  group('branchCoverage', () {
    test('computes taken/total within the method range', () {
      final coverage = file(branches: const [
        BranchHit(line: 2, block: 0, branch: 0, taken: 3),
        BranchHit(line: 2, block: 0, branch: 1, taken: 0),
        BranchHit(line: 3, block: 1, branch: 0, taken: null),
        BranchHit(line: 9, block: 2, branch: 0, taken: 1),
      ]);
      expect(calculator.branchCoverage(method(2, 4), coverage), 1 / 3);
    });

    test('returns null when no BRDA records fall in the range', () {
      final coverage = file(hits: {2: 1});
      expect(calculator.branchCoverage(method(2, 4), coverage), isNull);
    });
  });
}
