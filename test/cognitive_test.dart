import 'package:crap4dart/src/analysis/cognitive.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

int cognitiveOf(String source) {
  final methods = parseMethods(source);
  assert(methods.length == 1, 'expected exactly one method in fixture');
  return const CognitiveCalculator().compute(methods.single.node);
}

void main() {
  group('CognitiveCalculator', () {
    test('linear code scores zero', () {
      expect(
        cognitiveOf('''
int add(int a, int b) => a + b;
'''),
        0,
      );
    });

    test('a flat if scores one', () {
      expect(
        cognitiveOf('''
String f(int x) {
  if (x > 0) return 'pos';
  return 'other';
}
'''),
        1,
      );
    });

    test('an if inside a loop pays the nesting penalty (Sonar example)', () {
      // for = +1, if inside = +1 + nesting 1
      expect(
        cognitiveOf('''
int f(int max) {
  var total = 0;
  for (var i = 1; i <= max; i++) {
    if (i % 2 == 0) total += i;
  }
  return total;
}
'''),
        3,
      );
    });

    test('else-if chains stay flat while nested else pays nesting', () {
      final chain = cognitiveOf('''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  } else if (x < 10) {
    return 'small';
  }
  return 'other';
}
''');
      final nested = cognitiveOf('''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else {
    if (x == 0) {
      return 'zero';
    } else {
      if (x < 10) {
        return 'small';
      }
    }
  }
  return 'other';
}
''');
      expect(chain, 3, reason: 'flat chain: one increment per if');
      expect(nested, 9, reason: 'if +1, else +1, if +2, else +2, if +3');
    });
  });
}
