import 'package:crap4dart/src/analysis/complexity.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ComplexityCalculator nesting', () {
    test('conditional expression adds one', () {
      expect(
        complexityOf('''
String f(bool b) => b ? 'yes' : 'no';
'''),
        2,
      );
    });

    test('nested branches accumulate', () {
      // 1 base + if + for + if + && = 5
      expect(
        complexityOf('''
void f(List<int> xs) {
  if (xs.isNotEmpty) {
    for (final x in xs) {
      if (x > 0 && x < 10) print(x);
    }
  }
}
'''),
        5,
      );
    });

    test('branches inside lambdas count towards the method', () {
      expect(
        complexityOf('''
void f(List<int> xs) {
  xs.where((x) => x > 0 && x < 10).forEach(print);
}
'''),
        2,
      );
    });

    test('nested named function declarations are not counted', () {
      expect(
        complexityOf('''
void f() {
  int helper(int x) {
    if (x > 0) return 1;
    return 0;
  }
  print(helper(1));
}
'''),
        1,
      );
    });

    test('countLambdas=false skips lambda branches', () {
      final methods = parseMethods('''
void f(List<int> xs) {
  xs.where((x) => x > 0 && x < 10).forEach(print);
}
''');
      expect(
        const ComplexityCalculator().compute(methods.single.node),
        2,
      );
      expect(
        const ComplexityCalculator(countLambdas: false)
            .compute(methods.single.node),
        1,
      );
    });
  });
}
