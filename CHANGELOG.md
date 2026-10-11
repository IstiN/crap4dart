# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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

