# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
