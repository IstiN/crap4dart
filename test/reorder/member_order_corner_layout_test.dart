import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('CRLF files keep their line endings', () {
    const src = 'class A {\r\n  void m() {}\r\n  int x = 0;\r\n}\r\n';
    final out = reorderSource(src);
    // New lines are CRLF too: no bare LF outside a CRLF pair.
    expect(out.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(out, endsWith('}\r\n'));
    expectConsistent(src);
  });

  test('a file without a trailing newline is preserved', () {
    const src = 'class A {\n  void m() {}\n  int x = 0;\n}';
    final out = reorderSource(src);
    expect(out, endsWith('}'));
    expect(out, isNot(endsWith('}\n')));
    expectConsistent(src);
  });

  test('empty files, comment-only files and empty classes are untouched', () {
    for (final src in ['', '// only a comment\n', 'class A {}\n']) {
      expect(reorderSource(src), src, reason: 'input: "$src"');
      expectConsistent(src);
    }
  });
}
