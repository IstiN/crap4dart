import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('late and final fields are ordinary fields', () {
    const src = '''
class A {
  void m() {}

  late final int lateField;
  final int readyField = 1;
}
''';
    final out = reorderSource(src);
    expect(out.indexOf('late final int lateField;'),
        lessThan(out.indexOf('void m() {}')));
    expectConsistent(src);
  });

  test('a multi-variable field declaration is one member', () {
    const src = '''
class A {
  void m() {}

  int a = 0, b = 0;
}
''';
    final out = reorderSource(src);
    expect(out, contains('int a = 0, b = 0;\n'));
    expect(out.indexOf('int a = 0'), lessThan(out.indexOf('void m()')));
    expectConsistent(src);
  });

  test('abstract members reorder like their kinds', () {
    const src = '''
abstract class Shape {
  void _privateHelper();

  int get area;

  void draw();
}
''';
    final out = reorderSource(src);
    final getter = out.indexOf('int get area');
    final draw = out.indexOf('void draw()');
    final private = out.indexOf('void _privateHelper()');
    expect(getter, lessThan(draw), reason: 'accessors before methods');
    expect(draw, lessThan(private), reason: 'private methods come last');
  });

  test('mixins and extensions are reordered too', () {
    const src = '''
mixin Greets {
  void greet() {}

  String salutation = 'hi';
}

extension IntExtras on int {
  int get doubled => this * 2;

  bool get isPositive => this > 0;
}
''';
    final out = reorderSource(src);
    expect(
        out.indexOf('String salutation'), lessThan(out.indexOf('void greet()')),
        reason: 'fields before methods');
    expect(out.indexOf('int get doubled'),
        lessThan(out.indexOf('bool get isPositive')),
        reason: 'both are accessors: original relative order kept');
    expectConsistent(src);
  });
}
