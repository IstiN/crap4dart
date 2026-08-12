import 'package:crap4dart/src/profile/source_instrumenter.dart';
import 'package:test/test.dart';

void main() {
  group('SourceInstrumenter', () {
    test('wraps a simple method body', () {
      const source = '''
class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      expect(result, contains("__crap_collector.dart"));
      expect(result, contains('Stopwatch()..start()'));
      expect(result, contains('try {'));
      expect(result, contains('} finally {'));
      expect(result, contains("CrapCollector.instance.record('Foo.bar'"));
    });

    test('wraps a top-level function', () {
      const source = '''
int add(int a, int b) {
  return a + b;
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      expect(result, contains("record('(top-level).add'"));
      expect(result, contains('Stopwatch'));
    });

    test('skips expression bodies', () {
      const source = '''
int double(int x) => x * 2;
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      // No insertion for expression bodies.
      expect(result, isNot(contains('Stopwatch')));
    });

    test('skips abstract methods', () {
      const source = '''
abstract class Foo {
  void bar();
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      expect(result, isNot(contains('Stopwatch')));
    });

    test('handles multiple methods in same class', () {
      const source = '''
class Foo {
  void a() {
    print('a');
  }
  void b() {
    print('b');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      expect(result, contains("record('Foo.a'"));
      expect(result, contains("record('Foo.b'"));
    });
  });
}
