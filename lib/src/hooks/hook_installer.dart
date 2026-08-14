import 'dart:io';

import 'package:path/path.dart' as p;

import '../gates/gate_context.dart';

/// Error raised when a git hook cannot be installed.
class HookInstallException implements Exception {
  /// Creates a [HookInstallException].
  const HookInstallException(this.message);

  /// Human readable description of the problem.
  final String message;

  @override
  String toString() => 'Hook installation failed: $message';
}

/// Installs crap4dart git hooks into a project's `.git/hooks` directory.
class HookInstaller {
  /// Creates a [HookInstaller].
  const HookInstaller();

  /// Start marker of the managed block inside a hook script.
  static const String beginMarker = '# >>> crap4dart >>>';

  /// End marker of the managed block inside a hook script.
  static const String endMarker = '# <<< crap4dart <<<';

  /// Installs a git hook named [hookName] into [projectRoot].
  ///
  /// The hook runs `crap4dart check --staged --baseline` so that
  /// violations recorded in a committed baseline do not block commits;
  /// only new violations do. When [runTests] is true, the
  /// test suite with coverage runs first (`flutter test --coverage` for
  /// Flutter projects, `dart test --coverage` otherwise).
  ///
  /// An existing hook containing our marker block gets its block replaced.
  /// An existing foreign hook requires [force]; with `force: true` the
  /// block is appended without touching the existing content. Throws a
  /// [HookInstallException] when [projectRoot] is not a git repository.
  ///
  /// Returns the path of the installed hook.
  Future<String> installHook(
    String projectRoot, {
    String hookName = 'pre-commit',
    bool force = false,
    bool runTests = false,
  }) async {
    final gitDir = Directory(p.join(projectRoot, '.git'));
    if (!gitDir.existsSync()) {
      throw const HookInstallException('not a git repository');
    }
    final hooksDir = Directory(p.join(gitDir.path, 'hooks'))..createSync();
    final hookFile = File(p.join(hooksDir.path, hookName));
    final block = _hookBlock(
      runTests: runTests,
      isFlutter: GateContext.isFlutterProjectAt(projectRoot),
    );
    final content = _mergeContent(
      hookFile.existsSync() ? hookFile.readAsStringSync() : null,
      block,
      force: force,
    );
    hookFile.writeAsStringSync(content);
    await _makeExecutable(hookFile.path);
    return hookFile.path;
  }

  String _mergeContent(String? existing, String block, {required bool force}) {
    if (existing == null) return '#!/bin/sh\n$block';
    if (existing.contains(beginMarker)) {
      final start = existing.indexOf(beginMarker);
      final end = existing.indexOf(endMarker);
      if (end > start) {
        final after = end + endMarker.length;
        return existing.substring(0, start) + block + existing.substring(after);
      }
    }
    if (!force) {
      throw HookInstallException(
        'hook exists without a crap4dart block, use --force',
      );
    }
    final separator = existing.endsWith('\n') ? '' : '\n';
    return '$existing$separator$block';
  }

  String _hookBlock({required bool runTests, required bool isFlutter}) {
    final buffer = StringBuffer()
      ..writeln(beginMarker)
      ..writeln('# crap4dart quality gate (installed by "crap4dart install").')
      ..writeln('if command -v crap4dart >/dev/null 2>&1; then')
      ..writeln('  CRAP4DART="crap4dart"')
      ..writeln('elif [ -f bin/crap4dart.dart ]; then')
      ..writeln('  CRAP4DART="dart run bin/crap4dart.dart"')
      ..writeln('else')
      ..writeln(
        '  echo "crap4dart not found; skipping quality checks." >&2',
      )
      ..writeln('  exit 0')
      ..writeln('fi');
    if (runTests) {
      buffer.writeln(
        isFlutter
            ? 'flutter test --coverage || exit 1'
            : 'dart test --coverage || exit 1',
      );
    }
    buffer
      ..writeln('\$CRAP4DART check --staged --baseline')
      ..writeln(endMarker);
    return buffer.toString();
  }

  Future<void> _makeExecutable(String path) async {
    final result = await Process.run('chmod', ['+x', path]);
    if (result.exitCode != 0) {
      throw HookInstallException(
        'could not make hook executable: ${result.stderr}',
      );
    }
  }
}
