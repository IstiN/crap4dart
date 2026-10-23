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
    expect(gate.exclude, contains('test/**'));
    // deep_search moved to the scattered_fragments gate.
    expect(
      () => loader.loadString('gates:\n'
          '  scattered_constants:\n'
          '    deep_search: true\n'),
      throwsA(isA<ConfigException>()),
    );
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
        '    exclude: [vendor/**]\n');
    final gate = config.gates.scatteredConstants;
    expect(gate.severity, GateSeverity.error);
    expect(gate.ignorable, isTrue);
    expect(gate.minFiles, 2);
    expect(gate.minLength, 6);
    expect(gate.minValue, 50);
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

  test('generated template round-trips the gates', () {
    final config = loader.loadString(defaultConfigTemplate);
    final gate = config.gates.scatteredConstants;
    expect(gate.enabled, isTrue);
    expect(gate.severity, GateSeverity.warning);
    expect(gate.minFiles, 3);
    expect(gate.minLength, 4);
    expect(gate.minValue, 100);
    final fragments = config.gates.scatteredFragments;
    expect(fragments.enabled, isTrue);
    expect(fragments.severity, GateSeverity.warning);
    expect(fragments.minFiles, 2);
    expect(fragments.minLength, 5);
    expect(fragments.separators, '.');
  });
}
