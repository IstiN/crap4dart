import 'package:crap4dart/src/profile/source_instrumenter.dart';
import 'package:test/test.dart';

void main() {
  group('SourceInstrumenter import ordering', () {
    test('inserts import after library before existing imports', () {
      const source = '''
library myapp.core;

import 'dart:async';

class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      final libIdx = result.indexOf('library myapp.core;');
      final collectorIdx = result.indexOf('__crap_collector');
      final existingImportIdx = result.indexOf("import 'dart:async';");

      expect(libIdx, lessThan(collectorIdx));
      expect(collectorIdx, lessThan(existingImportIdx));
    });

    test('no library directive keeps import at top', () {
      const source = '''
import 'dart:async';

class Foo {
  void bar() {
    print('hello');
  }
}
''';
      const instrumenter = SourceInstrumenter(packageName: 'myapp');
      final result = instrumenter.instrument(source);

      // Without a library directive, collector import still goes first.
      expect(result.indexOf('__crap_collector'),
          lessThan(result.indexOf("import 'dart:async';")));
    });
  });
}
