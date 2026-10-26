import '../common/constants.dart';

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
# exclude: ['example/**', 'tool/**', '$kGeneratedGlob']

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
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
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
    # Maximum allowed complexity.
    max_complexity: 10
    # Which metric max_complexity applies to: 'cyclomatic' (path count,
    # also feeds CRAP) or 'cognitive' (SonarSource-style, nesting-
    # weighted; flat else-if chains stay cheap). Default: cyclomatic.
    # metric: cyclomatic
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
  # Flag record types that must be named: an inline record type in a
  # signature is declared as a typedef (or class) and referenced by
  # name. Record values (literals, destructuring) stay legal; record
  # type aliases are the blessed form and are not scanned.
  inline_record_types:
    enabled: true
    severity: warning
  # Require named record fields: positional (unnamed) fields in record
  # types and `.\$N` positional accesses are flagged — name the fields
  # (`({int x, int y})`) or destructure.
  record_named_fields:
    enabled: true
    severity: warning
  # Cap record arity: a record with more than max_fields positional +
  # named fields has outgrown the tuple idea and should be transformed
  # into a class.
  record_size:
    enabled: true
    severity: warning
    max_fields: 5
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
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
  # Flag private declarations never referenced in the analyzed sources
  # (dead methods, fields, classes AI agents tend to leave behind).
  unused_code:
    enabled: true
    # Glob patterns whose files are ignored entirely (declarations and
    # references).
    exclude:
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
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
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
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
    # What violations are reported for: 'percentage' (per-file percent of
    # duplicated lines over threshold) or 'clones' (PMD CPD style — one
    # violation per clone group with all its locations).
    # report: percentage
    # Minimum number of tokens in a block to count as duplication.
    min_tokens: 50
    # Minimum number of lines in a block to count as duplication.
    min_lines: 5
    # Rename locally declared identifiers consistently before hashing so
    # renamed (Type-2) clones are detected; API names stay visible.
    ignore_locals: false
    # Replace string and numeric literals with placeholders before
    # hashing so clones differing only in literal values are detected.
    ignore_literals: false
    # Replace ALL identifiers with one placeholder before hashing
    # (structure-only matching, CPD --ignore-identifiers).
    ignore_identifiers: false
    # Exclude import/export/part directives from tokenization.
    ignore_imports: false
    # Skip files whose token stream equals an earlier file's, so a
    # copied file is reported once (CPD --skip-duplicate-files).
    skip_duplicate_files: false
    # Glob patterns excluded from the gate.
    exclude:
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
      - 'test/**'
    # Extra file/directory paths scanned for duplication (cross-module
    # checks), unioned with the analyzed source set.
    # sources:
    #   - 'flutter_app/lib'
    #   - 'packages/fa_ui/lib'
  # Flag literals (strings of min_length+ chars, numbers of
  # min_value+ magnitude) appearing in min_files+ distinct files —
  # one business fact hardcoded in many places. Extract a shared
  # constant and verify all occurrences mean the same thing.
  scattered_constants:
    enabled: true
    severity: warning
    min_files: 3
    min_length: 4
    min_value: 100
    # Literal values never flagged (fast-development repos: generic
    # vocabulary whose extraction adds churn without benefit).
    # Whole literals match by value, prefixes by head, numbers by
    # their decimal form.
    # ignore: [test, dart, flutter]
    # Glob patterns excluded from the gate.
    exclude:
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
      - 'test/**'
      - 'test/**'
  # and substring candidates against existing named constants —
  # partial reuse the whole-value gate cannot see. Findings are
  # candidates; verify intent before extracting.
  # Forbid mechanical file names (numeric suffixes, generic names).
  file_naming:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
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
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
      - 'test/**'
  # Scan golden PNG files for rendered error artifacts: overflow
  # stripes (yellow/black) and build-error screens (dark red). Golden
  # tests do not fail on these — the broken frame gets captured.
  broken_goldens:
    enabled: true
    # Directories recursively scanned for golden PNGs.
    dirs: [test]
    # Minimum alternating yellow/black pixels counting as a stripe.
    min_stripe_run: 8
    # Glob patterns excluded from the gate.
    exclude: []
  # Fail tests whose bodies contain no assertion calls (expect, fail,
  # throwsA, ...) — they verify nothing.
  test_assertions:
    enabled: true
    # Minimum assertion calls per test()/testWidgets() body.
    min_assertions: 1
    # Glob patterns excluded from the gate.
    exclude: []
  # Flag directories with loose .dart files instead of organized
  # feature packages (flat-file sprawl).
  folder_structure:
    enabled: true
    # Directories checked for loose-file sprawl.
    dirs: [lib]
    # Max .dart files directly inside each directory.
    max_loose_files: 0
    # Glob patterns excluded from the gate.
    exclude: []
  # Wrap external static-analysis tools (detekt, ktlint, swiftlint,
  # ...) producing a Checkstyle XML report; their findings become
  # standard violations (severity/baseline/diff mode apply).
  external:
    enabled: true
    rules: []
      # - id: detekt
      #   executable: detekt
      #   arguments: ['--report', 'checkstyle:{report}', 'android/']
      # - id: swiftlint
      #   executable: swiftlint
      #   arguments: ['lint', '--reporter', 'checkstyle', '>'] # see docs
  # Similarity: file-level near-duplicate detection over any text
  # corpus (markdown docs, source files) — copied docs that drifted
  # apart, twin templates, stale snapshots, generated files duplicating
  # their sources. Different from `duplication` (token-level clone
  # blocks in Dart): a violation means "this file is (mostly) a copy of
  # that file" — reuse, generate or delete, not extract-method.
  # Explore with `crap4dart similarity`, tune, then enable — typically
  # with `check --save-baseline` so only NEW near-duplicates fail.
  similarity:
    # Disabled by default: corpora differ wildly; opt in deliberately.
    enabled: false
    # Directories recursively scanned for text files.
    dirs: ['.']
    # Glob patterns of files to analyze.
    include: ['**/*.md']
    # Files with fewer shingles (8-token windows) than this are skipped.
    min_shingles: 50
    # Pair thresholds: report when Jaccard >= this OR containment >=
    # this (containment catches a small file largely copied into a big
    # one). 0.8/0.95 flags near-identical twins; docs corpora with
    # heavy boilerplate tune down to ~0.5/0.85 plus a baseline.
    jaccard: 0.8
    containment: 0.95
    # Glob patterns excluded from the gate.
    exclude: ['.git/**', '.dart_tool/**', 'build/**', 'coverage/**',
              'node_modules/**']
  # Mutation testing: mutate one operator/literal at a time and re-run
  # the test suite per mutant. Expensive — disabled by default; enable
  # explicitly once the suite is fast. Sites in unexecuted code are
  # excluded from the score.
  mutation:
    # Enable mutation testing (requires coverage data and a test suite).
    enabled: false
    # Minimum required mutation score (killed / (killed + survived)).
    min_score: 0.8
    # Maximum tolerated survived mutants, even above min_score.
    max_survivors: 0
    # Per-mutant timeout in seconds; a timeout counts as survived.
    timeout_seconds: 60
    # Performance cap: at most this many covered sites are executed.
    max_mutants: 500
    # Operator categories to enable (default: all).
    operators: [arithmetic, boundary, equality, logical, boolean, constant,
                unary]
    # Digest-incremental cache (.crap-mutation-cache.json): killed
    # mutants of unchanged methods are replayed, not re-executed;
    # survivors always re-run. A config/operator change wipes it.
    cache: true
    # Per-mutant test invocation args (`dart <args...>`). Scoping the
    # suite is your responsibility: a mutant is killed only if the
    # scoped suite would kill it.
    test_args: ['test']
    # Per-mutant test scoping: narrow each mutant's run to the derived
    # test file(s) of the mutated file (lib/src/foo/bar.dart ->
    # test/src/foo/bar_test.dart, test/foo/bar_test.dart); falls back
    # to test_args when no candidate exists. Scoped kills are cached;
    # scoped survivors are re-confirmed against the full invocation.
    scope_tests: false
    # Glob patterns excluded from the gate.
    exclude:
      - '$kGeneratedGlob'
      - '$kFreezedGlob'
      - '$kMocksGlob'
      - 'test/**'
  # Require dartdoc comments on the public API.
  public_docs:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - 'test/**'
''';
