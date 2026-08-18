# Changelog

All notable changes to this project will be documented in this file.

## 0.9.2

### Fixed

- `profile`: isolate-safe collector flush — temp files now carry the
  isolate identity hash (microsecond names collided across parallel
  test isolates, making flushes rename each other), and the merge read
  retries once around a concurrent rename instead of discarding the
  accumulated data as corrupt. Fixes the "instrumented runner drops a
  shard after ~30 tests" report from a full-suite yoloit run —
  verified end-to-end: 4523 methods, complete report, no shard loss.
- `profile`: MEAN column marks sub-30µs means with `~` (instrumentation
  overhead dominates there; a method that got FASTER can show a higher
  mean after its neighbors were optimized — read CALLS/TOTAL deltas).

## 0.9.1

### Fixed

- `broken_goldens` tofu detection precision: an anchored convergence
  baseline (letter glyph arcs like "m" previously faked the X), solid
  top-border and clear-above checks, continuous side walls and
  sustained diagonal movement. Verified on three real projects: all
  large broken icons caught, zero glyph/TUI false positives.

## 0.9.0

### Added

- `broken_goldens`: tofu icon detection — broken icon placeholders
  (the box-with-an-X of a failed image load) are flagged in golden
  PNGs by their shape: bordered square, converging diagonal bands,
  crossing in the middle. Verified on real goldens: 5/5 broken caught
  (one missed by the human reviewer), zero false positives on terminal
  UI screenshots and outlined digit glyphs.
- `crap4dart goldens` command: `--print-snippet` / `--write` emits the
  `guardGoldens` test helper that turns image-load errors into failing
  assertions inside golden tests (standard Image.asset/network paths).

### Changed

- BREAKING: `coverage.run_tests` now defaults to `true` — `analyze`
  runs the test suite to produce coverage instead of reporting all-N/A
  CRAP scores. Opt out with `run_tests: false` (bare `crap4dart`
  first-run experience drove this: a wall of N/A helped no one).

## 0.8.7

### Fixed

- `analyze`: N/A entries (no coverage data) are now ordered by file
  path and line — Dart's unstable sort previously shuffled them when
  every score was N/A.
- `analyze`: the "no LCOV coverage data found" warning now includes a
  hint on how to generate coverage (`flutter test --coverage` or
  `coverage.run_tests: true`).

## 0.8.6

### Changed

- Performance: `broken_goldens` pixel scanning rewritten as a single
  classification pass (`_PixelStats`) with an early exit when no
  stripe-yellow pixels exist — instrumented profiling showed the gate
  at 96% of total CPU time (1.68 billion per-pixel calls); the full
  check run is now ~80x faster on golden-heavy suites.
- Performance: compiled globs are cached per pattern in
  `GateContext.matchesAnyGlob` (was re-parsed for every file x
  pattern across all gates).
- `unused_code`: removed a double AST traversal for class members.

### Fixed

- `unused_code`: references made from mixin/extension/enum method
  bodies are counted again (a class-level-only reference pass missed
  them, false-positive "never referenced" on top-level helpers called
  from mixins).

## 0.8.5

### Fixed

- `broken_goldens`: overflow-stripe detection now requires real
  yellow/black alternation (>= 4 transitions, yellow >= 1/3 of the
  run) instead of "yellow and black pixels in a line" — dark terminal
  UIs with sparse yellow text (TUI screenshots) no longer
  false-positive.
- Internal: workspace profile pubspec rewriting extracted into
  `WorkspacePubspec` (ProfileRunner back under the WMC limit); stripe
  detector row/column scans deduplicated.

## 0.8.4

### Fixed

- `magic_constants`: all literals inside `const` declarations are
  exempt (map keys and collections included) — only non-const usages
  can be magic.

## 0.8.3

### Fixed

- `magic_constants`: string literals used as index expressions
  (`map['key']`) are no longer flagged — protocol identifiers, not
  constants.

## 0.8.2

### Fixed

- Rebase artifact cleanup; republished after the 0.8.0 release series.

## 0.7.2

### Fixed

- `magic_constants`: string literals used as map keys are no longer
  flagged — they are protocol identifiers (JSON field names, channel
  names), not constants; extracting them added pure noise.

## 0.8.0

### Added

- `external` quality gate — wraps external static-analysis tools
  (detekt, ktlint, swiftlint, ...) emitting a Checkstyle XML report
  as rules `{id, executable, arguments}`; findings become standard
  violations with severity, baseline and diff mode support. This
  brings Kotlin/Swift code in Flutter monorepos into the same
  `crap4dart check` run (new `package:xml` dependency).

## 0.7.1

### Fixed

- `unused_files`: `export` directives now count as file usage — a package's
  public entry library reaches implementation files through exports, which
  the import-only graph missed, flagging every exported file as unused.
