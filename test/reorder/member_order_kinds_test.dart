import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('operators count as methods (field before operator)', () {
    const src = '''
class Money {
  Money operator +(Money other) => Money();

  int cents = 0;
}
''';
    final out = reorderSource(src);
    expect(out.indexOf('int cents'), lessThan(out.indexOf('operator +')));
    expectConsistent(src);
  });

  test('constructors keep their relative order as one group', () {
    const src = '''
class Point {
  Point.origin() : x = 0, y = 0;

  Point(this.x, this.y);

  factory Point.zero() => Point.origin();

  int x = 0;
  int y = 0;
}
''';
    final out = reorderSource(src);
    final origin = out.indexOf('Point.origin() :');
    final generative = out.indexOf('Point(this.x, this.y)');
    final zero = out.indexOf('factory Point.zero()');
    final fields = out.indexOf('int x = 0;');
    expect(fields, lessThan(origin), reason: 'fields before constructors');
    expect(origin, lessThan(generative),
        reason: 'same category: original relative order kept');
    expect(generative, lessThan(zero),
        reason: 'same category: original relative order kept');
  });

  test('getter and setter land in the accessor group', () {
    const src = '''
class Box {
  void open() {}

  int _size = 0;

  int get size => _size;

  set size(int value) => _size = value;
}
''';
    final out = reorderSource(src);
    final getter = out.indexOf('int get size');
    final setter = out.indexOf('set size');
    final open = out.indexOf('void open() {}');
    final field = out.indexOf('int _size = 0;');
    expect(field, lessThan(getter), reason: 'fields before accessors');
    expect(getter, lessThan(setter),
        reason: 'same category: original relative order kept');
    expect(setter, lessThan(open), reason: 'accessors before methods');
  });
}
