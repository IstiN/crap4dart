import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  test('non_null_assertion accepts enabled, severity and ignorable', () {
    const yaml = '''
gates:
  non_null_assertion:
    enabled: true
    severity: error
    ignorable: true
''';
    final config = const ConfigLoader().loadString(yaml);
    expect(config.gates.quality.nonNullAssertion.enabled, isTrue);
    expect(config.gates.quality.nonNullAssertion.severity, GateSeverity.error);
    expect(config.gates.quality.nonNullAssertion.ignorable, isTrue);
  });

  test('non_null_assertion rejects unknown keys (strict loading)', () {
    const yaml = '''
gates:
  non_null_assertion:
    enabled: true
    unknown_key: 1
''';
    expect(
      () => const ConfigLoader().loadString(yaml),
      throwsA(
        predicate<Exception>(
          (e) => e.toString().contains('unknown_key'),
        ),
      ),
    );
  });

  test('non_null_assertion defaults: enabled, warning, not ignorable', () {
    final config = Crap4DartConfig.defaults();
    expect(config.gates.quality.nonNullAssertion.enabled, isTrue);
    expect(
      config.gates.quality.nonNullAssertion.severity,
      GateSeverity.warning,
    );
    expect(config.gates.quality.nonNullAssertion.ignorable, isFalse);
  });
}
