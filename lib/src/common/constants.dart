/// Shared literal names used across modules.
///
/// Every constant owns one business fact; the `scattered_constants`
/// gate guards against the literals reappearing inline elsewhere.
/// Two constants may share a spelling but never a meaning (see
/// [testSubcommand] vs [testDirName]) — that is the point: renaming a
/// fact changes exactly one line.
library;

// ---------------------------------------------------------------------------
// Tool invocation names (argv elements passed to Process.run/start).
// ---------------------------------------------------------------------------

/// The Dart SDK executable.
const String dartExecutable = 'dart';

/// The Flutter tool executable.
const String flutterExecutable = 'flutter';

/// The `test` subcommand of the dart and flutter tools.
const String testSubcommand = 'test';

/// The machine-readable reporter of dart/flutter test (`-r json`).
const String testReporterJson = 'json';

/// The `diff` subcommand of git.
const String gitDiffSubcommand = 'diff';

// ---------------------------------------------------------------------------
// File and directory names.
// ---------------------------------------------------------------------------

/// The name of the directory holding a project's tests.
const String testDirName = 'test';

/// The file name of a package's pubspec.
const String pubspecFileName = 'pubspec.yaml';

/// The file extension of Dart sources, with the leading dot.
const String dartFileExtension = '.dart';

// ---------------------------------------------------------------------------
// CLI protocol values.
// ---------------------------------------------------------------------------

/// The `console` output format shared by the reporting commands.
const String outputFormatConsole = 'console';

/// The `json` output format shared by the reporting commands.
const String outputFormatJson = 'json';

/// The skip reason reported when a Flutter-only gate runs in a
/// non-Flutter project.
const String notFlutterProjectReason = 'not a Flutter project';

// ---------------------------------------------------------------------------
// Units.
// ---------------------------------------------------------------------------

/// Milliseconds per second (memory and profile reports).
const int millisPerSecond = 1000;

/// Microseconds per millisecond (VM service timestamps).
const int microsPerMillisecond = 1000;
