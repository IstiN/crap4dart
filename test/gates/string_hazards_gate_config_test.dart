import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'string_hazards_fixture.dart';

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
  string_hazards:
    enabled: true
    severity: warning
    ignorable: true
''';
    final config = const ConfigLoader().loadString(yaml);
    expect(config.gates.quality.stringHazards.enabled, isTrue);
    expect(config.gates.quality.stringHazards.severity, GateSeverity.warning);
    expect(config.gates.quality.stringHazards.ignorable, isTrue);
  });

  test('defaults to enabled warning', () {
    final config = Crap4DartConfig.defaults();
    expect(config.gates.quality.stringHazards.enabled, isTrue);
    expect(config.gates.quality.stringHazards.severity, GateSeverity.warning);
    expect(config.gates.quality.stringHazards.ignorable, isFalse);
  });

  test('rejects unknown keys', () {
    const yaml = '''
gates:
  string_hazards:
    enabled: true
    unknown_key: 1
''';
    expect(
      () => const ConfigLoader().loadString(yaml),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects unknown gate sections', () {
    const yaml = 'gates:\n  no_such_gate:\n    enabled: true\n';
    expect(
      () => const ConfigLoader().loadString(yaml),
      throwsA(isA<ConfigException>()),
    );
  });

  test('finds violations under warning severity', () async {
    final result = await runOn(
      project,
      "final x = s.split('^');\n",
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 1);
  });

  test('passes on clean files', () async {
    final result = await runOn(project, r'''
final re = RegExp(r'^[a-z]+$');
final s = 'plain string';
final t = 'interpolated $s value';
final u = s.replaceFirst('a', 'b');
''');
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
