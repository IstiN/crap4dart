# crap4dart Specification

## 1. Purpose

`crap4dart` is a CRAP metric analyzer and quality-gate tool for Dart and
Flutter projects. It is a Dart port of the Java tool `crap4java`.

It shall:

- locate Dart source files to analyze
- parse Dart methods and compute cyclomatic complexity
- read LCOV coverage data and attribute it to methods
- combine complexity and coverage into CRAP scores
- print console or JSON reports sorted by worst score first
- run configurable quality gates over the project sources
- install a pre-commit hook and a CI workflow template
- fail when the maximum CRAP score exceeds the configured threshold or a
  quality gate fails

`crap4dart` is intended as a project-quality gate rather than a mutation
tool.

## 2. Scope

This specification defines:

- the command-line contract
- source file selection rules
- coverage handling
- method parsing behavior
- CRAP score computation
- report formats, ordering and exit codes
- the configuration file contract
- the quality gates and their semantics
- CPU profiling (`profile` command)
- hook and CI installation behavior

This specification does not define:

- semantic (resolved-AST) analysis
- automatic fixing of violations
- watch mode

## 3. Terminology

- `project root`
  The working directory from which `crap4dart` is invoked.

- `method metric`
  A single report row consisting of method identity, cyclomatic
  complexity, coverage, branch coverage and CRAP score.

- `coverage N/A`
  The state where no coverage data could be attributed to a method.

- `gate`
  A named quality check over the project sources, producing pass, fail or
  skip.

- `managed block`
  The region of an installed git hook delimited by the markers
  `# >>> crap4dart >>>` and `# <<< crap4dart <<<`.

## 4. Command-Line Interface

### 4.1 Commands

The tool shall support these commands:

- `crap4dart` (equivalent to `crap4dart analyze`)
- `crap4dart analyze [paths...]`
- `crap4dart check`
- `crap4dart init`
- `crap4dart install`
- `crap4dart profile`
- `crap4dart --help` / `crap4dart --version`

### 4.2 analyze Options

- `[paths...]`
  Files are analyzed directly; directories are expanded recursively to
  `.dart` files. Without paths, all `.dart` files under `lib/` and `bin/`
  are analyzed.

- `--changed`
  Analyze changed `.dart` files from `git status --porcelain`.

- `--threshold <value>`
  Override the configured CRAP threshold.

- `--lcov <path>`
  Override the configured LCOV file path.

- `--run-tests`
  Run the test suite with coverage before analyzing.

- `--config <path>`
  Use a non-default config file.

- `--format console|json`
  Select the report format (default: `console`).

- `--diff` / `--diff-base <ref>`
  Restrict the analysis to methods touched by `git diff` (see §9.3).
  `--diff` uses base `HEAD`; `--diff-base` implies `--diff` with the given
  ref. Shall not be combined with `--changed` or explicit paths.

- `--badge <path>`
  Write an SVG badge with the max CRAP score to `<path>` (see §9.4).

### 4.3 check Options

- `--all` (default), `--changed`, `--staged`
  Select target files: all files under `lib/` and `bin/`, changed files
  from `git status --porcelain`, or staged files from
  `git diff --cached --name-only --diff-filter=ACM`. `--changed` and
  `--staged` shall be mutually exclusive.

- `--only <ids>` / `--skip <ids>`
  Comma-separated gate id filters. Unknown gate ids shall be a usage
  error.

- `--diff` / `--diff-base <ref>`
  Restrict violations to added/changed lines (see §9.3). Shall not be
  combined with `--changed`/`--staged`.

- `--config <path>`, `--run-tests`, `--format console|json`
  As for `analyze`.

### 4.4 init

Creates a fully commented default `crap4dart.yaml` in the current
directory. An existing file shall not be overwritten unless `--force` is
given; without `--force` the tool shall print an error to stderr and exit
with usage-error status.

### 4.5 install

- Installs a git hook (default `pre-commit`, overridable with `--hook`)
  that runs `crap4dart check --staged`.
- `--ci` additionally installs `.github/workflows/quality.yml`.
- `--force` allows merging into an existing foreign hook or overwriting
  an existing workflow file.
