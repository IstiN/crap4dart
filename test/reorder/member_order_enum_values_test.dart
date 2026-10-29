import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

/// The constant names of the first enum in [code], in source order —
/// the enum value order the transform must never change.
List<String> constantOrder(String code) {
  final unit = DartParser().parse(content: code, path: 'a.dart').unit;
  final declaration = unit.childEntities.whereType<EnumDeclaration>().first;
  return [
    for (final constant in declaration.body.constants) constant.name.lexeme,
  ];
}

void main() {
  test('enum value order is preserved exactly (index safety)', () {
    const src = '''
enum Priority {
  low, high, critical;

  final int weight;

  const Priority(this.weight);

  static Priority fromWeight(int w) =>
      values.firstWhere((p) => p.weight == w);
}
''';
    final out = reorderSource(src);
    expect(constantOrder(src), ['low', 'high', 'critical']);
    expect(constantOrder(out), ['low', 'high', 'critical']);
    // The constants block is byte-identical, including spacing.
    expect(
      out.contains('low, high, critical;'),
      isTrue,
      reason: 'constants section must be copied verbatim',
    );
    expectConsistent(src);
  });

  test('.index and values usage keep their semantics after reorder', () {
    const src = '''
enum Phase {
  build, test, deploy;

  const Phase();

  bool get isFirst => index == 0;

  static Phase last() => values[values.length - 1];
}
''';
    final out = reorderSource(src);
    // `index == 0` must still mean build: the constants block (and the
    // whole method body) is copied verbatim — only member placement
    // changes.
    expect(out.contains('index == 0'), isTrue);
    expect(out.contains('values[values.length - 1]'), isTrue);
    expect(constantOrder(out), constantOrder(src));
    expectConsistent(src);
  });
}
