import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/memory/flutter_memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  group('cli positional paths (flutter engine, fake tool)', () {
    late Directory pkg;
    late Directory fakeBin;
    setUp(() {
      pkg = Directory.systemTemp.createTempSync('crap4dart_fmem');
      File(p.join(pkg.path, 'pubspec.yaml')).writeAsStringSync(
        'name: fake_flutter_pkg\n'
        'environment:\n'
        '  sdk: ^3.0.0\n'
        'dependencies:\n'
        '  flutter:\n'
        '    sdk: flutter\n',
      );
      Directory(p.join(pkg.path, 'test')).createSync();
      File(p.join(pkg.path, 'test', 'mini_test.dart')).writeAsStringSync('');
      final fixtureDir = p.absolute('test/memory/fixtures');
      fakeBin = Directory.systemTemp.createTempSync('crap4dart_fakebin');
      final script = File(p.join(fakeBin.path, 'flutter'));
      script.writeAsStringSync(
        '#!/bin/sh\n'
        'exec dart ${p.join(fixtureDir, 'fake_flutter_tool.dart')} "\$@"\n',
      );
      Process.runSync('chmod', ['+x', script.path]);
    });
    tearDown(() {
      pkg.deleteSync(recursive: true);
      fakeBin.deleteSync(recursive: true);
      flutterBinaryResolver = defaultFlutterBinaryResolver;
    });

    test('measures only the given test file', () async {
      flutterBinaryResolver = () => p.join(fakeBin.path, 'flutter');
      final result = await runCliInProcess(
        pkg,
        ['memory', 'test/mini_test.dart', '--format', 'json'],
      );
      expect(result.exitCode, 0, reason: result.stderr);
      final report = jsonDecode(result.stdout) as Map<String, dynamic>;
      expect(report['testCount'], 1);
      expect(result.stderr, contains('test/mini_test.dart'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('missing path exits with a usage error', () async {
      flutterBinaryResolver = () => p.join(fakeBin.path, 'flutter');
      final result = await runCliInProcess(
        pkg,
        ['memory', 'test/nope_test.dart'],
      );
      expect(result.exitCode, 1);
      expect(result.stderr, contains('test path(s) not found'));
      expect(result.stderr, contains('test/nope_test.dart'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