- `--config <path>` selects a non-default config file.

### 4.6 profile Options

- `[paths...]`
  Explicit test file or directory paths forwarded to the test runner.
  Without paths, the full test suite is run.

- `--name <pattern>`
  Run only tests whose name matches the given substring or regex.

- `--tags <t1,t2>`
  Run only tests with the given tags (comma-separated).

- `--exclude-tags <t1,t2>`
  Exclude tests with the given tags (comma-separated).

- `--threshold <ms>`
  Override the configured total-time threshold in milliseconds. Methods
  whose total time exceeds this value fail the run.

- `--top <N>`
  Limit the report to the `N` slowest methods (by total time). Defaults to
  the configured `top` (default 20).

- `--config <path>`
  Use a non-default config file.

- `--format console|json`
  Select the report format (default: `console`).

- `--diff` / `--diff-base <ref>`
  Restrict the report to methods touched by `git diff` (see §9.3). `--diff`
  uses base `HEAD`; `--diff-base` implies `--diff` with the given ref.

### 4.7 Invalid Usage

The tool shall exit with usage-error status when argument parsing fails
and shall print usage information on CLI usage failure.

## 5. File Selection Rules

### 5.1 Default Source Discovery

In default mode the tool shall analyze all `.dart` files under the
directories listed in the `sources` config key (default `lib/` and, when
present, `bin/`), excluding files matching `**.g.dart`, `**.freezed.dart`,
`**.mocks.dart` and anything under `.dart_tool/`. Configured directories
that do not exist shall be silently skipped.

### 5.2 Changed-File Discovery

In `--changed` mode the tool shall invoke `git status --porcelain`, keep
modified, added, untracked and renamed entries (for renames, the new
path), retain only `.dart` files and sort them in path order.

In `--staged` mode the tool shall invoke
`git diff --cached --name-only --diff-filter=ACM` with the same filtering.

### 5.3 Explicit Paths

Explicit paths shall be expanded per §4.2, de-duplicated and sorted.

### 5.4 Empty Selection

If no Dart files are selected, the tool shall print
`No Dart files to analyze.` (or `No Dart files to check.`) and exit
successfully.

## 6. Coverage Pipeline

### 6.1 LCOV Input

Coverage shall be read from the LCOV file at the configured `lcov_path`
(default `coverage/lcov.info`). Only `SF`, `DA` and `BRDA` records shall
be interpreted. Absolute `SF` paths shall be relativized against the
project root.

### 6.2 Test Execution

When `coverage.run_tests` (or `crap.run_tests`) is true in the config, or
`--run-tests` is given, the tool shall run the test suite before reading
coverage:

- Flutter projects (pubspec depends on `flutter`):
  `flutter test --coverage`
- pure Dart projects: `dart test --coverage=coverage`, followed by
  `coverage:format_coverage` when `coverage/lcov.info` was not produced

In `check`, a test run that produces no coverage file shall fail with an
error and exit with usage-error status. In `analyze`, it shall degrade to
coverage N/A with a warning.

### 6.3 Missing Coverage Data

If no LCOV file exists:

- `analyze` shall print a warning to stderr and report coverage and CRAP
  as N/A; the threshold shall not be considered exceeded.
- the `test_coverage` gate shall fail when `coverage.required` is true
  and skip otherwise.

### 6.4 Coverage Attribution

Coverage shall be attributed to methods by line range: the `DA` records
within the method's start/end lines form the denominator, records with
hits > 0 the numerator. Branch coverage shall analogously use `BRDA`
records taken at least once. When no records fall inside a method's
range, coverage shall be N/A.

LCOV entries whose path is not project-relative (absolute, or escaping
the root via `..`) shall be ignored during attribution, so dependency
records (e.g. from the pub cache) are never matched to project files.

## 7. Dart Method Parsing

The tool shall parse Dart sources using `package:analyzer` unresolved
ASTs; full semantic resolution shall not be required.

### 7.1 Exclusions

The parser shall ignore constructors (except for parameter counting in
the `method_size` gate), abstract and bodyless methods, and nested
function declarations.

### 7.2 Complexity Counting

