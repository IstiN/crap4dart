import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/gates/mutation_operators.dart';
import 'package:test/test.dart';

List<MutationSite> detect(String source, {Set<String>? categories}) =>
    MutationSiteDetector(categories: categories)
        .detect(DartParser().parse(content: source, path: '/p/lib/a.dart'));

const classSource = '''
class Calc {
  /// Doc.
  int add(int a, int b) {
    return a + b;
  }
}
''';

void main() {
  group('site metadata', () {
    test('records file, line and containing method', () {
      final sites = detect(classSource);
      expect(sites.single.file, '/p/lib/a.dart');
      expect(sites.single.line, 4);
      expect(sites.single.method, 'Calc.add');
    });

    test('top-level functions get the (top-level) container', () {
      final sites = detect('int f(int a, int b) => a * b;\n');
      expect(sites.single.method, '(top-level).f');
    });

    test('offsets are token-based: applied mutation rewrites the source', () {
      final sites = detect(classSource);
      expect(sites.single.applyTo(classSource), contains('return a - b;'));
      expect(classSource, contains('return a + b;'));
    });
  });

  group('category filtering', () {
    const source = 'bool f(int a, int b) => a > b && a == 0;\n';

    test('limits sites to the enabled categories', () {
      final sites = detect(source, categories: {'equality'});
      expect(sites.map((s) => s.category).toSet(), {'equality'});
    });

    test('empty category set yields no sites', () {
      expect(detect(source, categories: {}), isEmpty);
    });

    test('unary is detected without any binary operator', () {
      final sites = detect('bool f(bool a) => !a;\n', categories: {'unary'});
      expect(sites, hasLength(1));
    });
  });
}
