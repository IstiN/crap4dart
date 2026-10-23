/// Shared simple literals used across modules, `k`-prefixed per the
/// project convention for plain string constants.
///
/// Every constant owns one spelling, not one usage: the same value may
/// legitimately play several roles (kTest is both the dart/flutter test
/// subcommand and the test directory name). The `scattered_constants`
/// gate guards against the literals reappearing inline elsewhere.
library;

/// The Dart SDK executable.
const String kDart = 'dart';

/// The Flutter tool executable.
const String kFlutter = 'flutter';

/// The `test` subcommand of the dart/flutter tools and the name of the
/// directory holding a project's tests.
const String kTest = 'test';

/// The `json` format/reporter name (CLI output formats, dart/flutter
/// test `-r json`).
const String kJson = 'json';

/// The `console` output format shared by the reporting commands.
const String kConsole = 'console';

/// The `diff` subcommand of git and the shared `--diff` CLI flag.
const String kDiff = 'diff';

/// The shared `--format` CLI option name.
const String kFormat = 'format';

/// The shared `--config` CLI option name.
const String kConfig = 'config';

/// The help text of the shared `--config` option.
const String kConfigHelp = 'Path to a crap4dart.yaml config file.';

/// The help text of the shared `--format` option.
const String kOutputFormatHelp =
    'Output format (json writes only JSON to stdout).';

/// The help text of the shared `--diff-base` option.
const String kDiffBaseHelp =
    'Like --diff, but diffs against the given git ref.';

/// The default LCOV report path, relative to the project root.
const String kDefaultLcovPath = 'coverage/lcov.info';

/// Matches the `name:` entry of a pubspec.
const String kPubspecNamePattern = r'^name:\s*(.+)$';

/// The file name of a package's pubspec.
const String kPubspec = 'pubspec.yaml';

/// The file extension of Dart sources, with the leading dot.
const String kDartExtension = '.dart';

/// The skip reason reported when a Flutter-only gate runs in a
/// non-Flutter project.
const String kNotFlutterProject = 'not a Flutter project';

/// The shared prefix of every `gates.*` config path; sites compose
/// `'$kGatePrefix.loc'`-style paths from it.
const String kGatePrefix = 'gates';

/// Milliseconds per second (memory and profile reports).
const int millisPerSecond = 1000;
