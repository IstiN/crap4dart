import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';

import '../goldens/golden_guard_snippet.dart';
import 'exit_codes.dart';

/// The `goldens` command: golden-testing helpers. Prints the runtime
/// image-error guard snippet projects copy into their test suites.
class GoldensCommand extends Command<int> {
  /// Creates a [GoldensCommand] with an optional [projectRoot]
  /// override (used by in-process invocations and tests).
  GoldensCommand({this.projectRoot}) {
    argParser
      ..addFlag(
        'print-snippet',
        negatable: false,
        help: 'Print the guardGoldens helper source to stdout.',
      )
      ..addFlag(
        'write',
        negatable: false,
        help: 'Like --print-snippet, but writes test/goldens_guard.dart.',
      );
  }

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'goldens';

  @override
  final String description =
      'Golden test helpers: generate the runtime image-error guard.';

  @override
  String get invocation => 'crap4dart goldens [--print-snippet | --write]';

  @override
  Future<int> run() async {
    if (argResults!['write'] as bool) {
      final root = projectRoot ?? Directory.current.path;
      final file = File(
        p.join(root, 'test', 'goldens_guard.dart'),
      );
      if (file.existsSync()) {
        stderr.writeln('${p.relative(file.path, from: root)} already '
            'exists.');
        return ExitCodes.usageError;
      }
      file.createSync(recursive: true);
      file.writeAsStringSync(goldenGuardSnippet);
      stdout.writeln('Written to ${file.path} — wrap your golden tests:');
      stdout.writeln('  await guardGoldens(tester, () async { ... });');
      return ExitCodes.success;
    }
    stdout.write(goldenGuardSnippet);
    return ExitCodes.success;
  }
}
