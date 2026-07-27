@Timeout.factor(2)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  group('crap4dart global exclude', () {
    test('excluded files are skipped in check', () async {
      writeCleanProject(tempDir);
      Directory(p.join(tempDir.path, 'lib', 'gen')).createSync();
      File(p.join(tempDir.path, 'lib', 'gen', 'bad.dart'))
          .writeAsStringSync('void undocumented() {}\n');
      // Without the exclude, public_docs would fail on gen/bad.dart.
      final withoutExclude = await runCli(tempDir, ['check']);
      expect(withoutExclude.exitCode, 2);

      File(p.join(tempDir.path, 'crap4dart.yaml')).writeAsStringSync('''
coverage:
  required: false
exclude:
  - 'lib/gen/**'
''');
      final result = await runCli(tempDir, ['check']);
      expect(result.exitCode, 0);
      expect(result.stdout, isNot(contains('gen/bad.dart')));
    });

    test('excluded files are skipped in analyze', () async {
      writeMiniProject(tempDir, lcov: fullCoverageLcov);
      Directory(p.join(tempDir.path, 'lib', 'gen')).createSync();
      File(p.join(tempDir.path, 'lib', 'gen', 'extra.dart'))
          .writeAsStringSync('int extra() => 1;\n');
      File(p.join(tempDir.path, 'crap4dart.yaml')).writeAsStringSync('''
exclude:
  - 'lib/gen/**'
''');
      final result = await runCli(tempDir, ['analyze']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('risky'));
      expect(result.stdout, isNot(contains('extra')));
    });
  });
}
