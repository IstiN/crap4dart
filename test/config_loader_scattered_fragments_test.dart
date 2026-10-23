import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  test('scattered_fragments accepts overrides', () {
    final config = loader.loadString('gates:\n'
        '  scattered_fragments:\n'
        '    enabled: true\n'
        '    severity: error\n'
        '    ignorable: true\n'
        '    min_files: 2\n'
        '    min_length: 6\n'
        "    separators: './_'\n"
        "    ignore: [vendor]\n"
        '    exclude: [test/**]\n');
    final gate = config.gates.scatteredFragments;
    expect(gate.enabled, isTrue);
    expect(gate.severity, GateSeverity.error);
    expect(gate.ignorable, isTrue);
    expect(gate.minFiles, 2);
    expect(gate.minLength, 6);
    expect(gate.separators, './_');
    expect(gate.ignore, ['vendor']);
    expect(gate.exclude, ['test/**']);
  });
  test('unknown keys are config errors', () {
    expect(
      () => loader.loadString('gates:\n'
          '  scattered_fragments:\n'
          '    nope: 1\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}
