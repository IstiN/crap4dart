import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'enum_name_contract_fixture.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('accepts the documented keys', () {
    const yaml = '''
gates:
  enum_name_contract:
    enabled: true
    severity: warning
    ignorable: true
''';
    final config = const ConfigLoader().loadString(yaml);
    expect(config.gates.enumNameContract.enabled, isTrue);
    expect(config.gates.enumNameContract.severity, GateSeverity.warning);
    expect(config.gates.enumNameContract.ignorable, isTrue);
  });

  test('defaults to enabled warning', () {
    final config = Crap4DartConfig.defaults();
    expect(config.gates.enumNameContract.enabled, isTrue);
    expect(config.gates.enumNameContract.severity, GateSeverity.warning);
    expect(config.gates.enumNameContract.ignorable, isFalse);
  });

  test('rejects unknown keys', () {
    const yaml = '''
gates:
  enum_name_contract:
    enabled: true
    unknown_key: 1
''';
    expect(
      () => const ConfigLoader().loadString(yaml),
      throwsA(isA<ConfigException>()),
    );
  });

  test('finds violations under warning severity', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  String get label => name;
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 4);
  });
}
