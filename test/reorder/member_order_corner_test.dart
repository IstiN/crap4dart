import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('single-line canonical class is byte-identical', () {
    const src = 'class A { int x = 0; }\n';
    expect(reorderSource(src), src);
    expectConsistent(src);
  });

  test('single-line non-canonical class is moved and normalized', () {
    const src = 'class A { void m() {} int x = 0; }\n';
    final out = reorderSource(src);
    expect(out, 'class A { int x = 0;\n\n void m() {} }\n');
    expectConsistent(src);
  });

  test('member on the class header line keeps the header', () {
    const src = 'class A { // trailing\n  void m() {}\n  int x = 0;\n}\n';
    expect(
        reorderSource(src),
        'class A { // trailing\n'
        '  int x = 0;\n'
        '\n'
        '  void m() {}\n'
        '}\n');
    expectConsistent(src);
  });

  test('a // class doc above the opener is never stolen', () {
    const src =
        '// Doc for the class.\nclass A {\n  void m() {}\n  int x = 0;\n}\n';
    expect(
      reorderSource(src),
      '// Doc for the class.\n'
      'class A {\n'
      '  int x = 0;\n'
      '\n'
      '  void m() {}\n'
      '}\n',
    );
    expectConsistent(src);
  });

  test('a blank-blank gap detaches the comment from the member', () {
    const src = 'class A {\n  void z() {}\n\n\n  // note\n  int a = 0;\n}\n';
    final out = reorderSource(src);
    expect(out, 'class A {\n  // note\n  int a = 0;\n\n  void z() {}\n}\n');
    expectConsistent(src);
  });

  test('block doc comments are carried', () {
    const src = '''
class A {
  /**
   * Field docs.
   */
  int field = 0;

  void m() {}
}
''';
    final out = reorderSource(src);
    expect(out, contains('/**\n   * Field docs.\n   */'));
    expect(out.indexOf('Field docs'), lessThan(out.indexOf('void m() {}')));
    expectConsistent(src);
  });

  test('an orphan comment before the closing brace stays in place', () {
    const src = 'class A {\n  int x = 0;\n\n  // trailing orphan note\n}\n';
    final out = reorderSource(src);
    expect(out, src);
    expectConsistent(src);
  });

  test('a comment that looks like code is carried, not parsed', () {
    const src =
        'class A {\n  void z() {}\n\n  // void fake() {}\n  int a = 0;\n}\n';
    final out = reorderSource(src);
    expect(out, contains('// void fake() {}\n  int a = 0;'));
    expectConsistent(src);
  });
}
