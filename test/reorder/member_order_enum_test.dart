import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('reorders enum members into the canonical order', () {
    const src = '''
enum Color {
  red, green;

  static const fallback = Color.red;

  Color();

  final String label;

  static Color? tryParse(String value) => null;

  String get upper => label.toUpperCase();

  bool get _internal => false;
}
''';
    final out = reorderSource(src);
    expect(out, '''
enum Color {
  red, green;

  static const fallback = Color.red;

  final String label;

  Color();

  static Color? tryParse(String value) => null;

  String get upper => label.toUpperCase();

  bool get _internal => false;
}
''');
    expectConsistent(src);
  });

  test('a comment above an enum member moves with it', () {
    const src = '''
enum Color {
  red, green;

  Color();

  /// The display label.
  final String label;
}
''';
    final out = reorderSource(src);
    expect(out, '''
enum Color {
  red, green;

  /// The display label.
  final String label;

  Color();
}
''');
    expectConsistent(src);
  });
}
