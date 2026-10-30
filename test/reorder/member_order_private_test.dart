import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

void main() {
  test('private methods move after public ones', () {
    const src = '''
class A {
  void _hidden() {}

  void visible() {}
}
''';
    expect(reorderSource(src), '''
class A {
  void visible() {}

  void _hidden() {}
}
''');
  });

  test('a marker comment between members moves with the follower', () {
    const src = '''
class A {
  void z() {}

  // belongs to a
  int a = 0;
}
''';
    expect(reorderSource(src), '''
class A {
  // belongs to a
  int a = 0;

  void z() {}
}
''');
  });
}
