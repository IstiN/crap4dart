import 'package:crap4dart/src/analysis/cognitive.dart';
import 'package:crap4dart/src/analysis/complexity.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

int cognitiveOf(String source) {
  final methods = parseMethods(source);
  assert(methods.length == 1, 'expected exactly one method in fixture');
  return const CognitiveCalculator().compute(methods.single.node);
}

void main() {
  group('CognitiveCalculator flow breaks', () {
    test('logical operator sequences count once per same-operator run', () {
      expect(
        cognitiveOf('''
bool f(bool a, bool b, bool c) {
  return a && b && c;
}
'''),
        1,
      );
      expect(
        cognitiveOf('''
bool f(bool a, bool b, bool c) {
  return a && b || c;
}
'''),
        2,
      );
    });

    test('catch, switch members each increment', () {
      expect(
        cognitiveOf('''
String f(Object x) {
  switch (x) {
    case int():
      return 'int';
    default:
      return 'other';
  }
}
'''),
        2,
      );
      expect(
        cognitiveOf('''
int f(int x) {
  try {
    return int.parse('\$x');
  } on FormatException {
    return 0;
  }
}
'''),
        1,
      );
    });

    test('nested ternaries pay nesting on the inner branch', () {
      expect(
        cognitiveOf('''
int f(int x) => x > 0 ? 1 : x < 0 ? -1 : 0;
'''),
        3,
      );
    });
  });

  group('MetricCalculator interface', () {
    test('cognitive reports its metric name', () {
      expect(const CognitiveCalculator().metricName, 'cognitive');
      expect(const ComplexityCalculator().metricName, 'CC');
    });
  });
}
