import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

const messy = '''
class A {
  void m() {}

  static const top = 1;
}
''';
const canonical = '''
class A {
  static const top = 1;

  void m() {}
}
''';

Directory workDir() {
  final dir = Directory.systemTemp.createTempSync('reorder_cli');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('parse errors are skipped, not fatal', () async {
    final dir = workDir();
    File('${dir.path}/lib/a.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class Broken { void m() {}');
    File('${dir.path}/lib/b.dart').writeAsStringSync(messy);
    final result = await runCliInProcess(dir, ['reorder']);
    expect(result.exitCode, 0, reason: result.stdout);
    expect(result.stdout, contains('skipped (parse error)'));
    expect(File('${dir.path}/lib/b.dart').readAsStringSync(), canonical);
  });

  test('explicit path targets only that subtree', () async {
    final dir = workDir();
    File('${dir.path}/lib/a.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(messy);
    File('${dir.path}/test/b.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(messy);
    final result = await runCliInProcess(dir, ['reorder', 'test']);
    expect(result.exitCode, 0, reason: result.stdout);
    expect(File('${dir.path}/test/b.dart').readAsStringSync(), canonical);
    expect(File('${dir.path}/lib/a.dart').readAsStringSync(), messy);
  });
}
