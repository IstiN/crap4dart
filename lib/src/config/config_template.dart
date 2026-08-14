/// Template written by `crap4dart init`.
///
/// Every gate supports two common keys (shown here once):
/// - `severity: error | warning` — warning gates report violations but
///   do not fail the run (default: error).
/// - `ignorable: true` — opt in to `// crap:ignore` line comments and
///   `// crap:ignore-file` markers suppressing violations of this gate.
///   OFF by default: suppression must be explicitly allowed.
const String defaultConfigTemplate = '''
# crap4dart configuration.
# See https://github.com/IstiN/crap4dart for details.

# Directories scanned for Dart sources by "analyze" and "check"
# (default mode, without --changed/--staged).
# sources: [lib, bin]

# Files excluded from analysis in every mode (glob patterns relative
# to the project root).
# exclude: ['example/**', 'tool/**', '**.g.dart']

# CRAP metric analysis settings ("analyze" command).
crap:
  # Enable CRAP analysis; when false, "analyze" exits immediately.
  enabled: true
  # Maximum allowed CRAP score; higher scores fail the run.
  threshold: 8.0
  # Run the test suite to generate coverage before analyzing.
  run_tests: false
  # Count branches inside lambdas towards the enclosing method's
  # cyclomatic complexity.
  # count_lambdas: true

# Coverage input settings.
coverage:
  # Path to the LCOV coverage file, relative to the project root.
  lcov_path: coverage/lcov.info
  # Run "dart test --coverage" / "flutter test --coverage" before analyzing.
  run_tests: false
  # Fail when no coverage data is available instead of reporting N/A.
  required: true
  # Report branch coverage (BRDA records) in addition to line coverage.
  branch_coverage: true

# CPU profiling settings ("profile" command).
# Instruments every method in lib/ with a Stopwatch, runs the test
# suite, and reports per-method timing (source instrumentation).
profile:
  # Enable profiling.
  enabled: true
  # Warn on methods whose total time exceeds this value (milliseconds).
  # Omit to disable the threshold check.
  threshold_ms: 10.0
  # Show only the top N methods by total time (omit to show all).
  # top: 20

# Quality gates ("check" command).
gates:
  # Limit file size in lines of code.
  loc:
    enabled: true
    # Maximum lines per file.
    max_lines: 800
    # Per-path overrides: the first entry whose paths glob matches the
    # file replaces max_lines for that file.
    entries: []
      # - max_lines: 2000
      #   paths: ['lib/legacy/**']
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
  # Enforce a minimum test coverage percentage.
  test_coverage:
    enabled: true
    # Minimum required coverage percent.
    min_percent: 80.0
    # Apply the minimum per file instead of to the project total.
    per_file: false
    # Directories whose files count towards the coverage aggregate.
    dirs: [lib]
  # Enforce golden (screenshot) tests for widgets (Flutter projects).
  golden:
    enabled: true
    # Minimum percentage of widgets with a matching golden test.
    min_widget_coverage: 80.0
    # Directories scanned for widgets.
    widget_dirs: [lib]
    # Directories scanned for golden tests.
    test_dirs: [test]
    # Widget class names excluded from the gate.
    exclude_widgets: []
  # Forbid hardcoded user-visible strings in widget parameters.
  hardcoded_strings:
    enabled: true
    # Comment marker that suppresses the gate on a line.
    ignore_marker: 'l10n:ignore'
    # Widget parameter names that must not contain hardcoded strings.
    check_params: [labelText, hintText, helperText, tooltip]
  # Require semantics labels on interactive widgets (Flutter projects).
  accessibility:
    enabled: true
    # Widget types that must provide a semantics label.
    require_label_for: [IconButton, Image, GestureDetector, InkWell]
  # Limit cyclomatic complexity per method.
  complexity:
    enabled: true
    # Maximum allowed cyclomatic complexity.
    max_complexity: 10
    # Per-path overrides of max_complexity.
    entries: []
    # Count branches inside lambdas towards the enclosing method.
    # count_lambdas: true
  # Limit method size and signature length.
  method_size:
    enabled: true
    # Maximum lines per method body.
    max_lines: 60
    # Maximum number of parameters per method.
    max_params: 6
    # Per-path overrides; unset limits keep the gate defaults.
    entries: []
  # Limit maximum block nesting level per method (catches complexity
  # gate dodging via deeply nested early-return chains).
  nesting:
    enabled: true
    # Maximum number of nested blocks in a method body.
    max_nesting: 5
  # Limit class size: method count and weighted methods per class
  # (WMC = sum of cyclomatic complexities). Catches god-classes that
  # pass the per-method complexity gate.
  class_size:
    enabled: true
    # Maximum concrete methods per class.
    max_methods: 25
    # Maximum WMC per class.
    max_wmc: 80
  # Fail classes that reveal more data than behavior (public fields /
  # public members > max_weight). Off by default: data/model classes
  # are legitimate.
  weight_of_class:
    enabled: false
    # Maximum allowed data-to-members ratio (0.0 - 1.0).
    max_weight: 0.33
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
  # Flag private declarations never referenced in the analyzed sources
  # (dead methods, fields, classes AI agents tend to leave behind).
  unused_code:
    enabled: true
    # Glob patterns whose files are ignored entirely (declarations and
    # references).
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
      - 'bin/**'
  # Flag files under `dirs` that are never imported by any analyzed
  # file (orphans of refactoring). Files with main() and part-of
  # files are never reported.
  unused_files:
    enabled: true
    # Directories checked for orphan files.
    dirs: [lib]
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
  # Enforce architectural boundaries: forbid imports matching `forbid`
  # globs in files matching `from`. With no rules the gate passes.
  banned_imports:
    enabled: true
    rules: []
      # - from: 'lib/ui/**'
      #   forbid: ['**/data/**', 'dart:io']
      #   message: UI must not touch data or IO
  # Detect duplicated code blocks.
  duplication:
    enabled: true
    # Maximum allowed duplicated line percentage per file.
    threshold: 1.0
    # Minimum number of tokens in a block to count as duplication.
    min_tokens: 50
    # Minimum number of lines in a block to count as duplication.
    min_lines: 5
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
      - 'test/**'
  # Forbid mechanical file names (numeric suffixes, generic names).
  file_naming:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
      - 'test/**'
    # Extra whole-stem names allowed to end in digits (technical terms).
    allow: []
  # Flag magic constants: hex colors outside const declarations and
  # literals (numbers, strings) repeating many times in one file.
  magic_constants:
    enabled: true
    # Flag hex color literals (0xRRGGBB / 0xAARRGGBB) outside constants.
    flag_hex_colors: true
    # How many repeats of the same literal in a file trigger a violation.
    min_duplicates: 3
    # Minimum length of a string literal to be considered.
    min_length: 4
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
      - 'test/**'
  # Require dartdoc comments on the public API.
  public_docs:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - 'test/**'
''';
