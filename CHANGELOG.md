# Changelog

## 0.22.0 — 2026-10-27

- New `reorder` command: deterministically rewrites class members into
  the canonical Dart/Flutter order (constants, static fields, fields,
  constructors, static methods, getters/setters, public methods,
  private methods — same-kind members keep their relative order; a
  stable partition, never alphabetical). Doc comments, annotations and
  `//` comment blocks directly above a member (even separated by one
  blank line) move with it; enum bodies are untouched; CRLF files keep
  their line endings. Idempotent and byte-stable on canonical input —
  including single-line class bodies and members sharing the header
  line, which are preserved (and never corrupted) as-is.
  `--dry-run` lists would-change files and exits 2 for CI/pre-commit
  use.
- Ignore comments gain Dart-lint-style granularity alongside the
  legacy `// crap:ignore` / `// crap:ignore-file` (both unchanged):
  `// ignore:<gate-id>` suppresses that gate on the line (trailing
  or stacked above — several markers combine), `// ignore-file:<id>`
  that gate file-wide. One rule per marker; `// ignore:` with no id
  means every ignorable gate; unknown ids are inert. The
  `ignorable: true` opt-in still applies per gate.
- `scattered_constants` — new `aliases` rule (default on): a private
  pure value alias (`const _x = kY;`) is flagged as adding a name
  without information; the message says to reference the shared
  constant directly. Public declarations (re-export shims) are
  exempt; `aliases: false` switches the rule off.
- `folder_structure` — `dirs` entries accept glob patterns
  (`lib/src/*`, `packages/**`) expanding to every matching directory,
  and generated siblings of one source file (`magic.dart` +
  `magic.g.dart` + `magic.freezed.dart`) count as one logical unit;
  only a directory's own files count (nested directories are the
  organized form). New optional `config` map with per-pattern caps —
  `config: {lib/src: 3, 'lib/src/**': 30}` — taking precedence over
  `dirs`/`max_loose_files`, which stay fully backward compatible.

## 0.21.0 — 2026-10-23

- `scattered_constants` v2: new constant-regression rule — when a
  named `const` for a value already exists in the corpus, every
  hardcoded re-introduction flags immediately (any occurrence count),
  naming the constant and its `file:line`; scattered literals (no
  constant, `min_files`+ files) keep the extract-and-verify message.
- `scattered_fragments` gate removed — too noisy in practice; parked
  on the `feature/scattered-constants-gate` branch (0.20.0) should we
  return to it.

## 0.19.0 — 2026-10-24

- Flutter memory reports no longer show a misleading `0.0` for
  reclaimed-new-gen churn: the VM Service GC stream has no reclaimed
  counters, so `churnNewMb` (per test/suite) and `totalChurnMb` are
  JSON `null` there, a top-level `churnAvailable` flag says so, and
  the console prints "new-gen churn unavailable". Use `allocatedMb` /
  `totalAllocatedMb` (exact allocated bytes) as the churn metric on
  both engines; `--badge` follows the same rule. Dart-engine output
  is unchanged (numeric churn, `churnAvailable: true`).

## 0.18.0 — 2026-10-23

- New `record_named_fields` gate: record type annotations with unnamed
  fields and `.$N` positional accesses are flagged.
- New `inline_record_types` gate: inline record types in signatures
  must move behind one named `typedef` declaration.
- New `record_size` gate: records over `max_fields` (default 5,
  positional plus named) should be transformed into classes.
- `PreparedRun` (CLI run preparation) converted from a six-field
  record typedef to a class — the first `record_size` dogfooding fix.

All notable changes to this project will be documented in this file.

## 0.17.0 — 2026-10-23

### Added

