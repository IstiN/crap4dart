import 'dart:io';

import 'package:crap4dart/src/coverage/coverage_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ProcessResult _result(int exitCode) => ProcessResult(0, exitCode, '', '');

void _writeLcov(String? workingDirectory) {
  final dir = Directory(p.join(workingDirectory!, 'coverage'))
    ..createSync(recursive: true);
  File(p.join(dir.path, 'lcov.info')).writeAsStringSync('');
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('crap4dart_covrun_test_');
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: fixture\n');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  group('CoverageRunner', () {
    test('dart project falls back to format_coverage', () async {
      final calls = <String>[];
      Future<ProcessResult> spawn(
        String exe,
        List<String> args, {
        String? workingDirectory,
      }) async {
        calls.add('$exe ${args.first}');
        if (args.contains('coverage:format_coverage')) {
          _writeLcov(workingDirectory);
        }
        return _result(0);
      }

      final lcov = await CoverageRunner(spawn: spawn).run(project.path);
      expect(lcov, p.join(project.path, 'coverage', 'lcov.info'));
      expect(calls, ['dart test', 'dart pub']);
    });

    test('flutter project uses flutter test --coverage directly', () async {
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
        'name: fixture\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
      final calls = <String>[];
      Future<ProcessResult> spawn(
        String exe,
        List<String> args, {
        String? workingDirectory,
      }) async {
        calls.add(exe);
        _writeLcov(workingDirectory);
        return _result(0);
      }

      final lcov = await CoverageRunner(spawn: spawn).run(project.path);
      expect(lcov, isNotNull);
      expect(calls, ['flutter']);
    });

    test('returns null when no coverage file is produced', () async {
      Future<ProcessResult> spawn(
        String exe,
        List<String> args, {
        String? workingDirectory,
      }) async =>
          _result(1);

      final lcov = await CoverageRunner(spawn: spawn).run(project.path);
      expect(lcov, isNull);
    });

    test('returns null when spawning fails', () async {
      Future<ProcessResult> spawn(
        String exe,
        List<String> args, {
        String? workingDirectory,
      }) =>
          throw ProcessException(exe, args, 'not found');

      final lcov = await CoverageRunner(spawn: spawn).run(project.path);
      expect(lcov, isNull);
    });
  });
}
