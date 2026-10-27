import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  Directory workDir() {
    final dir = Directory.systemTemp.createTempSync('reorder_cli');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

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

  test('writes reordered files and exits 0', () async {
    final dir = workDir();
    File('${dir.path}/lib/a.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(messy);
    final result = await runCliInProcess(dir, ['reorder']);
    expect(result.exitCode, 0, reason: result.stdout);
    expect(File('${dir.path}/lib/a.dart').readAsStringSync(), canonical);
    expect(result.stdout, contains('reordered lib/a.dart'));
  });

  test('dry-run reports and exits 2 without writing', () async {
    final dir = workDir();
    File('${dir.path}/lib/a.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(messy);
    final result = await runCliInProcess(dir, ['reorder', '--dry-run']);
    expect(result.exitCode, 2, reason: result.stdout);
    expect(File('${dir.path}/lib/a.dart').readAsStringSync(), messy);
    expect(result.stdout, contains('would reorder lib/a.dart'));
  });

  test('canonical files exit 0 in both modes', () async {
    final dir = workDir();
    File('${dir.path}/lib/a.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(canonical);
    final write = await runCliInProcess(dir, ['reorder']);
    final dry = await runCliInProcess(dir, ['reorder', '--dry-run']);
    expect(write.exitCode, 0);
    expect(dry.exitCode, 0);
    expect(write.stdout, contains('already canonical'));
  });
}
