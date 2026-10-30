import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags identical catch bodies in one try', () async {
    final result = await runOn('''
void f() {
  try {
    run();
  } on FormatException {
    log('bad');
  } on ArgumentError {
    log('bad');
  }
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.message, contains('duplicate catch body'));
  });

  test('different catch bodies are legal', () async {
    final result = await runOn('''
void f() {
  try {
    run();
  } on FormatException {
    log('format');
  } on ArgumentError {
    log('argument');
  }
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('a catch body equal to an on-clause body is flagged', () async {
    final result = await runOn('''
void f() {
  try {
    run();
  } on FormatException {
    log('bad');
  } catch (e) {
    log('bad');
  }
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });
}
