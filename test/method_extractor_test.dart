import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('MethodExtractor basics', () {
    test('extracts class methods with container name and lines', () {
      final methods = parseMethods('''
class Foo {
  void bar() {
    print('bar');
  }

  int baz() => 42;
}
''');
      expect(methods, hasLength(2));
      expect(methods[0].info.className, 'Foo');
      expect(methods[0].info.methodName, 'bar');
      expect(methods[0].info.startLine, 2);
      expect(methods[0].info.endLine, 4);
      expect(methods[1].info.methodName, 'baz');
      expect(methods[1].info.startLine, 6);
      expect(methods[1].info.endLine, 6);
      expect(methods[0].info.filePath, 'test.dart');
    });

    test('extracts top-level functions', () {
      final methods = parseMethods('''
void topLevel() {}

int another() => 1;
''');
      expect(methods, hasLength(2));
      expect(methods[0].info.className, topLevelClassName);
      expect(methods[0].info.methodName, 'topLevel');
    });

    test('skips constructors and abstract methods', () {
      final methods = parseMethods('''
abstract class Base {
  Base();
  Base.named();
  void abstractMethod();
  void concrete() {}
}
''');
      expect(methods, hasLength(1));
      expect(methods.single.info.methodName, 'concrete');
    });
  });
}