- `unused_code`: declaring a private method no longer removes its name from
  the reference set — cross-class private access within the same library
  (`host.controller._method()`) was reported as never referenced.

## 0.7.0

### Added

- `broken_goldens` quality gate — scans golden PNG files for rendered
  Flutter error artifacts: overflow stripes (yellow/black) and
  build-error screens (dark red). Golden tests do not fail on these;
  the pixels are the only witness (new `package:image` dependency).
- `test_assertions` quality gate — fails tests without assertion calls
  (`min_assertions`, default 1).
- `folder_structure` quality gate — flags directories with more than
  `max_loose_files` (default 0) loose `.dart` files instead of
  organized feature packages.

## 0.6.1

### Changed

- Dogfooding cleanup: every literal previously hidden in the committed
  baseline (304 violations — repeated YAML keys, CLI flag names, gate
  ids, JSON keys, path segments) is now a named constant. The baseline
  is empty; `check` passes with no grandfathered violations.

## 0.6.0

### Added

- `magic_constants` quality gate — flags magic literals: hex color
  values (`0xFFFF5733`) outside `const` declarations and numeric or
  string literals repeating `min_duplicates` (default 3) times in one
  file. Configurable via `gates.magic_constants` (`enabled`,
  `severity`, `ignorable`, `flag_hex_colors`, `min_duplicates`,
  `min_length`, `exclude`).

## 0.5.3

### Fixed

- `profile`: pub workspace members (`resolution: workspace`) can now be
  profiled. The temp copy gets a standalone `pubspec.yaml` (workspace marker
  stripped, relative `path:` dependencies absolutized) and runs
  `pub get` before the instrumented tests, instead of failing with
  "found no workspace root including it".

## 0.5.2

### Fixed

- `profile`: `part of` files are now skipped instead of being instrumented
  with an injected import — parts cannot contain directives, so the old
  behavior produced uncompilable code and the profiled test run failed.

## 0.5.1

### Fixed

- `unused_code` and `unused_files` now skip themselves in partial
  selection runs (`--changed`, `--staged`, `--diff`, explicit paths):
  their verdicts need the full source set, and partial runs previously
  produced false "never imported/referenced" positives.

## 0.5.0

### Added

- Gate framework: `severity: error | warning` per gate — warning gates
  report violations (`[WARN]`) without failing the run.
- Gate framework: `ignorable: true` opts a gate into `// crap:ignore`
  line comments and `// crap:ignore-file` file markers. Off by
  default — suppression is never allowed unless explicitly enabled.
- Gate framework: per-path threshold overrides (`entries`) for `loc`,
  `complexity` and `method_size` — relax or tighten thresholds per
  directory.
- Baseline mode: `check --save-baseline` records current violations to
  `.crap-baseline.json`; `check --baseline` fails only on violations
  not in the baseline.
- `nesting` gate — maximum block nesting level per method (default 5).
- `class_size` gate — methods-per-class (default 25) and
  weighted-methods-per-class (default 80) limits; catches god-classes.
- `weight_of_class` gate — flags classes revealing more data than
  behavior (default 0.33, disabled by default).
- `unused_code` gate — flags never-referenced private declarations.
- `unused_files` gate — flags never-imported files under `lib`.
- `banned_imports` gate — architectural import rules
  (`from`/`forbid`/`message`).

## 0.4.0

### Fixed

- `profile`: the collector import is now inserted after leading
  `library`/`part of`/`part` directives instead of blindly prepending it,
  which produced invalid Dart (compile error) on files starting with
  `library;`.

### Added

- `file_naming` quality gate — flags mechanical file names that indicate
  code was split to dodge the `loc` gate instead of along domain
  boundaries: numeric suffixes (`jira_batch1.dart`, `report2.dart`) and
  generic dumping-ground names (`utils.dart`, `helpers.dart`).
  Configurable via `gates.file_naming` (`enabled`, `exclude`, `allow`);
  technical stems such as `base64`/`sha256` are allowed by default.

## 0.3.0

### Added

- `profile` command — source-instrumentation-based per-method timing
  profiler. Creates a temporary instrumented copy of `lib/`, runs the test
  suite, and collects precise per-method timing (microseconds, not
  statistical sampling). Reports TOTAL(ms), %, CALLS, MEAN(µs), MAX(µs) and
  @60fps(ms) per method.
- `--name`, `--tags`, `--exclude-tags` flags for filtering which tests the
  profiler runs; positional `[paths...]` for explicit test file/directory
  targets.
- `@60fps(ms)` column in profile reports — estimates the per-frame cost of
  a method called every frame at 60 fps (`MEAN × 60`), highlighting methods
  that are cheap per-call but costly in a rebuild hot path.
- `profile` config section (`enabled`, `threshold_ms`, `top`).
- `skill` command — prints the crap4dart profiling skill content for AI
  agents, or shows installation instructions (`crap4dart skill`,
  `crap4dart skill --format install`).
