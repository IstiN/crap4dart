import 'package:test/test.dart';

import 'test_utils.dart';

const String _factoryWithBody = '''
class Money {
  factory Money.parse(String raw) {
    if (raw.isEmpty) throw const FormatException('empty amount');
    return Money._();
  }

  Money._();
}
''';

void main() {
  group('MethodExtractor constructors', () {
    test('constructors are skipped by default', () {
      expect(parseMethods(_factoryWithBody), isEmpty);
    });

    test('countConstructors extracts factory constructors', () {
      final methods = parseMethods(
        _factoryWithBody,
        countConstructors: true,
      );
      expect(methods, hasLength(1));
      expect(methods.single.info.className, 'Money');
      expect(methods.single.info.methodName, 'parse');
      expect(methods.single.info.startLine, 2);
    });

    test('unnamed constructors are reported as new', () {
      final methods = parseMethods('''
class Foo {
  Foo(int a) {
    if (a < 0) throw ArgumentError('a');
  }
}
''', countConstructors: true);
      expect(methods, hasLength(1));
      expect(methods.single.info.methodName, 'new');
    });

    test('redirecting factories have no body and are skipped', () {
      expect(
        parseMethods('''
class Foo {
  factory Foo(int a) = _Foo;
}

class _Foo implements Foo {}
''', countConstructors: true),
        isEmpty,
      );
    });

    test('bodyless constructors are skipped', () {
      expect(
        parseMethods('''
class Foo {
  Foo(this.a);

  final int a;
}
''', countConstructors: true),
        isEmpty,
      );
    });

    test('complexity is computed from the constructor body', () {
      expect(
        complexityOf('''
class Foo {
  factory Foo.validate(int a, String? b) {
    if (a < 0) throw ArgumentError('a');
    if (b == null || b.isEmpty) throw ArgumentError('b');
    return Foo._();
  }

  Foo._();
}
''', countConstructors: true),
        4,
      );
    });
  });
}
