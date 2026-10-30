import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

void main() {
  test('moves a field above its constructor and a const to the top', () {
    const src = '''
class A {
  int value = 0;

  static const answer = 42;

  A();
}
''';
    final out = reorderSource(src);
    expect(out, '''
class A {
  static const answer = 42;

  int value = 0;

  A();
}
''');
  });

  test('carries doc comments and // notes with their member', () {
    const src = '''
class A {
  /// Public api.
  void api() {}

  // A note on the field.
  int field = 0;
}
''';
    final out = reorderSource(src);
    expect(out, '''
class A {
  // A note on the field.
  int field = 0;

  /// Public api.
  void api() {}
}
''');
  });

  test('carries annotations', () {
    const src = '''
class A {
  void current() {}

  @Deprecated('use other')
  static const legacy = 1;
}
''';
    final out = reorderSource(src);
    expect(out, '''
class A {
  @Deprecated('use other')
  static const legacy = 1;

  void current() {}
}
''');
  });
}