Cyclomatic complexity shall be computed from method bodies with base
value 1 and +1 for each: `if`, `for` (any form), `while`, `do`,
`catch` clause, `switch` case (including `default`), conditional
expression (`?:`), and each `&&`/`||` operator. Branches inside lambda
bodies count towards the enclosing method; nested named function
declarations do not.

## 8. CRAP Formula

For methods with known coverage, CRAP shall be computed as:

`CRAP = CC^2 * (1 - coverage)^3 + CC`

where `CC` is cyclomatic complexity and `coverage` the line coverage
fraction in `0.0..1.0`. Methods with coverage N/A shall have CRAP N/A.

## 9. Reports

### 9.1 Console Report

The analyze console report shall contain CRAP, COV%, BR%, CC, METHOD and
FILE:LINE columns, sorted by numeric CRAP descending with N/A entries
last, followed by a summary line with the maximum CRAP and the threshold
verdict.

The check console report shall print one `[PASS]`/`[FAIL]`/`[SKIP]` line
per gate with an optional summary, up to 20 violations per failed gate
(summarizing the remainder), and a final aggregate line.

### 9.2 JSON Report

With `--format json`, stdout shall contain only a single valid JSON
document:

- analyze: `command`, `threshold`, `maxCrap`, `passed`, and `methods`
  (same order as the console report; missing values are JSON `null`).
- check: `command`, `passed`, and `gates` with `id`, `status`
  (`passed`/`failed`/`skipped`), optional `summary` or `reason`, and
  `violations` (`file`, `line`, `message`).

Warnings shall go to stderr. Exit codes shall be identical to the console
format.

### 9.3 Diff Mode

With `--diff` or `--diff-base <ref>`, the tool shall run
`git diff --unified=0 <base> -- '*.dart'` and build a map of
project-relative new file paths to their added/changed line numbers.
Deleted files shall be absent from the map; files with only deletions
shall map to an empty set; new files shall have all their lines.
Untracked files are not part of `git diff`; staged new files are. A
failed git invocation shall be an error printed to stderr with
usage-error status.

In diff mode:

- The analyzed files shall be the diff files existing on disk (subject to
  the global `exclude`, independent of `sources`).
- `analyze` shall report only methods whose line range intersects the
  added lines. The report header (console) or the JSON fields
  `diffMode`/`diffBase` shall mark the mode.
- `check` shall run the gates on the diff files and then filter
  violations: a violation with a line number survives only when the line
  was added/changed; a file-level violation (no line) survives only for
  files with at least one added/changed line. Gate summaries shall be
  kept as computed, and rendered gate lines shall be marked
  `(diff mode)`.
- The `test_coverage` aggregate is not meaningful in diff mode; the
  file-level rule above applies to it unchanged.

### 9.4 Badge

With `--badge <path>`, `analyze` shall write a self-contained
shields.io-style SVG badge to `<path>` after the analysis, creating parent
directories as needed. The badge shall show the label `CRAP` and the
maximum numeric CRAP score with two decimals, or `N/A` when no numeric
scores exist. The color shall be green when the maximum is at or below the
effective threshold, yellow when above it but at most twice the threshold,
red beyond that, and light grey for N/A.

The badge shall be written even when the threshold is exceeded (exit code
2). Write failures shall produce a stderr warning without changing the
exit code. A confirmation and a Markdown snippet shall be printed to
stderr, keeping stdout unchanged (including under `--format json`).

### 9.5 Profile Report

The `profile` command shall use **source instrumentation**: it creates a
temporary copy of the project's `lib/` directory with every method body
wrapped in a `Stopwatch`-based `try/finally` block, runs the test suite
against the instrumented copy, and collects deterministic per-method timing
data. The temporary directory (`.crap_profile_temp/`) shall be cleaned up
automatically after the run.

For pure-Dart projects the test runner shall use
`dart test --compiler source` (bypassing the kernel cache that would load
the original uninstrumented sources). For Flutter projects it shall use
`flutter test`.

For each profiled method, the tool shall report:

