import '../common/constants.dart';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';

import '../goldens/golden_guard_snippet.dart';
import 'exit_codes.dart';
import 'goldens_scaffold_command.dart';

/// Flag/option names of the `--scaffold` group, single-sourced so the
/// argParser registration and the run() lookup cannot drift.
const String kScaffoldFlag = 'scaffold';

/// The `--dir` option name of the `--scaffold` group.
const String kScaffoldDir = 'dir';

/// Usage line for the `--scaffold` group.
const String kScaffoldUsage = '--scaffold [--dir <path>] [--force] [--dry-run]';

/// The `goldens` command: golden-testing helpers. Prints the runtime
/// image-error guard snippet projects copy into their test suites, or
/// scaffolds the visual-regression scene harness (`--scaffold`).
class GoldensCommand extends Command<int> {
  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'goldens';

  @override
  final String description =
      'Golden test helpers: generate the runtime image-error guard, '
      'or scaffold the visual-regression scene harness '
      '(`--scaffold`).';

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
      )
      ..addFlag(
        kScaffoldFlag,
        negatable: false,
        help: 'Generate the visual-regression scene harness into '
            'test/golden/ (scopes above Navigator, phone/desktop × '
            'light/dark matrix, scoped update script, montage).',
      )
      ..addOption(
        kScaffoldDir,
        help: 'Scaffold target directory (relative to the project root).',
        defaultsTo: 'test/golden',
      )
      ..addFlag(
        kForce,
        negatable: false,
        help: 'Scaffold: overwrite existing harness files.',
      )
      ..addFlag(
        kDryRun,
        negatable: false,
        help: 'Scaffold: list the files that would be written, write '
            'nothing.',
      );
  }

  @override
  String get invocation => 'crap4dart goldens [--print-snippet | --write] '
      '[$kScaffoldUsage]';

  @override
  Future<int> run() async {
    if (argResults![kScaffoldFlag] as bool) {
      return GoldenScaffoldWriter(
        projectRoot: projectRoot ?? Directory.current.path,
      ).write(
        dir: argResults![kScaffoldDir] as String,
        force: argResults![kForce] as bool,
        dryRun: argResults![kDryRun] as bool,
      );
    }
    if (argResults!['write'] as bool) {
      return _writeGuard();
    }
    stdout.write(goldenGuardSnippet);
    return ExitCodes.success;
  }

  /// The `--write` path: drops the guard snippet into
  /// `test/goldens_guard.dart`, refusing to overwrite.
  int _writeGuard() {
    final root = projectRoot ?? Directory.current.path;
    final file = File(
      p.join(root, kTest, 'goldens_guard.dart'),
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
}
