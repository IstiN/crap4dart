import 'dart:io';

import 'package:path/path.dart' as p;

import '../gates/gate_context.dart';
import 'hook_installer.dart';

/// Installs a GitHub Actions quality workflow into a project.
class CiInstaller {
  /// Creates a [CiInstaller].
  const CiInstaller();

  /// Path of the workflow relative to the project root.
  static const String workflowPath = '.github/workflows/quality.yml';

  /// Creates `.github/workflows/quality.yml` in [projectRoot].
  ///
  /// Flutter projects get a Flutter-based workflow; pure Dart projects get
  /// a Dart-based one. An existing file is only overwritten when [force]
  /// is true; otherwise a [HookInstallException] is thrown.
  ///
  /// Returns the path of the created workflow file.
  String installCi(String projectRoot, {bool force = false}) {
    final file = File(p.join(projectRoot, workflowPath));
    if (file.existsSync() && !force) {
      throw HookInstallException(
        '$workflowPath already exists, use --force',
      );
    }
    file.parent.createSync(recursive: true);
    final isFlutter = GateContext.isFlutterProjectAt(projectRoot);
    file.writeAsStringSync(
      isFlutter ? _flutterWorkflow() : _dartWorkflow(),
    );
    return file.path;
  }

  String _dartWorkflow() => '''
name: Quality

on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub get
      - run: dart format --set-exit-if-changed .
      - run: dart analyze
      - run: dart test --coverage=coverage
      - run: dart pub global activate coverage
      - name: Format coverage
        run: >-
          dart pub global run coverage:format_coverage
          --lcov --in coverage --out coverage/lcov.info --report-on lib
      - name: Install crap4dart
        run: dart pub global activate crap4dart
      - run: crap4dart check --all
      - run: crap4dart analyze
''';

  String _flutterWorkflow() => '''
name: Quality

on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test --coverage
      - name: Install crap4dart
        run: dart pub global activate crap4dart
      - run: crap4dart check --all
      - run: crap4dart analyze
''';
}