- **total time** — total execution time across all calls (microseconds)
- **calls** — number of invocations
- **mean time** — average time per call (microseconds)
- **max time** — slowest single call (microseconds)
- **@60fps** — estimated per-frame cost at 60 fps (mean × 60, in
  milliseconds), highlighting methods that are cheap per-call but costly
  when called every frame

Method attribution: timing data shall be matched to project methods by
`ClassName.methodName` using the same method parsing as `analyze` (§7).
Timing entries that do not match a project method shall be ignored.

The console report shall list `TOTAL(ms)`, `%`, `CALLS`, `MEAN(µs)`,
`MAX(µs)`, `@60fps(ms)`, `METHOD` and `FILE:LINE` columns sorted by total
time descending, limited to the configured `top` count, followed by a
summary line stating whether the threshold was exceeded and how many
methods violated it.

With `--format json`, stdout shall contain a single JSON document with:
`command`, `totalMicros`, `thresholdMs` (when set), `passed`, and `methods`
(each with `file`, `line`, `class`, `method`, `calls`, `totalMicros`,
`minMicros`, `maxMicros`, `meanMicros`). The report shall mark diff mode
with `diffMode`/`diffBase` fields as in §9.2.

The run shall fail with threshold-failure status when at least one
method's total time exceeds the configured (or `--threshold`) value in
milliseconds.

## 10. Configuration

### 10.1 File Location and Defaults

The tool shall read `crap4dart.yaml` from the project root, or the file
given by `--config`. A missing default file shall not be an error and
shall yield the built-in defaults. A partial config shall be merged with
defaults per key.

### 10.2 Strict Validation

Unknown top-level keys, unknown gate ids, unknown keys inside a gate and
wrongly typed values shall raise a configuration error naming the
offending key; the CLI shall print it to stderr and exit with
usage-error status. The `sources` key shall be a list of non-empty
strings. The `exclude` key shall be a list of glob patterns applied to
every file selection mode. The `count_lambdas` keys (under `crap` and
`gates.complexity`) shall be booleans controlling whether lambda branches
count towards the enclosing method's complexity. The `profile` key shall
configure the `profile` command (§4.6, §9.5) with `enabled` (bool,
default true), `threshold_ms` (double, optional — omit to disable the
threshold check) and `top` (int, default 20).

### 10.3 Gate Identifiers

Known gate ids: `loc`, `test_coverage`, `golden`, `hardcoded_strings`,
`accessibility`, `complexity`, `method_size`, `nesting`, `class_size`,
`weight_of_class`, `unused_code`, `unused_files`, `banned_imports`,
`public_docs`, `duplication`, `file_naming`, `magic_constants`.

## 11. Quality Gates

Gates shall run in the fixed order: `loc`, `test_coverage`,
`complexity`, `method_size`, `nesting`, `class_size`, `duplication`,
`file_naming`, `magic_constants`, `unused_code`, `unused_files`,
`banned_imports`, `public_docs`, `hardcoded_strings`, `accessibility`,
`golden`, `weight_of_class`. A gate disabled in the config shall produce a
skipped result. The run shall fail when at least one gate fails;
skipped gates shall not fail the run.

### 11.0 Framework

Every gate accepts `enabled` (bool), `severity` (`error` | `warning`,
default `error`) and `ignorable` (bool, default `false`). A `warning`
gate's violations shall be reported (marked `[WARN]` in the console
output) but shall not fail the run. `// crap:ignore` on the violation
line or the line above, and `// crap:ignore-file` within the first 5
lines of a file, shall suppress violations of a gate only when that
gate sets `ignorable: true`; by default suppression comments have no
effect.

The `loc`, `complexity` and `method_size` gates accept `entries`: a
list of `{threshold(s), paths}` overrides where the first entry whose
`paths` glob matches the file replaces the default threshold(s) for
that file. Unset `method_size` entry thresholds keep the gate defaults.
Entries must set at least one threshold; `paths` must be a non-empty
glob list.

### 11.1 loc

Fails files longer than `max_lines` (default 800), honoring the
configured `exclude` globs.

### 11.2 test_coverage

Fails when the total line coverage of the LCOV entries under the
configured `dirs` (default `lib/`) is below `min_percent` (default 80.0).
An entry counts when its path equals a listed directory or starts with it
followed by `/`; entries outside the project root shall never count. With
`per_file: true`, each file below the minimum shall additionally be
reported.

