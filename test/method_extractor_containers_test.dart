import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('MethodExtractor containers', () {
    test('extracts mixin, enum and extension members', () {
      final methods = parseMethods('''
mixin M {
  void mixinMethod() {}
}

enum E {
  a, b;
  void enumMethod() {}
}

extension on String {
  void extensionMethod() {}
}

extension NamedExt on int {
  void namedExtensionMethod() {}
}
''');
      final byName = {for (final m in methods) m.info.methodName: m.info};
      expect(byName['mixinMethod']!.className, 'M');
      expect(byName['enumMethod']!.className, 'E');
      expect(byName['extensionMethod']!.className, unnamedExtensionName);
      expect(byName['namedExtensionMethod']!.className, 'NamedExt');
    });

    test('skips nested function declarations inside method bodies', () {
      final methods = parseMethods('''
void outer() {
  void nested() {}
  final lambda = () {};
  lambda();
}
''');
      expect(methods, hasLength(1));
      expect(methods.single.info.methodName, 'outer');
    });

    test('skips bodyless external functions', () {
      final methods = parseMethods('''
class A {
  external void ext();
  void concrete() {}
}
''');
      expect(methods, hasLength(1));
      expect(methods.single.info.methodName, 'concrete');
    });
  });
}
