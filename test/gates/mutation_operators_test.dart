import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/gates/mutation_operators.dart';
import 'package:test/test.dart';

void main() {
  group('binary operator detection', () {
    List<MutationSite> detect(String source, {Set<String>? categories}) =>
        MutationSiteDetector(categories: categories)
            .detect(DartParser().parse(content: source, path: '/p/lib/a.dart'));

    test('arithmetic rows produce replacement pairs', () {
      final sites = detect('int f(int a, int b) => a + b;\n');
      expect(sites.map((s) => s.original).toList(), ['+']);
      expect(sites.single.mutant, '-');
      expect(sites.single.category, 'arithmetic');
    });

    test('division yields two mutants (/ -> * and / -> ~/)', () {
      final sites = detect('double f(int a, int b) => a / b;\n');
      expect(sites.map((s) => s.mutant).toList(), ['*', '~/']);
    });

    test('boundary rows match comparison operators', () {
      final sites = detect('bool f(int a, int b) => a > b;\n');
      expect(sites.map((s) => s.mutant).toList(), ['>=', '<']);
    });

    test('equality, logical and constant rows match together', () {
      final source = 'bool f(int a, int b) => a == b && b != 0;\n';
      final sites = detect(source);
      expect(sites.map((s) => '${s.original}->${s.mutant}').toList(), [
        '==->!=',
        '&&->||',
        '!=->==',
        '0->1',
      ]);
    });
  });
}
