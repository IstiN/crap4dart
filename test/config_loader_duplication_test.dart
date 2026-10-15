import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  group('duplication cpd-parity keys', () {
    const loader = ConfigLoader();
    test('cpd-parity keys parse and validate strictly', () {
      final config = loader.loadString(
        'gates:\n  duplication:\n'
        '    report: clones\n'
        '    ignore_identifiers: true\n'
        '    ignore_imports: true\n'
        '    skip_duplicate_files: true\n',
      );
      expect(config.gates.duplication.report, DuplicationReport.clones);
      expect(config.gates.duplication.matching.ignoreIdentifiers, isTrue);
      expect(config.gates.duplication.matching.ignoreImports, isTrue);
      expect(config.gates.duplication.matching.skipDuplicateFiles, isTrue);
      expect(
        loader
            .loadString('gates:\n  duplication: {}\n')
            .gates
            .duplication
            .report,
        DuplicationReport.percentage,
      );
      expect(
        () => loader.loadString(
          'gates:\n  duplication:\n    report: pmd\n',
        ),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.duplication.report',
          ),
        ),
      );
    });
  });
}
