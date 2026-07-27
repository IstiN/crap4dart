# crap4dart

CRAP metric analyzer and configurable quality gates for Dart and Flutter
projects.

[![Quality](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml/badge.svg)](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml)
[![pub package](https://img.shields.io/pub/v/crap4dart.svg)](https://pub.dev/packages/crap4dart)
_(pub.dev publication pending)_

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
- **8 quality gates**: `loc`, `test_coverage`, `golden`,
  `hardcoded_strings`, `accessibility`, `complexity`, `method_size`,
  `public_docs`
- **Configuration** via `crap4dart.yaml` with strict validation
- **Pre-commit hook** installation (`check --staged` on every commit)
- **GitHub Actions workflow** template (`crap4dart install --ci`)
- **JSON output** for CI integration (`--format json`)
- **Branch coverage** (BRDA records) next to line coverage

## Installation

Published on pub.dev (pending):

```sh
dart pub global activate crap4dart
```

From the repository (works today):

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

The `analyze`, `check` and `install` commands accept `--config <path>` to
use a non-default config file.

### Exit codes

| Code | Meaning                                             |
| ---- | --------------------------------------------------- |
| `0`  | Success (including empty selections and all-passed) |
| `1`  | Usage or configuration error                        |
| `2`  | CRAP threshold exceeded or a quality gate failed    |

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
  # Require dartdoc comments on the public API.
  public_docs:
    enabled: true
    # Glob patterns excluded from the gate.
    exclude:
      - 'test/**'
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

Each gate can be turned off with `enabled: false` in the config.

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
- **public_docs** — requires dartdoc on the public API: classes, mixins,
  enums, extension types, named extensions, top-level functions and
  variables, public methods and fields. `@override` members and members of
  private classes are exempt; files under `exclude` (default `test/**`)
  are skipped.

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

## JSON output

Both `analyze` and `check` support `--format json`. Stdout then contains
only valid JSON (warnings still go to stderr), and exit codes are
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
