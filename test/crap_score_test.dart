import 'package:crap4dart/src/crap/crap_score.dart';
import 'package:test/test.dart';

void main() {
  group('crapScore', () {
    test('CC=1 with full coverage is 1.0', () {
      expect(crapScore(1, 1.0), 1.0);
    });

    test('CC=2 with zero coverage is 6.0', () {
      // 2^2 * (1-0)^3 + 2 = 4 + 2 = 6
      expect(crapScore(2, 0.0), 6.0);
    });

    test('CC=3 with 50% coverage is 4.125', () {
      // 3^2 * (1-0.5)^3 + 3 = 9 * 0.125 + 3 = 4.125
      expect(crapScore(3, 0.5), closeTo(4.125, 1e-9));
    });

    test('null coverage yields null score', () {
      expect(crapScore(5, null), isNull);
    });

    test('high complexity and low coverage exceeds the default threshold', () {
      // 4^2 * (1-0.25)^3 + 4 = 16 * 0.421875 + 4 = 10.75
      expect(crapScore(4, 0.25), closeTo(10.75, 1e-9));
    });
  });
}