- Profiling skill at `.agents/skills/crap4dart-profiling/SKILL.md` —
  teaches AI agents how to run and analyze profiling results.
- Full profiling reports saved to `profile-reports/` directory
  (`profile-report.txt` + `profile-report.json`), with automatic
  `.gitignore` entries for `profile-reports/` and `.crap_profile_temp/`.

### Changed

- `profile` now uses source instrumentation (wrapping every method body in a
  `Stopwatch` + `try/finally`) instead of VM service sampling. Timing is
  deterministic and exact rather than statistical.

### Removed

- `vm_service` as a direct dependency (it was needed for the previous
  VM-sampling approach; now only transitive).

## 0.2.1

### Changed

- `duplication` gate now tokenizes the whole Dart file (imports, declarations,
  classes, methods) instead of only method bodies, aligning its detection scope
  with jscpd while keeping the Dart-aware normalization and 1.0% default
  threshold.

## 0.2.0

### Added

- New `duplication` quality gate enabled by default. Detects exact copy-paste
  token blocks across Dart source files using `package:analyzer` tokenization
  and Rabin-Karp sliding-window indexing. A block counts when it is at least
  `min_tokens` (default 50) tokens and `min_lines` (default 5) lines long.
  The gate fails a file when its duplicated line percentage exceeds
  `threshold` (default 1.0%). Generated files and `test/**` are excluded by
  default.
- Cross-file duplicate detection: identical blocks in different files are
  reported in every file that contains them.

### Changed

- Quality gates now run in the order: `loc`, `test_coverage`, `complexity`,
  `method_size`, `duplication`, `public_docs`, `hardcoded_strings`,
  `accessibility`, `golden`.

## 0.1.3

- Same as 0.1.2, with the embedded `--version` string updated (it stayed
  hardcoded at 0.1.1 in the 0.1.2 archive).


## 0.1.2

- fix(cli): monorepo-aware staged/changed file resolution — git diff/status
  report paths relative to the repo top-level, but the runner joined them
  against the current directory, so `check --staged`/`analyze --changed`
  crashed with PathNotFoundException or scanned outside the package when
  run from a monorepo sub-package. Selections now resolve against
  `git rev-parse --show-toplevel` (canonical, symlink-free) and are
  filtered to files inside the project root.


The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.1

- Fix the published package: `.gitignore` pattern `coverage/` also excluded
  `lib/src/coverage/` sources from both git and the pub.dev archive; anchor it
  to the repository root (`/coverage/`).
- CI workflow template and this repo's workflow install crap4dart from
  pub.dev instead of the git source; this repo's own CI self-hosts from the
  checkout.
- `Crap4DartRunner` and commands accept an optional `projectRoot`; the LCOV
  path resolves against it.
- CLI tests run in-process for honest coverage; `CoverageRunner` accepts an
  injectable process spawner; fix unawaited futures in file selection.
- `analyze --badge <path>` writes a local shields.io-style SVG badge with
  the max CRAP score (green/yellow/red against the threshold, grey for
  N/A); written even when the threshold is exceeded.

## 0.1.0

Initial release.

### Added

- CRAP analyzer for Dart/Flutter: cyclomatic complexity per method,
  LCOV coverage attribution, CRAP scores with a configurable threshold.
- Console report with CRAP, COV%, BR% (branch coverage), CC, method and
  location columns, sorted worst-first.
- 8 quality gates: `loc`, `test_coverage`, `golden`,
  `hardcoded_strings`, `accessibility`, `complexity`, `method_size`,
  `public_docs`.
- `crap4dart.yaml` configuration with per-key defaults merging and strict
  validation.
- `analyze`, `check`, `init` and `install` commands.
- Pre-commit hook installation with a managed marker block and `--force`
  merging into foreign hooks.
- GitHub Actions workflow template (`install --ci`) for Dart and Flutter
  projects.
- JSON output (`--format json`) for `analyze` and `check`.
- `--run-tests` coverage generation for `analyze` and `check`
  (`flutter test --coverage` / `dart test --coverage` + `format_coverage`).
- Configurable source directories via the top-level `sources` key, so
  gates (`loc`, `complexity`, `method_size`) can check test code too.
- `gates.test_coverage.dirs` to scope the coverage aggregate.
- Stricter LCOV attribution: entries outside the project root (e.g.
  pub-cache dependencies) are ignored when matching coverage to files.
- `count_lambdas` option (`crap` and `gates.complexity`) to exclude
  lambda branches from cyclomatic complexity.
- Global `exclude` glob patterns applied in every file selection mode.
- Diff mode (`--diff`, `--diff-base`): gates and CRAP analysis restricted
  to lines changed since a git base (ratchet for legacy codebases).
