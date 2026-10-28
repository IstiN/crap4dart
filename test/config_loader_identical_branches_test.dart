import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('identical_branches config', () {
    test('defaults: enabled, warning severity', () {
      final config = loader.loadString('sources: [lib]\n');
      expect(config.gates.identicalBranches.enabled, isTrue);
      expect(config.gates.identicalBranches.severity, GateSeverity.warning);
      expect(config.gates.identicalBranches.ignorable, isFalse);
    });

    test('known gate id with explicit values loads', () {
      final config = loader.loadString('''
gates:
  identical_branches:
    enabled: true
    severity: error
    ignorable: true
''');
      expect(config.gates.identicalBranches.enabled, isTrue);
      expect(config.gates.identicalBranches.severity, GateSeverity.error);
      expect(config.gates.identicalBranches.ignorable, isTrue);
    });

    test('disabled explicitly', () {
      final config = loader.loadString('''
gates:
  identical_branches:
    enabled: false
''');
      expect(config.gates.identicalBranches.enabled, isFalse);
    });

    test('unknown key inside the gate is a config error', () {
      expect(
        () => loader.loadString('''
gates:
  identical_branches:
    max_something: 3
'''),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.identical_branches.max_something',
          ),
        ),
      );
    });

    test('invalid severity is a config error', () {
      expect(
        () => loader.loadString('''
gates:
  identical_branches:
    severity: fatal
'''),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.identical_branches.severity',
          ),
        ),
      );
    });

    test('generated template round-trips the gate', () {
      final config = loader.loadString(defaultConfigTemplate);
      expect(config.gates.identicalBranches.enabled, isTrue);
      expect(config.gates.identicalBranches.severity, GateSeverity.warning);
    });
  });
}
