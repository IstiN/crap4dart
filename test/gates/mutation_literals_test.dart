import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/gates/mutation/mutation_operators.dart';
import 'package:test/test.dart';

void main() {
  group('literal and unary detection', () {
    List<MutationSite> detect(String source) => MutationSiteDetector()
        .detect(DartParser().parse(content: source, path: '/p/lib/a.dart'));

    test('boolean literals flip', () {
      final sites = detect('bool f() => true;\nbool g() => false;\n');
      expect(sites.map((s) => '${s.original}->${s.mutant}').toList(), [
        'true->false',
        'false->true',
      ]);
      expect(sites.every((s) => s.category == 'boolean'), isTrue);
    });

    test('integer literals 0 and 1 flip, other ints are ignored', () {
      final sites = detect('int f() => 0;\nint g() => 1;\nint h() => 2;\n');
      expect(sites.map((s) => '${s.original}->${s.mutant}').toList(), [
        '0->1',
        '1->0',
      ]);
    });

    test('negative one becomes zero across the whole span', () {
      final source = 'int f() => -1;\n';
      final sites = detect(source);
      final site = sites.firstWhere((s) => s.original == '-1');
      expect(site.category, 'constant');
      expect(site.applyTo(source), 'int f() => 0;\n');
    });

    test('bang prefix deletion keeps the operand', () {
      final source = 'bool f(bool a) => !a;\n';
      final sites = detect(source);
      expect(sites.single.category, 'unary');
      expect(sites.single.mutant, isEmpty);
      expect(sites.single.applyTo(source), 'bool f(bool a) => a;\n');
    });
  });
}
