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

/// The shared `--diff-base` option (diff against a given git ref).
const String kDiffBase = 'diff-base';

/// The shared `--changed` flag (diff scope: git working tree).
const String kChanged = 'changed';

/// The shared `--staged` flag (diff scope: git index).
const String kStaged = 'staged';

/// The shared `--badge` option name (SVG badge output path).
const String kBadge = 'badge';

/// The `--threshold` option name and the `threshold` key of config
/// sections; each command and section defines what it thresholds.
const String kThreshold = 'threshold';

/// The `profile` command name, its config section key and the command
/// tag in JSON reports.
const String kProfile = 'profile';

/// The shared `--include` option name and `include` config key.
const String kInclude = 'include';

/// The shared `--exclude` option name and per-gate `exclude` key.
const String kExclude = 'exclude';

/// The `jaccard` similarity setting (CLI option and config key).
const String kJaccard = 'jaccard';

/// The `containment` similarity setting (CLI option and config key).
const String kContainment = 'containment';

/// The `.dart_tool` directory of a package.
const String kDartToolDir = '.dart_tool';

/// The path prefix of sources inside a package's `lib/` directory.
const String kLibPrefix = 'lib/';

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

/// The generated-code glob family, shared by every gate's default
/// `exclude` list and the `init` config template.
const String kGeneratedGlob = '**.g.dart';

/// The freezed-codegen glob.
const String kFreezedGlob = '**.freezed.dart';

/// The mock-codegen glob.
const String kMocksGlob = '**.mocks.dart';

/// The skip reason reported when a Flutter-only gate runs in a
/// non-Flutter project.
const String kNotFlutterProject = 'not a Flutter project';

/// The shared prefix of every `gates.*` config path; sites compose
/// `'$kGatePrefix.'` + `GateIds.x` paths from it, so a gate rename is
/// a one-line change and an id typo is a compile error.
const String kGatePrefix = 'gates';

/// Milliseconds per second (memory and profile reports).
const int millisPerSecond = 1000;

/// Microseconds per millisecond (unit conversion for reported times).
const double microsPerMillisecond = 1000.0;

/// The `coverage` name shared by the config section key and the
/// coverage directory argument of the coverage tooling.
const String kCoverage = 'coverage';

/// The shared `error` label — gate severity, Checkstyle severity tag
/// and VM-service status all spell it identically.
const String kError = 'error';

/// JSON/attribute names of a violation location, shared by the JSON
/// reporter and the Checkstyle-XML output of the external gate.
const String kFileKey = 'file';

/// The `line` attribute name of a violation location — shared by the
/// JSON reporter and the Checkstyle-XML output of the external gate.
const String kLineKey = 'line';

/// The `extension` declaration label — the analyzer visitor's kind
/// tag and the synthetic name for unnamed extensions.
const String kExtension = 'extension';