### 11.3 complexity

Fails methods whose cyclomatic complexity exceeds `max_complexity`
(default 10). When `count_lambdas` is false (default true), branches
inside lambdas shall not count towards the enclosing method.

### 11.4 method_size

Fails methods longer than `max_lines` (default 60) or with more than
`max_params` parameters (default 6). Constructors shall be checked only
for parameter count.

### 11.5 nesting

Fails methods whose maximum block nesting level exceeds `max_nesting`
(default 5). The method body block counts as level 1; every nested
block or control-flow statement (`if`, `for`, `while`, `do`, `switch`,
`try`/`catch`) adds one.

### 11.6 class_size

Fails classes with more than `max_methods` (default 25) concrete
methods or a weighted-methods-per-class sum (total cyclomatic
complexity over all methods) above `max_wmc` (default 80). Top-level
functions are not attributed to any class.

### 11.7 weight_of_class

Skipped unless enabled (default disabled). Fails public classes whose
ratio of public instance fields to public instance members exceeds
`max_weight` (default 0.33). Static members are not counted; classes
without public fields are never flagged. Honors `exclude` globs.

### 11.8 unused_code

Flags private declarations never referenced by any simple identifier in
the analyzed sources: top-level `_functions`, `_classes`, and private
members (`_fields`, `_methods`) of public classes. References are
counted lexically on unresolved ASTs. Files matching the gate's
`exclude` list (default generated files and `bin/**`) are ignored
entirely — both their declarations and their references.

### 11.9 unused_files

Flags files under `dirs` (default `lib`) that are never imported by any
analyzed file. A file containing a top-level `main` function and
`part of` files are never reported. Imports resolve to project-relative
paths: relative URIs against the importing file's directory,
`package:<self>/...` against `lib/`; external packages never count.
Files matching the gate's `exclude` list (default generated files) are
skipped.

### 11.10 banned_imports

Enforces architectural rules `{from, forbid, message}`. For every file
matching the rule's `from` glob, each import whose URI — or, for
relative and `package:<self>` imports, its resolved project-relative
path — matches any `forbid` glob is a violation. The optional
`message` is appended to the violation. With no rules the gate passes.

### 11.11 duplication

Detects exact copy-paste duplicates across Dart source files. Each file is
tokenized with `package:analyzer` (comments and synthetic tokens are
ignored). A duplicated block is a sequence of tokens that appears at least
twice, is at least `min_tokens` long (default 50) and spans at least
`min_lines` source lines (default 5). The gate reports each file whose
percentage of duplicated lines exceeds `threshold` (default 1.0). Files
matching the gate's `exclude` list (default generated files and `test/**`)
are skipped.

### 11.12 file_naming

Flags Dart files whose names indicate a mechanical split instead of a
domain boundary. A file is flagged when its stem (name without the `.dart`
extension), lower-cased, either ends in digits preceded by a letter or
underscore (`jira_batch1`, `report2`, `day_1`, `configv3`) or equals a
generic dumping-ground stem (`common`, `core`, `general`, `helper`,
`helpers`, `misc`, `shared`, `stuff`, `temp`, `tmp`, `types`, `util`,
`utils`, `utilities`, `utility`, `various`). Whole technical stems ending
in digits (`base64`, `sha256`, `utf8`, `oauth2`, ...) are accepted by
default; additional stems may be allowlisted via `allow` (matched
case-insensitively against the whole stem). Files matching the gate's
`exclude` list (default generated files and `test/**`) are skipped.

### 11.13 magic_constants

Flags magic literals in Dart files. Two checks: (a) hex color integer
literals (`0xRRGGBB` / `0xAARRGGBB`) outside named constant
declarations — lines that initialize a `const` variable (including
constructor/method call arguments in the initializer) are exempt;
(b) numeric or string literals (including adjacent strings) whose value
repeats at least `min_duplicates` (default 3) times in one file — every
occurrence is reported. String literals shorter than `min_length`
(default 4) are ignored. `flag_hex_colors: false` disables check (a).
Files matching the gate's `exclude` list (default generated files and
`test/**`) are skipped.

