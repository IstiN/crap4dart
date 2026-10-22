import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

/// Creates a tiny Dart project with two tests in [dir].
void _writeFixture(Directory dir) {
  File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: memory_fixture
environment:
  sdk: ^3.0.0
dev_dependencies:
  test: ^1.33.0
''');
  // Offline resolve from the local pub cache (this repo depends on
  // package:test, so it is always cached) — no network in tests.
  final pub = Process.runSync('dart', ['pub', 'get', '--offline'],
      workingDirectory: dir.path);
  if (pub.exitCode != 0) {
    throw StateError('fixture pub get failed: ${pub.stderr}');
  }
  Directory('${dir.path}/test').createSync();
  File('${dir.path}/test/mini_test.dart').writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('quiet', () => expect(1 + 1, 2));
  test('allocating', () {
    var total = 0;
    for (var i = 0; i < 20000; i++) {
      total += List.filled(50, i).length;
    }
    expect(total, greaterThan(0));
  });
}
''');
}

void main() {
  late Directory workDir;

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('crap4dart_memory');
    _writeFixture(workDir);
  });

  tearDown(() {
    workDir.deleteSync(recursive: true);
  });

  test('memory reports the fixture suite', () async {
    final result = await runCliInProcess(workDir, ['memory', '--top', '2']);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stderr, contains('verbose_gc'));
    expect(result.stdout, contains('memory: 2 tests'));
    expect(result.stdout, contains('allocation churn'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('memory --badge writes the churn SVG', () async {
    final badge = '${workDir.path}/badges/memory.svg';
    final result = await runCliInProcess(
      workDir,
      ['memory', '--badge', badge, '--badge-threshold', '500'],
    );
    expect(result.exitCode, 0, reason: result.stderr);
    final svg = File(badge).readAsStringSync();
    expect(svg, contains('memory churn'));
    expect(svg, contains('MB'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('memory --format json stays JSON-only on stdout', () async {
    final result = await runCliInProcess(
      workDir,
      ['memory', '--format', 'json'],
    );
    expect(result.exitCode, 0, reason: result.stderr);
    final report = jsonDecode(result.stdout) as Map<String, dynamic>;
    expect(report['testCount'], 2);
    expect(report['gcCount'], isA<int>());
    expect(report['tests'], isA<List<dynamic>>());
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('memory exits 1 outside a Dart project', () async {
    final empty = Directory.systemTemp.createTempSync('crap4dart_nomem');
    try {
      final result = await runCliInProcess(empty, ['memory']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('no Dart test suite'));
    } finally {
      empty.deleteSync(recursive: true);
    }
  });
}
