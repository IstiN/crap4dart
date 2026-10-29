import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

void main() {
  test('canonical enum members are left byte-identical', () {
    const src = '''
enum Color {
  red, green;

  static const fallback = Color.red;

  final String label;

  const Color(this.label);
}
''';
    expect(reorderSource(src), src);
  });

  test('enums without a member section are left byte-identical', () {
    const src = 'enum Color { red, green }\n';
    expect(reorderSource(src), src);
    const semi = 'enum Color { red, green; }\n';
    expect(reorderSource(semi), semi);
  });
}
