import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ComplexityCalculator switch expressions and patterns', () {
    test('switch expression cases each add one', () {
      expect(
        complexityOf('''
String f(int x) {
  return switch (x) {
    1 => 'one',
    2 => 'two',
    _ => 'other',
  };
}
'''),
        4,
      );
    });

    test('switch expression when-guards add one each', () {
      expect(
        complexityOf('''
String f(Object x) {
  return switch (x) {
    int y when y > 0 => 'pos',
    int y when y < 0 => 'neg',
    _ => 'other',
  };
}
'''),
        6,
      );
    });

    test('logical-or patterns add one like || conditions', () {
      expect(
        complexityOf('''
String f(Object x) {
  return switch (x) {
    int() || double() => 'num',
    _ => 'other',
  };
}
'''),
        4,
      );
    });

    test('if-case clause and its when-guard add one each', () {
      expect(
        complexityOf('''
String f(Object x) {
  if (x case int y when y > 0) return 'pos';
  return 'other';
}
'''),
        3,
      );
    });
  });
}
