import 'dart:io';

import 'package:crap4dart/src/gates/file_naming_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = FileNamingGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('passes domain-meaningful file names', () async {
    final files = [
      'lib/jira/client.dart',
      'lib/invoice_parser.dart',
      'lib/base64.dart',
      'lib/oauth2.dart',
      'lib/day_one.dart',
      'lib/mode_2d.dart',
    ];
    for (final f in files) {
      writeFile(project, f, 'void f() {}\n');
    }
    final result = await gate.run(makeContext(project, files));
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
  });

  test('flags files with numeric suffixes', () async {
    final files = [
      'lib/jira_batch1.dart',
      'lib/jira_batch2.dart',
      'lib/report2.dart',
      'lib/day_1.dart',
      'lib/sync10.dart',
      'lib/configv3.dart',
    ];
    for (final f in files) {
      writeFile(project, f, 'void f() {}\n');
    }
    final result = await gate.run(makeContext(project, files));
    expect(result.passed, isFalse);
    expect(result.violations.map((v) => v.file).toList(), files);
    expect(
      result.violations.first.message,
      contains('split by domain instead of numbered parts'),
    );
  });

  test('flags generic dumping-ground names', () async {
    final files = ['lib/utils.dart', 'lib/helpers.dart', 'lib/misc.dart'];
    for (final f in files) {
      writeFile(project, f, 'void f() {}\n');
    }
    final result = await gate.run(makeContext(project, files));
    expect(result.passed, isFalse);
    expect(result.violations.map((v) => v.file).toList(), files);
    expect(
      result.violations.first.message,
      contains('split by domain instead of accumulating'),
    );
  });

  test('honors the exclude globs', () async {
    writeFile(project, 'lib/generated2.g.dart', 'void f() {}\n');
    writeFile(project, 'test/utils_test.dart', 'void f() {}\n');
    final result = await gate.run(
      makeContext(project, ['lib/generated2.g.dart', 'test/utils_test.dart']),
    );
    expect(result.passed, isTrue);
  });
}