### 11.14 public_docs

Fails public declarations without dartdoc: classes, mixins, enums,
extension types, named extensions, top-level functions and variables, and
public methods and fields. `@override` members, members of private
containers, constructors and files under `exclude` (default `test/**`)
shall be exempt.

### 11.15 hardcoded_strings

Skipped for non-Flutter projects. Flags string literals containing Latin
or Cyrillic letters passed to `Text(...)` or to the parameters in
`check_params`, including interpolated strings with literal letter
segments. Lines marked with the configured ignore marker (on the same or
the previous line) and files containing `// l10n:ignore-file` within the
first 5 lines shall be exempt. When ARB files exist under `lib/`,
`l10n.<key>` references missing from `app_en.arb` shall be flagged.

### 11.16 accessibility

Skipped for non-Flutter projects. Requires `tooltip` on `IconButton`,
`semanticLabel` on `Image`, and `semanticsLabel` or a wrapping
`Semantics` widget on `GestureDetector`/`InkWell`, for the widget types
in `require_label_for`.

### 11.17 golden

Skipped for non-Flutter projects and for projects without widgets.
Widgets are public classes in `widget_dirs` extending `StatelessWidget`,
`StatefulWidget`, `ConsumerWidget` or `ConsumerStatefulWidget`, excluding
`exclude_widgets`. A widget is covered when a test under `test_dirs` both
invokes `matchesGoldenFile` and references the widget by type or imports
the widget's file. The gate fails when coverage is below
`min_widget_coverage` (default 80.0).

## 12. Baseline

`check --save-baseline` shall run all enabled gates and write every
current violation to `.crap-baseline.json` keyed by gate id, file,
line and message; the command exits 0. `check --baseline` shall strip
violations covered by the baseline file before deciding the run
outcome: a gate fails only when it has at least one violation not in
the baseline. A missing baseline file is not an error and leaves the
run unchanged.

## 13. Threshold

The default CRAP threshold shall be `8.0`, overridable in the config and
via `--threshold`. When the maximum numeric CRAP value exceeds the
threshold, the tool shall print
`CRAP threshold exceeded: <max> > <threshold>` to stderr and exit with
threshold-failure status. When no numeric CRAP values exist, the maximum
shall be treated as `0.0`.

## 13. Exit Codes

- `0` — success, including empty selections and runs where nothing
  failed.
- `1` — CLI usage error, configuration error, hook/CI installation error,
  or a failed test run in `check --run-tests`.
- `2` — CRAP threshold exceeded, at least one quality gate failed, or the
  profile threshold was exceeded.

## 14. Hook and CI Installation

### 14.1 Git Hook

The hook shall be a POSIX sh script with a managed block. The block shall
prefer a `crap4dart` binary from `PATH`, fall back to
`dart run bin/crap4dart.dart` when present, and exit 0 with a warning
when neither is available. When `coverage.run_tests` is true, the test
suite with coverage shall run before the check.

An existing hook containing a managed block shall have the block
replaced. An existing foreign hook shall cause an error unless `--force`
is given, in which case the block shall be appended and the existing
content preserved. A project without `.git` shall be an error.

### 14.2 CI Workflow

`install --ci` shall create `.github/workflows/quality.yml` running
format check, static analysis, tests with coverage, `crap4dart check
--all` and `crap4dart analyze` on push and pull request. Flutter projects
shall get a Flutter-based workflow; pure Dart projects a Dart-based one.
An existing file shall not be overwritten without `--force`.

## 15. Error Handling

The tool shall fail fast on invalid command-line usage, invalid
configuration, unreadable source files and parser failures. Warnings
about missing coverage data shall not by themselves fail an `analyze`
run.

## 16. Non-Goals

The current implementation is not required to support:

- semantic (resolved-AST) analysis of Flutter widgets
- automatic fixing of violations
- watch mode
- machine mutation of source code

## 17. Conformance

An implementation conforms to this specification if it satisfies the CLI,
file selection, coverage, parsing, CRAP computation, reporting,
configuration, gating, installation and exit-code rules above for Dart
and Flutter projects.
