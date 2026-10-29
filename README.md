# crap4dart

CRAP metric analyzer and configurable quality gates for Dart and Flutter
projects.

[![Quality](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml/badge.svg)](https://github.com/IstiN/crap4dart/actions/workflows/quality.yml)
[![pub package](https://img.shields.io/pub/v/crap4dart.svg)](https://pub.dev/packages/crap4dart)
![CRAP](badges/crap.svg)
![memory churn](badges/memory.svg)

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
- **30 quality gates**: `loc`, `test_coverage`, `golden`,
  `hardcoded_strings`, `accessibility`, `complexity`, `method_size`,
  `nesting`, `record_named_fields`, `inline_record_types`,
  `record_size`, `class_size`, `weight_of_class`, `unused_code`,
  `unused_files`, `banned_imports`, `public_docs`, `duplication`,
  `file_naming`, `magic_constants`, `scattered_constants`, `broken_goldens`,
  `test_assertions`, `folder_structure`, `external`, `mutation`,
  `similarity`, `string_hazards`, `identical_branches`,
  `enum_name_contract`
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

Prebuilt native binaries (no Dart SDK needed — Linux x64/arm64) are
published on every tagged release:

```sh
curl -LO https://github.com/IstiN/crap4dart/releases/latest/download/crap4dart-linux-x64
chmod +x crap4dart-linux-x64 && ./crap4dart-linux-x64 --version
```
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
Profile Report (142 methods, total 1.23s)

  TOTAL    SELF    %      CALLS  MEAN(µs)  MAX(µs)  @60fps(ms)  METHOD                      FILE:LINE
  45.20ms  12.10ms  3.7%    142   318.3     2890     19.10       CrapAnalyzer.analyzeMethod  lib/src/crap/crap_analyzer.dart:88
  32.10ms   9.80ms  2.6%    500   64.2      410       3.85       MethodExtractor.extract     lib/src/analysis/method_extractor.dart:34
  28.70ms   8.30ms  2.3%     88   326.1     2100     19.57       LcovParser.parseFile        lib/src/coverage/lcov_parser.dart:21

Threshold: 10.00ms — 3 methods exceed
```

Columns:

- **TOTAL** — total wall-clock time across all calls (inclusive of nested
  profiled calls), rendered with adaptive units (`82.50ms`, `13.89s`,
  `22.50m`, `13.89h`) so extreme call counts (tens of billions) keep the
  column compact.
- **SELF** — time spent in the method's own body: TOTAL minus nested
  profiled calls (flamegraph self-time). Ranks hot code by actual CPU
  burn, not by how many callers it fans out into.
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

### memory

Runs the test suite and attributes allocation volume and GC activity
to individual tests: which tests allocate the most and which grow the
old generation without freeing it (leak suspects).

- **Dart projects** run under `dart --verbose_gc` (concurrency 1):
  churn = reclaimed new-gen MB per GC row (deterministic across runs);
  attribution uses each isolate's own clock (GC rows count from
  isolate start; the suite event time is the same zero);
  loading/teardown GCs land in a separate unattributed bucket.
- **Flutter projects** (auto-detected, or `--engine flutter`) ride
  `flutter test --verbose -j1`: every traced `flutter_tester` spawn is
  re-run with the VM Service enabled, driven over package:test's
  remote protocol, and measured through the VM's allocation profile —
  per-test ALLOCATED bytes exactly, plus GC events and old-gen growth.
  Every file executes twice (the tool's run plus the measured copy).
  The VM stream has no reclaimed-new-gen counters, so there
  `churnNewMb`/`totalChurnMb` are JSON `null` (plus
  `churnAvailable: false`) — use `allocatedMb`/`totalAllocatedMb` as
  the churn metric on both engines; badges follow the same rule.

```sh
crap4dart memory                  # run the suite, print both leaderboards
crap4dart memory --top 5          # shorter leaderboards
crap4dart memory --format json    # machine-readable report (JSON-only stdout)
crap4dart memory test/foo_test.dart          # measure a subset (targeted A/B)
crap4dart memory --badge badges/memory.svg   # shields-style churn badge
```

Informational only — always exits 0 on a successful run. Thresholds
and the `memory_pressure` gate come with baseline machinery later:
raw GC counts are machine-dependent, allocated MB are not.

### similarity

Scans any text corpus (markdown docs, source files) for file-level
near-duplicates — the exploration tool for tuning the `similarity` gate
before enabling it. Two files are *similar* when their 8-token shingle
sets overlap enough: Jaccard (overall overlap) or containment (the
smaller file largely inside the bigger one). Comments, imports, code
fences and literal values are normalized away, so only real content
counts.

```sh
crap4dart similarity                          # config dirs/include, console report
crap4dart similarity docs/                    # scan one directory
crap4dart similarity --jaccard 0.5            # threshold overrides
crap4dart similarity --min-shingles 30        # smaller files are skipped
crap4dart similarity --include '**/*.md' --include '**/*.dart'
crap4dart similarity --format json            # machine-readable clusters
```

### `reorder`

`crap4dart reorder [paths]` rewrites Dart files so class members follow
the canonical Dart/Flutter order: `static const` constants, static
fields, instance fields, constructors, static methods, getters and
setters, public methods, private methods. Members of the same category
keep their relative order — it is a stable partition, never an
alphabetical sort.

```sh
crap4dart reorder              # reorder everything under lib/
crap4dart reorder test/lib/    # explicit paths
crap4dart reorder --dry-run    # list files that would change; exit 2 if any
```

The transform is deterministic: the same input always produces the same
output, already-canonical files are left byte-identical, and running it
twice changes nothing. Doc comments, annotations and directly-preceding
`//` notes move with their member. Enums: the constants block (value
order) is never touched, while the member section after the constants
is reordered like a class body. `--dry-run` is the CI/pre-commit form:
it exits 2 when any file would change.

The `similarity` **gate** (in `check`) turns this into CI enforcement:
one violation per clustered file, baseline-compatible so existing
clusters can be grandfathered while new ones fail the run.

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
  # String literal hazards: escaped interpolations rendering literally,
  # raw RegExp patterns with an escaped anchor, and regex anchors in
  # literal String patterns of replaceFirst/replaceAll/split.
  string_hazards:
    enabled: true
    severity: warning
  # Copy-paste-edit family: duplicate conditions/bodies in one
  # if/else-if chain, duplicate operands in one boolean chain,
  # identical ternary branches, duplicate positional call arguments,
  # duplicate catch bodies — all compared by canonical form.
  identical_branches:
    enabled: true
    severity: warning
  # Flag built-in .name/.index contracts inside enum bodies (persisted
  # values drift when an identifier is renamed).
  enum_name_contract:
    enabled: true
    severity: warning
  # Limit cyclomatic complexity per method.
  complexity:
    enabled: true
    # Maximum allowed complexity.
    max_complexity: 10
    # Which metric max_complexity applies to: 'cyclomatic' (default) or
    # 'cognitive' (SonarSource-style, nesting-weighted; flat else-if
    # chains stay cheap).
    # metric: cyclomatic
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
    # What violations are reported for: 'percentage' (per-file percent)
    # or 'clones' (PMD CPD style — one violation per clone group with
    # all its locations).
    # report: percentage
    # Minimum number of tokens in a block to count as duplication.
    min_tokens: 50
    # Minimum number of lines in a block to count as duplication.
    min_lines: 5
    # Rename locally declared identifiers consistently before hashing so
    # renamed (Type-2) clones are detected; API names stay visible.
    # ignore_locals: false
    # Replace string and numeric literals with placeholders before
    # hashing so clones differing only in literal values are detected.
    # ignore_literals: false
    # Replace ALL identifiers with one placeholder before hashing
    # (structure-only matching, CPD --ignore-identifiers).
    # ignore_identifiers: false
    # Exclude import/export/part directives from tokenization.
    # ignore_imports: false
    # Skip files whose token stream equals an earlier file's, so a
    # copied file is reported once (CPD --skip-duplicate-files).
    # skip_duplicate_files: false
    # Glob patterns excluded from the gate.
    exclude:
      - '**.g.dart'
      - '**.freezed.dart'
      - '**.mocks.dart'
    # Extra file/directory paths scanned for duplication (cross-module
    # checks), unioned with the analyzed source set.
    # sources:
    #   - 'flutter_app/lib'
    #   - 'packages/fa_ui/lib'
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
  # Mutation testing: mutate one operator/literal at a time and re-run
  # the test suite per mutant. Expensive — disabled by default.
  mutation:
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
    operators: [arithmetic, boundary, equality, logical, boolean,
                constant, unary]
    # Digest-incremental cache: replay kills of unchanged methods.
    cache: true
    # Per-mutant test invocation args (`dart <args...>`).
    test_args: ['test']
    # Narrow each mutant's run to the derived test file(s) of the
    # mutated file; scoped survivors are re-confirmed with test_args.
    scope_tests: false
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
  comments and `// crap:ignore-file` file markers, plus the
  gate-specific `// ignore:<id>` and `// ignore-file:<id>` (one rule
  per marker, stacked markers combine; empty id = everything).
  **Off by default**:
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
- **complexity** — fails methods whose complexity exceeds `max_complexity`
  (default 10). `metric` chooses between `cyclomatic` (default) and
  `cognitive` (SonarSource-style, nesting-weighted — flat `else if`
  chains stay cheap, nested ones pay extra; `&&`/`||` sequences count
  once per run). Cyclomatic counting covers switch expressions and
  pattern guards; CRAP always uses cyclomatic complexity.
- **method_size** — fails methods longer than `max_lines` (default 60) or
  with more than `max_params` parameters (default 6). Constructors are
  checked only for parameter count.
- **nesting** — fails methods whose maximum block nesting level exceeds
  `max_nesting` (default 5). The method body counts as level 1; every
  nested block or control-flow statement adds one. `else if` chains stay
  flat (a chained `if` keeps its originating `if`'s level), while an
  `if` inside an `else` block keeps adding levels. Catches complexity
  dodging via deeply nested early-return chains.
- **record_named_fields** — flags record type annotations with unnamed
  fields (`(int, int)`) and `.$N` positional field accesses anywhere;
  both are the fingerprint of undocumented shapes. Name the fields
  (`({int x, int y})`), destructure, or use a class. Record values
  (literals, destructuring patterns) stay legal; record type aliases
  are not scanned. Warning severity by default.
- **inline_record_types** — flags inline record type annotations in
  signatures (return types, parameters, nested in type arguments):
  consumers should reference one named declaration, not diff shapes
  field-by-field. Declare a `typedef` (or a class when nominal
  identity is needed). A function-type typedef blesses nothing.
  Warning severity by default.
- **record_size** — caps record arity: a record type (inline or
  typedef) with more than `max_fields` (default 5, positional plus
  named) fields should be transformed into a class. Warning severity
  by default.
- **class_size** — fails classes with more than `max_methods` (default
  25) concrete methods or a weighted-methods sum (WMC, total cyclomatic
  complexity of all methods) above `max_wmc` (default 80). Catches
  god-classes assembled from many small methods that each pass the
  `complexity` gate.
- **weight_of_class** — fails classes whose ratio of public instance
  fields to public instance members exceeds `max_weight` (default 0.33):
  classes revealing more data than behavior. Disabled by default —
  data/model classes are legitimate.
- **scattered_constants** — two finding kinds on whole literal
  values. *Constant regression*: a named `const` for the value
  already exists anywhere in the corpus — every hardcoded
  re-introduction (a bare literal or a duplicate local const, even a
  single occurrence in the declaring file) is flagged immediately,
  naming the constant and its declaration site to reference. The
  fact has a home; you do not get to re-hardcode it while the gate
  waits for `min_files` again. *Scattered literal*: no constant
  exists yet and the value appears in `min_files`+ distinct files —
  the classic "change `86400` in every service" hazard; the message
  asks to extract one shared constant and *verify* all occurrences
  mean the same thing first (the same value is sometimes
  coincidence). Expressions, case labels, directive URIs and
  literals inside constant declarations follow the shared
  literal-site rules; short strings (`min_length`) and small numbers
  (`min_value`) are coincidence; an `ignore` list exempts values
  permanently (generic vocabulary) and path-glob entries (`src/**`)
  exempt whole files. Also flags pure value aliases — private
  `const _x = kY;` — "reference the constant directly" (`aliases:
  false` opt-out; public re-export shims are exempt). Warning
  severity by default.
- **duplication** — detects exact copy-paste token blocks across Dart
  source files. A block counts when it is at least `min_tokens` tokens
  (default 50) and `min_lines` lines (default 5) long. `report` chooses
  the verdict style: `percentage` (default) fails a file whose
  duplicated line percentage exceeds `threshold` (default 1.0); `clones`
  (PMD CPD style) fails once per non-overlapping clone group with all
  its locations in the message. CPD-parity knobs: `ignore_identifiers`
  (structure-only matching), `ignore_imports` (skip
  import/export/part directives), `skip_duplicate_files` (report a
  copied file once). Generated files and `test/**` are excluded by
  default. Cross-module duplication can be gated with `sources`: extra
  file/directory paths (resolved against the project root) unioned into
  the scan, so a monorepo can compare `lib/` against `flutter_app/lib/`
  or `packages/*/lib/` without widening CRAP analysis. Two opt-in
  normalizations extend detection to renamed clones: `ignore_locals`
  renames function-local identifiers (parameters, locals, loop and catch
  variables, type parameters, local functions, pattern variables)
  consistently in first-use order, keeping the API surface — called
  method names, types, field references — visible, so two locals swapped
  against each other never match (interpolated strings become opaque);
  `ignore_literals` replaces string and numeric literals with
  placeholders. Both are off by default: the default mode reports
  exact copy-paste only.
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
  black RenderFlex pattern, matched by its equal-length checkerboard
  segments), build-error screens (the dark-red `ErrorWidget`
  background), broken icon placeholders (the tofu box-with-an-X of a
  failed image load — confirmed by diagonals that start at the box
  corners, converge, cross and diverge again, so checkmark tiles and
  filled controls with text pass), hollow icon boxes (an unloaded icon
  font's bordered square with an empty interior — ring-isolated,
  square-cornered, 20-64 px, so checkboxes pass) and solid glyph
  rectangles (square-cornered Ahem fallback text from a font that
  failed to load). Golden tests do not fail on these — the broken frame gets
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
- **folder_structure** — flags directories holding more than their
  cap of logical `.dart` units directly, instead of organizing code
  into feature packages. Classic form: `dirs` (literal paths or
  globs) + one shared `max_loose_files`. Alternative `config` map
  with per-pattern caps (`{lib/src: 3, 'lib/src/**': 30}` — takes
  precedence when present). Only a directory's own files count
  (nested directories are the organized form); generated siblings of
  one source file (`magic.dart` + `magic.g.dart`) count as one unit;
  `exclude` globs exempt files.
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
- **mutation** — mutation testing (adapted from the unclebob/mutator
  research conclusions): a declarative, category-tagged operator table
  (`arithmetic` `+`/`-`, `*`/`/`, `/`→`~/`; `boundary` `>`↔`>=`,
  `<`↔`<=`, `>`↔`<`, `>=`↔`<=`; `equality` `==`↔`!=`; `logical`
  `&&`↔`||`; `boolean` `true`↔`false`; `constant` `0`↔`1`, `-1`→`0`;
  `unary` delete `!`) is matched on the parsed AST — offsets come from
  analyzer tokens, never regex. Sites in unexecuted methods are
  `uncovered` and excluded from the score denominator; every covered
  site is mutated one at a time and the test suite re-runs per mutant
  (a non-zero exit kills the mutant — compile-error mutants die the
  same way because `dart test` refuses to run; a timeout counts as
  survived). The gate fails below `min_score` (default 0.8) or above
  `max_survivors` (default 0), reporting one violation per survived
  mutant, and skips itself when there is no coverage data or no test
  directory. Disabled by default: mutation testing runs the test suite
  once per mutant, so enable it only on fast suites. `operators`
  selects a category subset; `max_mutants` (default 500) caps the
  executed sites; `timeout_seconds` (default 60) guards each mutant.
  `cache` (default true) enables the digest-incremental
  killed-stays-killed cache (`.crap-mutation-cache.json`): mutants of
  methods whose exact source span is unchanged since the last run and
  that were previously killed are replayed, not re-executed (survivors
  always re-run, because the suite may have improved); a
  mutation-relevant config change (operators, `test_args`, tool
  version) wipes the cache. `test_args` (default `['test']`) is the
  full per-mutant test invocation argument list — scope the suite to
  relevant test paths yourself, knowing that a mutant is killed only if
  the scoped suite would kill it. `scope_tests` (default false) derives
  that scoping automatically: each mutant's invocation is narrowed to
  the test file(s) mirroring the mutated file (`lib/src/foo/bar.dart`
  → `test/src/foo/bar_test.dart`, `test/foo/bar_test.dart`), falling
  back to `test_args` when no candidate exists — a scoped kill is
  monotone and cached as a regular kill, a scoped survivor is
  re-confirmed against the full invocation before it counts. In a diff
  run (`--diff` / `--diff-base`) only sites whose containing method
  intersects the changed lines are executed at all: per-PR runs pay
  only for the mutants of the changed methods.

- **string_hazards** — flags string literals whose escaping or pattern
  usage contradicts what the author almost certainly meant, from the
  parsed-unresolved AST only. Three checks: (1) escaped interpolation —
  `\$name` / `\${name}` inside a non-raw string renders the literal
  text `$name`; flagged only when the same identifier is interpolated
  elsewhere in the same file (sibling evidence), keeping deliberate
  shell escapes quiet; (2) raw regex with an escaped anchor — a raw
  string passed to `RegExp(...)` ending with `\$` (or starting with
  `\^`) matches a literal dollar/caret where the end/start anchor was
  almost certainly intended (a plain `$`/`^` is the anchor); (3) regex
  anchors in literal String patterns — `replaceFirst`/`replaceAll`/
  `replaceFirstMapped`/`replaceAllMapped`/`split` treat their `String`
  pattern as literal text, so a leading `^` or unescaped trailing `$`
  can only ever match that literal character. Warning severity by
  default: deliberate literal dollars (shell code, price patterns) trip
  the warnings occasionally — confirm or restructure.

- **identical_branches** — the copy-paste-edit bug family, compared by
  canonical form (whitespace-, parenthesis- and comment-independent;
  operands of commutative operators sorted; same-operator nests
  flattened): (1) duplicate conditions in one `if`/`else if` chain —
  every later branch is unreachable; (2) duplicate branch bodies in one
  chain, including an `else` equal to its `then` (a single-statement
  block equals the naked statement); (3) duplicate
  operands in one boolean chain (`a || a` collapses to `a`) and
  absorbed operands (`a || b && a` collapses to `a` — the extra terms
  are dead); (4) identical ternary
  branches (`c ? x : x` — the condition is dead); (5) duplicate
  positional arguments in one call (`f(w, h, w)`) — named arguments are
  exempt (the name documents the slot) and so are all-literal argument
  lists (uniform-value APIs like `EdgeInsets.fromLTRB(8, 8, 8, 8)`);
  (6) duplicate catch bodies in one `try`. Only pieces of the *same*
  construct are compared; identical conditions in separate `if`
  statements are legal. `switch` is excluded — the analyzer already
  flags duplicate cases. Warning severity by default: equivalence
  assumes side-effect-free operands.

- **enum_name_contract** — flags usages of the built-in `.name`/`.index`
  members *inside enum declaration bodies* on provable enum receivers:
  `this`, implicit `this` (a bare `name`/`index` in an instance member
  with no local shadowing), the enum's own constants (qualified or not),
  `values` loop variables, `values[i]` index accesses, and parameters
  explicitly typed with the enum. `Color.red.name` is `"red"` today;
  rename the constant and every persisted YAML/JSON/DB row written from
  it drifts. The fix is an explicit contract field — `final String
  value;` (enhanced enum) contracted on as `.value`. Names the enum body
  declares itself shadow the built-ins and are skipped; usages *outside*
  enum bodies are out of scope (they need type matching). Warning
  severity by default: `.name` in log/display labels is legal — the
  message asks to confirm the usage is not a persisted contract.

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
