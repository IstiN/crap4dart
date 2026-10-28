import 'dart:io';

import 'package:crap4dart/src/cli/memory_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('missingTestPaths', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('crap4dart_paths');
      Directory(p.join(dir.path, 'test')).createSync();
      File(p.join(dir.path, 'test', 'a_test.dart')).writeAsStringSync('');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('existing file and directory are fine', () {
      expect(
        missingTestPaths(dir.path, ['test/a_test.dart', 'test']),
        isEmpty,
      );
    });
    test('missing path is reported', () {
      expect(missingTestPaths(dir.path, ['test/nope_test.dart']),
          ['test/nope_test.dart']);
    });
    test('absolute path outside root is accepted when it exists', () {
      expect(
        missingTestPaths(dir.path, [p.join(dir.path, 'test', 'a_test.dart')]),
        isEmpty,
      );
    });
  });

  group('inferPackageRoot', () {
    late Directory ws;
    setUp(() {
      // workspace/ (no pubspec) containing pkg/ (pubspec + test/x.dart)
      ws = Directory.systemTemp.createTempSync('crap4dart_ws');
      final pkg = Directory(p.join(ws.path, 'pkg'));
      pkg.createSync(recursive: true);
      File(p.join(pkg.path, 'pubspec.yaml')).writeAsStringSync('name: pkg\n');
      Directory(p.join(pkg.path, 'test')).createSync();
      File(p.join(pkg.path, 'test', 'x_test.dart')).writeAsStringSync('');
    });
    tearDown(() => ws.deleteSync(recursive: true));

    test('walks up from the path to the nearest pubspec', () {
      expect(
        inferPackageRoot(ws.path, ['pkg/test/x_test.dart']),
        p.join(ws.path, 'pkg'),
      );
    });
  });
}
