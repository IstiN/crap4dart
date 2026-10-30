import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('collapsible_flow accepts enabled, severity and ignorable', () {
    const yaml = '''
gates:
  collapsible_flow:
    enabled: true
    severity: error
    ignorable: true
''';
    final config = const ConfigLoader().loadString(yaml);
    expect(config.gates.quality.collapsibleFlow.enabled, isTrue);
    expect(config.gates.quality.collapsibleFlow.severity, GateSeverity.error);
    expect(config.gates.quality.collapsibleFlow.ignorable, isTrue);
  });

  test('collapsible_flow rejects unknown keys (strict loading)', () {
    const yaml = '''
gates:
  collapsible_flow:
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

  test('collapsible_flow defaults: enabled, warning, not ignorable', () {
    final config = Crap4DartConfig.defaults();
    expect(config.gates.quality.collapsibleFlow.enabled, isTrue);
    expect(config.gates.quality.collapsibleFlow.severity, GateSeverity.warning);
    expect(config.gates.quality.collapsibleFlow.ignorable, isFalse);
  });
}
