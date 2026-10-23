import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  test('record gates are known ids with warning defaults', () {
    final config = loader.loadString('''
gates:
  record_named_fields:
    enabled: true
  inline_record_types:
    enabled: true
  record_size:
    enabled: true
''');
    expect(config.gates.recordNamedFields.enabled, isTrue);
    expect(config.gates.recordNamedFields.severity, GateSeverity.warning);
    expect(config.gates.inlineRecordTypes.enabled, isTrue);
    expect(config.gates.inlineRecordTypes.severity, GateSeverity.warning);
    expect(config.gates.recordSize.enabled, isTrue);
    expect(config.gates.recordSize.severity, GateSeverity.warning);
    expect(config.gates.recordSize.maxFields, 5);
  });

  test('record_size accepts max_fields and severity overrides', () {
    final config = loader.loadString('''
gates:
  record_size:
    enabled: true
    severity: error
    ignorable: true
    max_fields: 3
''');
    expect(config.gates.recordSize.maxFields, 3);
    expect(config.gates.recordSize.severity, GateSeverity.error);
    expect(config.gates.recordSize.ignorable, isTrue);
  });

  test('unknown keys under the record gates are errors', () {
    for (final gate in ['record_named_fields', 'inline_record_types']) {
      expect(
        () => loader.loadString('gates:\n  $gate:\n    nope: 1\n'),
        throwsA(isA<ConfigException>()),
        reason: gate,
      );
    }
    expect(
      () => loader.loadString('gates:\n  record_size:\n    nope: 1\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('max_fields must be an integer', () {
    expect(
      () =>
          loader.loadString('gates:\n  record_size:\n    max_fields: three\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('generated template round-trips the three gates', () {
    final config = loader.loadString(defaultConfigTemplate);
    expect(config.gates.recordNamedFields.enabled, isTrue);
    expect(config.gates.recordNamedFields.severity, GateSeverity.warning);
    expect(config.gates.inlineRecordTypes.enabled, isTrue);
    expect(config.gates.inlineRecordTypes.severity, GateSeverity.warning);
    expect(config.gates.recordSize.enabled, isTrue);
    expect(config.gates.recordSize.severity, GateSeverity.warning);
    expect(config.gates.recordSize.maxFields, 5);
  });
}
