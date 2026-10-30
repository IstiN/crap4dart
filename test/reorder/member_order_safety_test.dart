import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

void main() {
  test('enum bodies are never touched', () {
    const src = '''
enum Color {
  red,
  green,
  blue;

  void describe() {}
}
''';
    expect(reorderSource(src), src);
  });

  test('multiple classes in one file are each reordered', () {
    const src = '''
class A {
  void m() {}

  int f = 0;
}

class B {
  void m() {}

  int f = 0;
}
''';
    final out = reorderSource(src);
    expect(out.indexOf('int f = 0;'), lessThan(out.indexOf('void m() {}')));
    expect(out.lastIndexOf('int f = 0;'),
        lessThan(out.lastIndexOf('void m() {}')));
  });

  test('is idempotent: reorder(reorder(x)) == reorder(x)', () {
    const src = '''
class A {
  /// Later.
  void later() {}

  static const first = 1;

  void _last() {}

  int middle = 2;
}
''';
    final once = reorderSource(src);
    expect(reorderSource(once), once);
  });

  test('is a pure function: same input, same output', () {
    const src = '''
class A {
  void b() {}

  int a = 0;
}
''';
    // Idempotence contract: two runs of the same input must agree.
    // ignore:identical_branches
    expect(reorderSource(src), reorderSource(src));
  });
}
