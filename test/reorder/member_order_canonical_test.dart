import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

void main() {
  test('is returned byte-identical', () {
    const src = '''
class A {
  static const one = 1;

  static int two = 2;

  int three = 3;

  A();

  static void four() {}

  int get five => 5;

  void six() {}

  void _seven() {}
}
''';
    expect(reorderSource(src), src);
  });

  test('members of one category keep their relative order', () {
    const src = '''
class A {
  void first() {}

  void second() {}

  void third() {}
}
''';
    expect(reorderSource(src), src);
  });
}
