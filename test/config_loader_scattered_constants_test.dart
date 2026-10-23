import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  test('scattered_constants defaults: on, warning, 3/4/100', () {
    final config = loader.loadString('gates:\n'
        '  scattered_constants:\n'
        '    enabled: true\n');
    final gate = config.gates.scatteredConstants;
    expect(gate.enabled, isTrue);
    expect(gate.severity, GateSeverity.warning);
    expect(gate.ignorable, isFalse);
    expect(gate.minFiles, 3);
    expect(gate.minLength, 4);
    expect(gate.minValue, 100);
    expect(gate.deepSearch, isFalse);
    expect(gate.prefixMinFiles, 2);
    expect(gate.exclude, contains('test/**'));
  });

  test('scattered_constants accepts overrides', () {
    final config = loader.loadString('gates:\n'
        '  scattered_constants:\n'
        '    enabled: true\n'
        '    severity: error\n'
        '    ignorable: true\n'
        '    min_files: 2\n'
        '    min_length: 6\n'
        '    min_value: 50\n'
        '    deep_search: true\n'
        '    prefix_min_files: 3\n'
        '    exclude: [vendor/**]\n');
    final gate = config.gates.scatteredConstants;
    expect(gate.severity, GateSeverity.error);
    expect(gate.ignorable, isTrue);
    expect(gate.minFiles, 2);
    expect(gate.minLength, 6);
    expect(gate.minValue, 50);
    expect(gate.deepSearch, isTrue);
    expect(gate.prefixMinFiles, 3);
    expect(gate.exclude, ['vendor/**']);
  });

  test('unknown keys are config errors', () {
    expect(
      () => loader.loadString('gates:\n  scattered_constants:\n    nope: 1\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('numeric knobs must be integers', () {
    for (final key in ['min_files', 'min_length', 'min_value']) {
      expect(
        () => loader
            .loadString('gates:\n  scattered_constants:\n    $key: many\n'),
        throwsA(isA<ConfigException>()),
        reason: key,
      );
    }
  });

  test('generated template round-trips the gate', () {
    final config = loader.loadString(defaultConfigTemplate);
    final gate = config.gates.scatteredConstants;
    expect(gate.enabled, isTrue);
    expect(gate.severity, GateSeverity.warning);
    expect(gate.minFiles, 3);
    expect(gate.minLength, 4);
    expect(gate.minValue, 100);
  });
}
