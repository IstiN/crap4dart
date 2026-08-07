/// Template written by `crap4dart init`.
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

# Quality gates ("check" command).
gates:
  # Limit file size in lines of code.
  loc:
    enabled: true
    # Maximum lines per file.
    max_lines: 800
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
    # Count branches inside lambdas towards the enclosing method.
    # count_lambdas: true
  # Limit method size and signature length.
  method_size:
    enabled: true
    # Maximum lines per method body.
    max_lines: 60
    # Maximum number of parameters per method.
    max_params: 6
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
  # Require dartdoc comments on the public API.
  public_docs:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - 'test/**'
''';
