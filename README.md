# crap4dart

CRAP metric analyzer and configurable quality gates for Dart and Flutter
projects.

[![Quality](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml/badge.svg)](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml)
[![pub package](https://img.shields.io/pub/v/crap4dart.svg)](https://pub.dev/packages/crap4dart)
![CRAP](badges/crap.svg)

## What is CRAP?

CRAP (Change Risk Anti-Patterns) combines cyclomatic complexity with test
coverage to score the risk of changing a method:

```
CRAP = CC² · (1 − coverage)³ + CC
```

- `CC` — cyclomatic complexity of the method
- `coverage` — line coverage fraction of the method (`0.0..1.0`)

A method that is both complex and untested gets a high score. Scores above
the default threshold of **8.0** fail the analysis.

crap4dart is a Dart port of the Java tool
[crap4java](https://github.com/unclebob/crap4java).

## Features

- **CRAP analysis** per method, combining complexity and LCOV coverage
- **21 quality gate**: `loc`, `test_coverage`, `golden`,
  `hardcoded_strings`, `accessibility`, `complexity`, `method_size`,
  `nesting`, `class_size`, `weight_of_class`, `unused_code`,
  `unused_files`, `banned_imports`, `public_docs`, `duplication`,
  `file_naming`, `magic_constants`, `broken_goldens`, `test_assertions`,
  `folder_structure`, `external`
- **Gate framework**: per-path thresholds (`entries`), warning
  severity, baseline mode, opt-in ignore markers
- **Configuration** via `crap4dart.yaml` with strict validation
- **Pre-commit hook** installation (`check --staged` on every commit)
- **GitHub Actions workflow** template (`crap4dart install --ci`)
- **JSON output** for CI integration (`--format json`)
- **Branch coverage** (BRDA records) next to line coverage

## Installation

Published on pub.dev:

```sh
dart pub global activate crap4dart
```

From the repository:

```sh
dart pub global activate -sgit https://github.com/IstiN/crap4dart.git
```

## Usage

### analyze (default command)

Computes CRAP scores and prints a report sorted by worst score first.

```sh
crap4dart                                  # analyze lib/ and bin/
crap4dart analyze lib/src/foo.dart         # explicit files/directories
crap4dart analyze --changed                # changed files (git working tree)
crap4dart analyze --threshold 10.0         # override the config threshold
crap4dart analyze --lcov build/lcov.info   # override the coverage file
crap4dart analyze --run-tests              # run tests with coverage first
crap4dart analyze --format json            # machine-readable output
crap4dart analyze --diff                   # only methods touched since HEAD
crap4dart analyze --diff-base main         # only methods touched since main
```

### check

Runs the quality gates enabled in `crap4dart.yaml`.

```sh
crap4dart check                            # all files under lib/ and bin/
crap4dart check --changed                  # changed files only
crap4dart check --staged                   # staged files only (pre-commit)
crap4dart check --only loc,complexity      # selected gates
crap4dart check --skip public_docs         # all but some gates
crap4dart check --run-tests                # run tests with coverage first
crap4dart check --format json              # machine-readable output
crap4dart check --diff                     # only lines changed since HEAD
crap4dart check --diff-base main           # only lines changed since main
```

### init

Creates a fully commented default `crap4dart.yaml`:

```sh
crap4dart init            # refuses to overwrite an existing file
crap4dart init --force    # overwrite
```

### install

Installs the pre-commit hook and, optionally, the CI workflow:

```sh
crap4dart install                    # pre-commit hook only
crap4dart install --ci               # hook + .github/workflows/quality.yml
crap4dart install --hook pre-push    # different hook name
crap4dart install --force            # merge into an existing foreign hook
```

### profile

Instruments every method in `lib/` with a `Stopwatch`, runs the test suite
against the instrumented copy, and reports precise per-method timing.
Unlike VM-sampling profilers, timing is deterministic and exact
(microseconds, not statistical samples).

```sh
crap4dart profile                          # profile all sources, run all tests
crap4dart profile test/collab/             # run only tests in this directory
crap4dart profile --name "golden"          # run only tests matching a name
crap4dart profile --tags "integration"     # run only tests with these tags
crap4dart profile --exclude-tags "slow"    # exclude tagged tests
crap4dart profile --threshold 10.0         # warn on methods slower than 10ms
crap4dart profile --top 50                 # show top 50 slowest methods
crap4dart profile --format json            # machine-readable output
crap4dart profile --config my.yaml         # use a non-default config file
crap4dart profile --diff                   # only methods touched since HEAD
crap4dart profile --diff-base main         # only methods touched since main
```

Example console output:

```
Profile Report (142 methods, total 1234.56ms)

  TOTAL(ms)  %      CALLS  MEAN(µs)  MAX(µs)  @60fps(ms)  METHOD                      FILE:LINE
      45.20  3.7%    142   318.3     2890     19.10       CrapAnalyzer.analyzeMethod  lib/src/crap/crap_analyzer.dart:88
      32.10  2.6%    500   64.2      410       3.85       MethodExtractor.extract     lib/src/analysis/method_extractor.dart:34
      28.70  2.3%     88   326.1     2100     19.57       LcovParser.parseFile        lib/src/coverage/lcov_parser.dart:21

Threshold: 10.00ms — 3 methods exceed
```

Columns:

- **TOTAL(ms)** — total wall-clock time across all calls.
- **%** — share of the total profiled time.
- **CALLS** — number of invocations.
- **MEAN(µs)** — average time per call (microseconds).
- **MAX(µs)** — slowest single call (microseconds).
- **@60fps(ms)** — estimated per-frame cost if the method were called every
  frame at 60 fps (`MEAN × 60`). Highlights methods that are cheap per-call
  but dangerous in a rebuild hot path.

During profiling a temporary `.crap_profile_temp/` directory is created and
cleaned up automatically. Set the `CRAP_PROFILE_DEBUG` environment variable
to keep it for debugging.

The `analyze`, `check`, `install` and `profile` commands accept
`--config <path>` to use a non-default config file.

### Exit codes

| Code | Meaning                                             |
| ---- | --------------------------------------------------- |
| `0`  | Success (including empty selections and all-passed) |
| `1`  | Usage or configuration error                        |
| `2`  | CRAP/profile threshold exceeded or a gate failed    |

## Diff mode (ratchet)

On a legacy codebase the gates often fail on old code you cannot fix all
at once. Diff mode ratchets quality in: it requires quality only for code
changed since a git base.

```sh
crap4dart check --diff                 # changes against HEAD
crap4dart check --diff-base main       # changes against a branch
crap4dart analyze --diff
```

- `check --diff` runs the gates on the changed files and then keeps only
  violations on added/changed lines (file-level violations, e.g. `loc`,
  survive only for files with real changes). Gate lines are marked with
  `(diff mode)`.
- `analyze --diff` reports only methods whose line range intersects the
  added lines, and the report header/JSON notes the diff base.
- `--diff` defaults to base `HEAD` (staged + unstaged changes);
  `--diff-base <ref>` picks any ref. Untracked files are not part of
  `git diff` — stage new files to include them. `--diff` cannot be
  combined with `--changed`/`--staged`.
- The `test_coverage` aggregate is not meaningful in diff mode; the
  file-level rule above applies.

## Configuration

`crap4dart init` generates this fully commented default config:

```yaml
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
  # Require dartdoc comments on the public API.
  public_docs:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - 'test/**'

# CPU profiling settings ("profile" command).
profile:
  # Enable profiling; when false, "profile" exits immediately.
  enabled: true
  # Warn on methods whose total time exceeds this value (milliseconds).
  # Omit to disable the threshold check.
  threshold_ms: 10.0
  # Maximum number of methods to list (sorted by total time).
  top: 20
```

The config file is optional — without it, the defaults above apply. Partial
configs are merged with defaults per key. Unknown keys, unknown gate ids and
wrongly typed values are rejected with an error naming the offending key.

The top-level `sources` key selects the directories scanned by `analyze`
and `check` in their default (all-files) mode — default `[lib, bin]`. Set
`sources: [lib, bin, tool, test]` to cover Dart files in any layout.

The top-level `exclude` key (default `[]`) drops files matching the given
glob patterns (matched project-relative) in every selection mode —
default discovery, `--changed`, `--staged`, `--diff` and explicit paths.

`crap.count_lambdas` and `gates.complexity.count_lambdas` (both default
`true`, independently) control whether branches inside lambdas count
towards the enclosing method's cyclomatic complexity. Setting them to
`false` is useful for test-heavy code full of `test(...)` closures.

The `gates.test_coverage.dirs` option (default `[lib]`) scopes the coverage
aggregate to the LCOV entries under the listed directories.

### Test code quality

Add `test` to `sources` to hold your test code to the same bar:

```yaml
sources: [lib, bin, test]
```

The `loc`, `complexity` and `method_size` gates then check test files too
(`public_docs` keeps excluding `test/**` by default, and
`gates.test_coverage.dirs` keeps them out of the coverage aggregate unless
you add `test` there as well). This repository dogfoods exactly this setup.

## Quality gates

Each gate can be turned off with `enabled: false` in the config. Every
gate also accepts two framework keys:

- `severity: error | warning` — a `warning` gate reports its violations
  (marked `[WARN]`) but does not fail the run. Useful for adopting a
  gate on a legacy codebase.
- `ignorable: true` — opts this gate into `// crap:ignore` line
  comments and `// crap:ignore-file` file markers. **Off by default**:
  suppression is never allowed unless you explicitly enable it.

`loc`, `complexity` and `method_size` support per-path threshold
overrides via `entries` (the first entry whose `paths` glob matches the
file wins):

```yaml
gates:
  loc:
    max_lines: 800
    entries:
      - max_lines: 2000        # legacy code gets a breather
        paths: ['lib/legacy/**']
      - max_lines: 400         # new code is held to a higher standard
        paths: ['lib/src/**']
```

- **loc** — fails files longer than `max_lines` (default 800), honoring the
  `exclude` globs (generated files are excluded by default).
- **test_coverage** — computes total line coverage from the LCOV entries
  under `dirs` (default `[lib]`) and fails below `min_percent` (default
  80.0). With `per_file: true`, every file below the minimum is reported
  individually. When no coverage file exists, the gate fails if
  `coverage.required` is true and skips otherwise.
- **golden** (Flutter) — requires that at least `min_widget_coverage`
  percent of widget classes (extending `StatelessWidget`/`StatefulWidget`/
  `ConsumerWidget`/`ConsumerStatefulWidget`) are referenced by a test that
  calls `matchesGoldenFile`. Skipped for non-Flutter projects.
- **hardcoded_strings** (Flutter) — flags string literals (Latin or
  Cyrillic) passed to `Text(...)` or to the parameters in `check_params`.
  Suppress per line with the `ignore_marker` comment or per file with
  `// l10n:ignore-file` in the first 5 lines. When ARB files exist under
  `lib/`, `l10n.<key>` references missing from `app_en.arb` are flagged too.
  Skipped for non-Flutter projects.
- **accessibility** (Flutter) — requires `tooltip` on `IconButton`,
  `semanticLabel` on `Image`, and `semanticsLabel` (or a wrapping
  `Semantics`) on `GestureDetector`/`InkWell`. Skipped for non-Flutter
  projects.
- **complexity** — fails methods whose cyclomatic complexity exceeds
  `max_complexity` (default 10).
- **method_size** — fails methods longer than `max_lines` (default 60) or
  with more than `max_params` parameters (default 6). Constructors are
  checked only for parameter count.
- **nesting** — fails methods whose maximum block nesting level exceeds
  `max_nesting` (default 5). The method body counts as level 1; every
  nested block or control-flow statement adds one. Catches complexity
  dodging via deeply nested early-return chains.
- **class_size** — fails classes with more than `max_methods` (default
  25) concrete methods or a weighted-methods sum (WMC, total cyclomatic
  complexity of all methods) above `max_wmc` (default 80). Catches
  god-classes assembled from many small methods that each pass the
  `complexity` gate.
- **weight_of_class** — fails classes whose ratio of public instance
  fields to public instance members exceeds `max_weight` (default 0.33):
  classes revealing more data than behavior. Disabled by default —
  data/model classes are legitimate.
- **duplication** — detects exact copy-paste token blocks across Dart
  source files. A block counts when it is at least `min_tokens` tokens
  (default 50) and `min_lines` lines (default 5) long. The gate fails a
  file when its duplicated line percentage exceeds `threshold` (default
  1.0). Generated files and `test/**` are excluded by default.
- **file_naming** — forbids mechanical file names that indicate code was
  split to dodge the `loc` gate instead of along domain boundaries:
  numeric suffixes (`jira_batch1.dart`, `report2.dart`, `configv3.dart`)
  and generic dumping-ground names (`utils.dart`, `helpers.dart`,
  `misc.dart`, `common.dart`). Whole technical stems like `base64`,
  `sha256` or `utf8` are allowed by default; add more via the `allow`
  list (matched case-insensitively against the whole file name).
  Generated files and `test/**` are excluded by default.
- **broken_goldens** — scans golden PNG files under `dirs` (default
  `test`) for rendered error artifacts: overflow stripes (the yellow/
  black RenderFlex pattern), build-error screens (the dark-red
  `ErrorWidget` background) and broken icon placeholders (the tofu
  box-with-an-X of a failed image load, detected by its bordered X
  shape). Golden tests do not fail on these — the broken frame gets
  captured (often permanently, via `--update-goldens`), so the pixels
  are the only witness. For standard `Image.asset`/`Image.network`
  failures you can additionally fail the TEST itself:
  `crap4dart goldens --write` drops in a `guardGoldens` helper that
  turns image-load errors into failing assertions (widgets with their
  own fallback icons emit no error — the pixel detector still covers
  those).
- **test_assertions** — fails `test()`/`testWidgets()` bodies with
  fewer than `min_assertions` (default 1) assertion calls (`expect`,
  `expectLater`, `fail`, `throwsA`, ...). A test without assertions
  runs green and verifies nothing — a typical AI placeholder.
- **folder_structure** — flags directories accumulating more than
  `max_loose_files` (default 0) `.dart` files directly, instead of
  organizing code into feature packages (the flat-file sprawl agents
  leave behind: `lib/src/a.dart`, `lib/src/b.dart`, ...).
- **external** — wraps external static-analysis tools (detekt for
  Kotlin, ktlint, swiftlint, anything emitting a Checkstyle XML
  report) as rules `{id, executable, arguments}`; `{report}` in the
  arguments is replaced with the report path, and every finding
  becomes a standard violation — severity, baseline, ignore markers
  and diff mode work on top of the wrapped tool. With no rules the
  gate passes. This is how Kotlin/Swift code in a Flutter monorepo
  joins the same `crap4dart check` run.
- **magic_constants** — flags magic literals: hex color values
  (`0xFFFF5733`, `0x00AAFF`) used outside `const` declarations, and any
  numeric or string literal repeating at least `min_duplicates`
  (default 3) times in one file — every occurrence is reported with a
  nudge to extract a named constant. `flag_hex_colors` can disable the
  color check; strings shorter than `min_length` (default 4) are
  ignored. Generated files and `test/**` are excluded by default.
- **public_docs** — requires dartdoc on the public API: classes, mixins,
  enums, extension types, named extensions, top-level functions and
  variables, public methods and fields. `@override` members and members of
  private classes are exempt; files under `exclude` (default `test/**`)
  are skipped.
- **unused_code** — flags private declarations (`_functions`, `_classes`,
  private class members) never referenced in the analyzed sources. Dead
  code is a typical leftover of AI-assisted refactoring. References are
  counted on unresolved ASTs (lexical identifiers).
- **unused_files** — flags files under `dirs` (default `[lib]`) that are
  never imported by any analyzed file. Files with a `main()` and
  `part of` files are never reported.
- **banned_imports** — enforces architectural boundaries with rules of
  `{from, forbid, message}`: imports matching a `forbid` glob are banned
  in files matching `from` (e.g. `lib/ui/**` must not import
  `**/data/**` or `dart:io`). Import URIs and their project-relative
  resolved paths are both matched. With no rules the gate passes.

## Baseline

On a legacy codebase a new gate can fail on hundreds of pre-existing
violations. Instead of lowering thresholds, record them once and fail
only on new ones:

```sh
crap4dart check --save-baseline   # record current violations to .crap-baseline.json
crap4dart check --baseline        # pass unless NEW violations appear
```

The baseline keys violations by gate + file + line + message; a
violation only fails the run when it is not covered by the baseline.
Re-run `--save-baseline` after cleanup to ratchet it down.

## Pre-commit hook

`crap4dart install` writes a `pre-commit` hook that runs
`crap4dart check --staged` on every commit. The hook script lives in a
marked block (`# >>> crap4dart >>>` ... `# <<< crap4dart <<<`) so repeated
installations only update the managed block. An existing foreign hook is
never overwritten: installation fails unless `--force` is given, in which
case the block is appended and the existing content is preserved.

To bypass the hook for a single commit:

```sh
git commit --no-verify
```

## CI

`crap4dart install --ci` generates `.github/workflows/quality.yml`: a
"Quality" workflow that runs on push and pull request — format check,
`dart analyze`, tests with coverage, and finally `crap4dart check --all`
and `crap4dart analyze`. Flutter projects get a Flutter-based workflow
(`subosito/flutter-action`, `flutter test --coverage`); pure Dart projects
get a Dart-based one (`dart-lang/setup-dart`, `format_coverage`).

## CRAP badge

`analyze --badge <path>` writes a local shields.io-style SVG badge with the
maximum CRAP score — no external services involved:

```sh
crap4dart analyze --badge badges/crap.svg
```

Embed it in your README:

```md
![CRAP](badges/crap.svg)
```

Colors: green when the max CRAP is at or below the threshold, yellow up to
twice the threshold, red beyond that, and grey `N/A` when no coverage data
is available. The badge is written even when the analysis fails the
threshold (exit 2), so it always reflects the actual state. Commit
`badges/crap.svg` and regenerate it in CI or a pre-push hook to keep it
fresh.

## JSON output

`analyze`, `check` and `profile` support `--format json`. Stdout then
contains only valid JSON (warnings still go to stderr), and exit codes are
unchanged, so CI can both parse the report and rely on the exit code.

analyze:

```json
{
  "command": "analyze",
  "threshold": 8.0,
  "maxCrap": 12.0,
  "passed": false,
  "methods": [
    {
      "file": "lib/sample.dart",
      "line": 1,
      "class": "(top-level)",
      "method": "risky",
      "complexity": 3,
      "lineCoverage": 0.0,
      "branchCoverage": null,
      "crap": 12.0
    }
  ]
}
```

check:

```json
{
  "command": "check",
  "passed": false,
  "gates": [
    {"id": "loc", "status": "passed", "summary": "...", "violations": []},
    {"id": "golden", "status": "skipped", "reason": "not a Flutter project"}
  ]
}
```

profile:

```json
{
  "command": "profile",
  "totalMicros": 1234567,
  "thresholdMs": 10.0,
  "passed": false,
  "methods": [
    {
      "file": "lib/src/crap/crap_analyzer.dart",
      "line": 88,
      "class": "CrapAnalyzer",
      "method": "analyzeMethod",
      "calls": 142,
      "totalMicros": 45200,
      "minMicros": 80,
      "maxMicros": 2890,
      "meanMicros": 318.3
    }
  ]
}
```

## Development

```sh
dart pub get
dart test
dart analyze
```

This repository dogfoods its own gates: the pre-commit hook runs
`crap4dart check --staged`, and the generated `quality.yml` workflow runs
the full `check`/`analyze` pipeline on every push.

## License

MIT
