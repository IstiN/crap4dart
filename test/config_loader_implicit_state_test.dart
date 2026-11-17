import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('implicit_state config', () {
    test('defaults: enabled, warning, 3 flags, 2 mutators', () {
      final config = loader.loadString('sources: [lib]\n');
      final gate = config.gates.quality.implicitState;
      expect(gate.enabled, isTrue);
      expect(gate.severity, GateSeverity.warning);
      expect(gate.ignorable, isFalse);
      expect(gate.minFlags, 3);
      expect(gate.minMutators, 2);
    });

    test('explicit values load', () {
      final config = loader.loadString('''
sources: [lib]
gates:
  implicit_state:
    enabled: true
    severity: error
    ignorable: true
    min_flags: 4
    min_mutators: 3
''');
      final gate = config.gates.quality.implicitState;
      expect(gate.severity, GateSeverity.error);
      expect(gate.ignorable, isTrue);
      expect(gate.minFlags, 4);
      expect(gate.minMutators, 3);
    });

    test('unknown key is rejected', () {
      expect(
        () => loader.loadString('''
sources: [lib]
gates:
  implicit_state:
    min_flagz: 3
'''),
        throwsA(isA<ConfigException>()),
      );
    });

    test('non-integer threshold is rejected', () {
      expect(
        () => loader.loadString('''
sources: [lib]
gates:
  implicit_state:
    min_flags: three
'''),
        throwsA(isA<ConfigException>()),
      );
    });

    test('default template parses and carries the gate', () {
      final config = loader.loadString(defaultConfigTemplate);
      expect(config.gates.quality.implicitState.enabled, isTrue);
      expect(config.gates.quality.implicitState.severity, GateSeverity.warning);
      expect(config.gates.quality.implicitState.minFlags, 3);
      expect(config.gates.quality.implicitState.minMutators, 2);
    });
  });
}
