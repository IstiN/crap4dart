import 'dart:io';

import 'package:crap4dart/src/gates/broken_goldens_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'tofu_fixtures.dart';

void main() {
  const gate = BrokenGoldensGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('flags a tofu icon (bordered box with an X)', () async {
    writeTofuGolden(project, 'test/goldens/tofu.png');
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse, reason: '${result.violations}');
    expect(result.violations.single.message, contains('icon placeholder'));
  });

  test('digits with outlines are NOT tofu', () async {
    writeOutlinedDigitGolden(project, 'test/goldens/zero.png');
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue,
        reason: 'an outlined digit must not be flagged: '
            '${result.violations}');
  });
}
