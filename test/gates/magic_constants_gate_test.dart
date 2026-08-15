import 'dart:io';

import 'package:crap4dart/src/gates/magic_constants_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = MagicConstantsGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('flags hardcoded hex colors outside constants', () async {
    writeFile(project, 'lib/colors.dart', '''
import 'package:flutter/material.dart';

Widget build() {
  return Container(color: const Color(0xFFFF5733));
}
''');
    final result = await gate.run(makeContext(project, ['lib/colors.dart']));
    expect(result.passed, isFalse);
    expect(result.violations.single.message,
        contains('hex color outside a constant'));
    expect(result.violations.single.line, 4);
  });

  test('allows hex colors inside const declarations', () async {
    writeFile(project, 'lib/theme.dart', '''
const int brandColor = 0xFF00AAFF;
const brand = Color(0xFFFF5733);
''');
    final result = await gate.run(makeContext(project, ['lib/theme.dart']));
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('flags literals repeated min_duplicates times', () async {
    writeFile(project, 'lib/repeat.dart', '''
void a() => print('loading-failed');
void b() => print('loading-failed');
void c() => print('loading-failed');
void d() => print('other message');
''');
    final result = await gate.run(makeContext(project, ['lib/repeat.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.every(
        (v) => v.message.contains('repeats 3 times'),
      ),
      isTrue,
    );
  });

  test('short literals and doubles below threshold pass', () async {
    writeFile(project, 'lib/ok.dart', '''
void a() => print('ok');
void b() => print('ok');
final x = 3.14;
''');
    final result = await gate.run(makeContext(project, ['lib/ok.dart']));
    expect(result.passed, isTrue, reason: '${result.violations}');
  });

  test('map-key strings are not flagged as constants', () async {
    writeFile(project, 'lib/keys.dart', '''
final a = {'blur': 1};
final b = {'blur': 2};
final c = {'blur': 3};
''');
    final result = await gate.run(makeContext(project, ['lib/keys.dart']));
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
