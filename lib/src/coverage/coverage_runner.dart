import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Runs the project's test suite to produce an LCOV coverage file.
///
/// Flutter projects (detected by a `flutter` entry in the pubspec
/// dependencies) use `flutter test --coverage`; pure Dart projects use
/// `dart test --coverage` followed by `coverage:format_coverage`.
class CoverageRunner {
  /// Creates a [CoverageRunner].
  const CoverageRunner();

  /// Default LCOV output path, relative to the project root.
  static const String defaultLcovPath = 'coverage/lcov.info';

  /// Runs the tests of the project at [projectRoot] and returns the path to
  /// the generated `lcov.info`, or `null` when coverage could not be
  /// produced.
  ///
  /// Progress and failures are reported to [stderr]; this method never
  /// throws for test or tooling failures.
  Future<String?> run(String projectRoot) async {
    try {
      return await _run(projectRoot);
    } on ProcessException catch (e) {
      stderr.writeln('Warning: could not run tests: ${e.message}');
      return null;
    }
  }

  Future<String?> _run(String projectRoot) async {
    final lcovPath = p.join(projectRoot, defaultLcovPath);
    final isFlutter = _isFlutterProject(projectRoot);
    stderr.writeln(
      isFlutter
          ? 'Running "flutter test --coverage"...'
          : 'Running "dart test --coverage"...',
    );
    final testResult = await Process.run(
      isFlutter ? 'flutter' : 'dart',
      isFlutter
          ? const ['test', '--coverage']
          : const ['test', '--coverage=coverage'],
      workingDirectory: projectRoot,
    );
    if (testResult.exitCode != 0) {
      stderr.writeln('Warning: tests failed; coverage may be incomplete.');
      stderr.writeln('${testResult.stderr}'.trim());
    }
    if (!isFlutter && !File(lcovPath).existsSync()) {
      await _formatCoverage(projectRoot);
    }
    if (!File(lcovPath).existsSync()) {
      stderr.writeln('Warning: no coverage file produced at $lcovPath.');
      return null;
    }
    return lcovPath;
  }

  Future<void> _formatCoverage(String projectRoot) async {
    stderr.writeln('Formatting coverage with "coverage:format_coverage"...');
    final result = await Process.run(
      'dart',
      const [
        'pub',
        'global',
        'run',
        'coverage:format_coverage',
        '--lcov',
        '--in',
        'coverage',
        '--out',
        'coverage/lcov.info',
        '--report-on',
        'lib',
      ],
      workingDirectory: projectRoot,
    );
    if (result.exitCode != 0) {
      stderr.writeln(
        'Warning: format_coverage failed (is the "coverage" package '
        'activated with "dart pub global activate coverage"?):',
      );
      stderr.writeln('${result.stderr}'.trim());
    }
  }

  bool _isFlutterProject(String projectRoot) {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final doc = loadYaml(pubspec.readAsStringSync());
    if (doc is! YamlMap) return false;
    for (final section in const ['dependencies', 'dev_dependencies']) {
      final deps = doc[section];
      if (deps is YamlMap && deps.containsKey('flutter')) return true;
    }
    return false;
  }
}
