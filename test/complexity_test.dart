import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ComplexityCalculator statements', () {
    test('simple method has complexity 1', () {
      expect(
        complexityOf('''
class A {
  int f() => 42;
}
'''),
        1,
      );
    });

    test('if and for add one each', () {
      expect(
        complexityOf('''
class A {
  void f(List<int> xs) {
    if (xs.isEmpty) return;
    for (final x in xs) {
      print(x);
    }
  }
}
'''),
        3,
      );
    });

    test('&& and || each add one', () {
      expect(
        complexityOf('''
bool f(bool a, bool b, bool c) {
  return a && b || c;
}
'''),
        3,
      );
    });

    test('while, do-while and catch add one each', () {
      expect(
        complexityOf('''
void f() {
  var i = 0;
  while (i < 10) { i++; }
  do { i--; } while (i > 0);
  try {
    throw StateError('x');
  } on StateError {
    rethrow;
  } catch (e) {
    print(e);
  }
}
'''),
        5,
      );
    });

    test('switch cases including default add one each', () {
      expect(
        complexityOf('''
String f(int x) {
  switch (x) {
    case 1:
      return 'one';
    case 2:
      return 'two';
    default:
      return 'other';
  }
}
'''),
        4,
      );
    });
  });
}
