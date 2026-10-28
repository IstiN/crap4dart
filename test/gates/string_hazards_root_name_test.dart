import 'dart:io';

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

  test('prefixed and chained interpolations expose their root', () async {
    final result = await runOn(project, r'''
void f(user, doc) {
  print('\${user.name} escaped');
  print('${user.name} real');
  print('\${a.b.c} escaped');
  print('${a.b.c} real');
}
''');
    expect(result.violations, hasLength(2));
  });

  test('method-call interpolations expose their receiver', () async {
    final result = await runOn(project, r'''
void f(builder) {
  print('\${builder.build()} escaped');
  print('${builder.build()} real');
}
''');
    expect(result.violations, hasLength(1));
  });

  test('calls and index expressions provide no sibling name', () async {
    final message = await singleViolation(project, r'''
void g() {}
void f(List<String> list) {
  print('\${g()} escaped');
  print('\${g()} real');
  print('\${list[0]} escaped');
  print('\${list[0]} real');
}
''');
    expect(message, isNull);
  });
}
