import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ComplexityCalculator switch expressions', () {
    test('switch expression arms add one each', () {
      expect(
        complexityOf('''
enum Lie { green, fringe, rough }

String f(Lie lie) => switch (lie) {
      Lie.green => 'Green',
      Lie.fringe => 'Fringe',
      Lie.rough => 'Rough',
    };
'''),
        4,
      );
    });

    test('switch expression and switch statement score the same', () {
      const arms = '''
enum Lie { green, fringe, rough }
''';
      final expression = complexityOf('''
$arms
String f(Lie lie) => switch (lie) {
      Lie.green => 'Green',
      Lie.fringe => 'Fringe',
      Lie.rough => 'Rough',
    };
''');
      final statement = complexityOf('''
$arms
String f(Lie lie) {
  switch (lie) {
    case Lie.green:
      return 'Green';
    case Lie.fringe:
      return 'Fringe';
    case Lie.rough:
      return 'Rough';
  }
}
''');
      expect(expression, statement);
    });

    test('wildcard arm counts like a default clause', () {
      expect(
        complexityOf('''
String f(int value) => switch (value) {
      0 => 'zero',
      _ => 'other',
    };
'''),
        3,
      );
    });

    test('guard clauses on switch expression arms are not double counted', () {
      expect(
        complexityOf('''
String f(int value) => switch (value) {
      final int v when v > 10 => 'big',
      _ => 'small',
    };
'''),
        3,
      );
    });
  });
}
