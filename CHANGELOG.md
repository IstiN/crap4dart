# Changelog

All notable changes to this project will be documented in this file.

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
