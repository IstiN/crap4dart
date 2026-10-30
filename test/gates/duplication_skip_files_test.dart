import 'dart:io';

import 'package:crap4dart/src/gates/quality/duplication_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = DuplicationGate();

  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  const clonesConfig = 'gates:\n  duplication:\n    report: clones\n';

  const file = '''
int alpha(List<int> xs) {
  var total = 0;
  for (final x in xs) {
    if (x > 0) {
      total += x * 2;
    } else {
      total -= x;
    }
  }
  return total + 42;
}

String bravo(String s) {
  final parts = s.split(':');
  if (parts.isEmpty) {
    return 'none';
  }
  return parts.reversed.join('-');
}
''';

  test('skip_duplicate_files reports a copied file once', () async {
    const file = '''
int alpha(List<int> xs) {
  var total = 0;
  for (final x in xs) {
    if (x > 0) {
      total += x * 2;
    } else {
      total -= x;
    }
  }
  return total + 42;
}

String bravo(String s) {
  final parts = s.split(':');
  if (parts.isEmpty) {
    return 'none';
  }
  return parts.reversed.join('-');
}
''';
    writeFile(project, 'lib/a.dart', file);
    writeFile(project, 'lib/b.dart', file);
    const skipConfig = 'gates:\n  duplication:\n'
        '    report: clones\n'
        '    skip_duplicate_files: true\n';
    final result = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: skipConfig),
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('without skip_duplicate_files a copied file is a clone', () async {
    writeFile(project, 'lib/a.dart', file);
    writeFile(project, 'lib/b.dart', file);
    final result = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: clonesConfig),
    );
    expect(result.passed, isFalse);
  });
}