- `memory --engine auto|dart|flutter` (default `auto`): Flutter test
  suites are now measurable. `auto` picks `flutter` when pubspec.yaml
  declares a `flutter:` dependency, else `dart`.
  - `flutter test` passes no VM flags through and the engine's
    `--dart-flags` whitelist rejects `--verbose_gc`; the Flutter mode
    instead re-runs every `flutter_tester` spawn traced by
    `flutter test --verbose --no-pub -j1 -r json` with the VM Service
    enabled, drives the suite over package:test's remote protocol
    (initial -> success -> run/close per test) and measures through
    the VM Service:
    - per-test ALLOCATED bytes — the allocation profile is reset
      before each test and read after it (exact, more precise than
      the Dart engine's reclaimed-new-gen proxy);
    - GC events from the `GC` stream, attributed by arrival;
    - old-gen growth chained across consecutive service events;
    - suite-load allocations read once before the first reset.
  - The tool deletes each file's temp dill when the file finishes and
    at -j1 outruns the measured copy: dills are snapshotted at trace
    time and the snapshots measured (and cleaned up after).
  - Every file executes twice (the tool's run plus the measured copy);
    trace paths must not contain commas (the tool prints its argv via
    plain `List.toString()`).
- Reports (both engines) gained `totalAllocatedMb` (JSON) and an
  `allocated` headline/column; the churn leaderboard sorts by
  allocation volume (Dart engine: reclaimed new-gen proxy; Flutter
  engine: profile-allocated bytes).

## 0.16.0 — 2026-10-22

### Added

- `memory` command (phase 1 of the memory-profiling plan): runs
  `dart --verbose_gc test --concurrency=1 -r json` and attributes GC
  events to tests — allocation churn (reclaimed new-gen MB,
  deterministic across runs) and old-gen growth (leak suspects).
  Per-test windows use each isolate's own clock (GC rows count from
  isolate start; the suite event time is the same zero); loading and
  teardown GCs land in an unattributed bucket. `--badge` writes a
  shields-style churn SVG (see `badges/memory.svg`).
- Dogfooding across three repos (file-level numbers stable across
  runs): crap4dart 497 tests / 245 MB (no heavy files — the earlier
  "30 MB" hotspots were detector artifacts, fixed by the
  window-only attribution); dmtools-dart 4254 tests / 1.5 GB (top:
  AiSyncTools transport test 35 MB, justified); flutter_agent 12387
  tests / 84 GB (top: `AC3 — status without id stays bounded` 2.5 GB
  churn + 14.7 MB retained — reported upstream).

## 0.15.0 — 2026-10-15

### Added

- **`similarity` gate + `crap4dart similarity` command**: file-level
  near-duplicate detection over any text corpus — markdown docs,
  source files of any language, raw text. Copied docs that drifted
  apart, twin templates differing by a heading, stale snapshot copies,
  generated files duplicating their sources: each clustered file gets
  a violation naming its counterparts and the strongest pair metrics.
  8-token shingles, Jaccard + containment thresholds, transitive
  clusters; markdown/code/raw normalization profiles (code fences,
  comments, import-family lines and literal values are normalized
  away). Opt-in (`enabled: false` by default) — explore with the
  informational `similarity` command, tune, then enforce, typically
  with a baseline so only new near-duplicates fail.
- **Native binary releases**: every `v*` tag now builds self-contained
  Linux x64/arm64 executables (`dart compile exe`, no Dart SDK needed
  at runtime) with SHA256 checksums attached to the GitHub release.

## 0.14.2 — 2026-10-15

### Fixed

- `broken_goldens` false positives against real-world goldens (measured
  on 187 current flutter_agent_harness goldens: 40 flagged before the
  fix, 1 documented residual after):
  - the tofu X must anchor its diagonals AT the box walls — the letter
    strokes inside a filled control (a white "S" on a Save button) also
    run a converge-merge-diverge cycle, but they start well inside the
    run and are now rejected;
  - hollow icon boxes must be RING-ISOLATED (the 2px ring around the
    box is pure background) — a copy icon's front panel has the rest of
    the glyph crossing it;
  - hollow icon boxes must have SQUARE corners and be 20-64 px —
    unchecked Material checkboxes are rounded 16-18 px squares;
  - solid glyph rectangles must have square corners — rows of rounded
    white dock/pagination tiles no longer read as Ahem text.
- `broken_goldens` measured on the 40 broken pre-font goldens from the
  flutter_agent_harness regression fixture: 30/40 detected (0/40
  before 0.14.1); the residual 10 carry only sub-20 px boxes and the
  fa_mark logo (a real image).

## 0.14.1 — 2026-10-15

### Added

- `broken_goldens`: two new broken-golden shape classes (fixes blind
  spots from issue #3):
  - hollow icon boxes — a square-ish bordered box (14-64 px) with
    continuous walls and an empty interior, what an unloaded icon font
    actually draws (no diagonal cross needed);
  - solid glyph runs — at least two distinct solid rectangles of the
    same vertical extent side by side with a small gap (Ahem fallback
    text, a font that failed to load in the test environment).
- `gates.duplication` `report: clones`: the summary now also carries
  the project-wide duplicated-line percentage, so a number is always
  present regardless of the report mode.

### Fixed

- `broken_goldens` false positives (issue #4):
  - the tofu X now requires the full life cycle — diagonals converge,
    MERGE into one central band and then DIVERGE again. A checkmark V
    (green Habit-Tracker-style tiles) converges to its vertex and
    never re-diverges, so those tiles pass;
  - overflow stripes require the checkerboard's equal-length yellow/
    black segments; amber digits on dark cards (4 px strokes on 7 px
    gaps) alternate but with unequal lengths and pass.

## 0.14.0 — 2026-10-12

### Added

- `gates.duplication`: PMD CPD parity, implemented natively (CPD itself
  has no Dart support):
  - `report: clones` — one violation per non-overlapping clone group
    (longest first), every occurrence location in the message;
    `percentage` stays the default.
  - `ignore_identifiers` — replace all identifiers with a placeholder
    before hashing (structure-only matching, CPD
    `--ignore-identifiers`); built-in/pseudo keywords included.
  - `ignore_imports` — exclude `import`/`export`/`part` directives
    from tokenization.
  - `skip_duplicate_files` — a file whose token stream equals an
    earlier file's is analyzed once (CPD `--skip-duplicate-files`).

### Fixed

- Duplication windows are now verified by actual token equality before
  reporting (Rabin-Karp fingerprint collisions no longer count as
  clones) and extended to the maximal extent the occurrences share.

## 0.13.0 — 2026-10-12

### Added

- `gates.complexity.metric`: `cyclomatic` (default) or `cognitive` —
  SonarSource-style cognitive complexity (flow breaks weighted by nesting
  depth; flat `else if` chains stay cheap, `&&`/`||` sequences count once
  per run). The CRAP score always uses cyclomatic complexity.

### Fixed

- Cyclomatic complexity now counts switch **expressions**
  (`return switch (x) { ... }`), their `when` guards, `if-case` guards,
  and `||`/`&&` patterns — previously all uncounted.
- The `nesting` gate no longer counts `else if` chains as nesting: a
  chained `if` keeps its originating `if`'s level, while an `if` inside
  an `else` block still adds one.

## 0.12.2 — 2026-10-11

### Added

- `mutation` gate: diff-scoped execution — under `--diff` / `--diff-base`
  only sites whose containing method intersects the changed lines are
  executed at all (sites outside the diff are neither executed nor
  counted), so a per-PR run pays only for the mutants of the changed
  methods.
- `mutation` gate: `scope_tests` (default false) — per-mutant test
  scoping to the derived test file(s) of the mutated file
  (`lib/src/foo/bar.dart` → `test/src/foo/bar_test.dart`,
  `test/foo/bar_test.dart`), falling back to `test_args` when no
  candidate exists. A scoped kill is monotone (the scoped invocation is
  a subset of the full suite) and is cached as a regular kill; a scoped
  survivor — a timeout included — is re-confirmed once against the full
  invocation, and only the confirmed outcome is reported and cached.

## 0.12.1 — 2026-10-11

### Fixed

- `mutation` gate integrity: a real run on a downstream project once
  ended with a leftover mutant on disk even though the per-site
  restore is `finally`-guarded (out-of-process defeat: external write
  or a killed VM between apply and restore). The engine now snapshots
  every file it will mutate before the loop and re-verifies the whole
  tree in an outer `finally`: any mismatch is re-restored and reported
  as `INTEGRITY: re-restored after run` in the summary plus a stderr
  warning, so silent tree corruption becomes a loud, self-healing
  error.

## 0.12.0 — 2026-10-11

### Added

- `mutation` gate hardening: digest-incremental killed-stays-killed
  cache. Per-method outcomes persist to
  `<projectRoot>/.crap-mutation-cache.json` (versioned envelope
  `{version, meta, methods}`) keyed by method identity (file +
  `className.methodName`) and an FNV-1a 64-bit digest of the method's
  exact AST source span (zero new dependencies). On later runs,
  covered mutants of unchanged methods with a matching site identity
  that were previously `killed` are replayed, not re-executed, and
  reported as `cached` in the summary; survivors always re-execute;
  changed/new methods re-execute fully; coverage gating is re-derived
  from fresh LCOV every run. The `meta` guard (tool version, operators,
  `test_args`) wipes the cache on mismatch; entries of vanished methods
  are pruned. New `gates.mutation` keys: `cache` (default true) and
  `test_args` (default `['test']` — full per-mutant test invocation
  args; strict validation: non-empty list of non-empty strings).
- `mutation` gate (22nd gate, disabled by default): mutation testing
  adapted from the unclebob/mutator research conclusions. A
  declarative category-tagged operator table (`arithmetic`, `boundary`,
  `equality`, `logical`, `boolean`, `constant`, `unary`) is matched on
  parsed ASTs (token offsets, never regex); covered sites are mutated
  one at a time and the test suite re-runs per mutant (non-zero exit
  kills — compile errors included; timeout counts as survived).
  Uncovered sites are excluded from the score. New `gates.mutation`
  keys: `min_score` (0.8), `max_survivors` (0), `timeout_seconds`
  (60), `max_mutants` (500), `operators` (all), `exclude` (generated +
  `test/**`), plus the standard `enabled`/`severity`/`ignorable`. One
  `GateViolation(file, line)` is reported per survived mutant, so diff
  mode and baselines work unchanged.

## 0.10.0 - 2026-09-28

### Added

- `duplication` gate: new `sources` key — additional file/directory paths
  (resolved against the project root) unioned into the duplication scan,
  enabling cross-module duplicate detection in monorepos without widening
  the CRAP analysis scope.

### Changed

- Dependencies refreshed: `analyzer` 7.3 -> 14.4 (new "parts" AST —
  `ClassDeclaration.namePart.typeName`, `NamedType.name`,
  `NamedArgument`/`Argument` model, `body.members`, `isComplete`),
  `xml` 7.1, `test` 1.32, `lints` 6.1.

