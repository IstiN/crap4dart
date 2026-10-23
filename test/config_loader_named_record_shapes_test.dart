import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('named_record_shapes config', () {
    test('defaults: enabled, warning severity', () {
      final config = loader.loadString('sources: [lib]\n');
      expect(config.gates.namedRecordShapes.enabled, isTrue);
      expect(config.gates.namedRecordShapes.severity, GateSeverity.warning);
      expect(config.gates.namedRecordShapes.ignorable, isFalse);
    });

    test('known gate id with explicit values loads', () {
      final config = loader.loadString('''
gates:
  named_record_shapes:
    enabled: true
    severity: error
    ignorable: true
''');
      expect(config.gates.namedRecordShapes.enabled, isTrue);
      expect(config.gates.namedRecordShapes.severity, GateSeverity.error);
      expect(config.gates.namedRecordShapes.ignorable, isTrue);
    });

    test('disabled explicitly', () {
      final config = loader.loadString('''
gates:
  named_record_shapes:
    enabled: false
''');
      expect(config.gates.namedRecordShapes.enabled, isFalse);
    });

    test('unknown key inside the gate is a config error', () {
      expect(
        () => loader.loadString('''
gates:
  named_record_shapes:
    check_types: false
'''),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.named_record_shapes.check_types',
          ),
        ),
      );
    });

    test('invalid severity is a config error', () {
      expect(
        () => loader.loadString('''
gates:
  named_record_shapes:
    severity: fatal
'''),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.named_record_shapes.severity',
          ),
        ),
      );
    });

    test('generated template round-trips the gate', () {
      final config = loader.loadString(defaultConfigTemplate);
      expect(config.gates.namedRecordShapes.enabled, isTrue);
      expect(config.gates.namedRecordShapes.severity, GateSeverity.warning);
    });
  });
}
