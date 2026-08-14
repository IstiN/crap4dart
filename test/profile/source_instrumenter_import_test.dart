import 'package:crap4dart/src/profile/source_instrumenter.dart';
import 'package:test/test.dart';

void main() {
  group('SourceInstrumenter import insertion', () {
    test('inserts import after library directive', () {
      const source = '''
library;

class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      // The import must come AFTER the library directive.
      expect(result.indexOf('library;'),
          lessThan(result.indexOf('__crap_collector')));
    });

    test('inserts import after named library directive', () {
      const source = '''
library myapp.core;

class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      expect(
        result.indexOf('library myapp.core;'),
        lessThan(result.indexOf('__crap_collector')),
      );
    });

    test('skips part-of files entirely (parts cannot contain imports)', () {
      const source = '''
part of 'myapp.dart';

class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      // Parts cannot contain imports; instrumenting them would produce
      // uncompilable code, so the source must be returned unchanged.
      expect(result, source);
    });
  });
}
