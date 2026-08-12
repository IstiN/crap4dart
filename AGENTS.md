# AGENTS.md

Guidance for AI agents and contributors working on crap4dart.

## What this is

`crap4dart` is a CLI tool and Dart package providing:

1. **CRAP metric analysis** (`analyze`) — `CRAP = CC²·(1−coverage)³ + CC`
   per method, combining AST-based cyclomatic complexity with LCOV coverage.
   Port of [crap4java](https://github.com/unclebob/crap4java).
2. **Quality gates** (`check`) — 8 configurable gates: `loc`,
   `test_coverage`, `golden`, `hardcoded_strings`, `accessibility`,
   `complexity`, `method_size`, `public_docs`.
3. **Integrations** — `init` (config scaffold), `install` (git hooks +
   GitHub Actions workflow), JSON output, diff mode (`--diff`/`--diff-base`).
4. **CPU profiling** (`profile`) — instruments every method in `lib/` with
   a `Stopwatch`, runs the test suite, and reports per-method timing
   (source instrumentation, not VM service sampling); configured via the
   `profile` config key (`enabled`, `threshold_ms`, `top`).

The full contract is specified in [spec.md](spec.md). Keep `spec.md`,
`README.md`, `lib/src/config/config_template.dart` and this file in sync
with the code when behavior changes.

## Commands

```bash
dart pub get
dart test                    # all tests must pass
dart analyze                 # must report "No issues found!"
dart format .                # apply before committing
dart run bin/crap4dart.dart check    # self-check (dogfooding) — must pass
dart run bin/crap4dart.dart analyze  # self CRAP — max must stay <= 8.0
```

Coverage-dependent verification (needed before judging `analyze` output):

```bash
dart test --coverage=coverage
dart pub global run coverage:format_coverage \
  --lcov --in coverage --out coverage/lcov.info --report-on lib
```

## Dogfooding rules (mandatory)

This repository is checked by its own tool. The pre-commit hook
(`.git/hooks/pre-commit`, installed via `crap4dart install`) runs
`check --staged`, and `.github/workflows/quality.yml` runs the full gate
suite in CI.

- All changes must keep `dart run bin/crap4dart.dart check` green:
  `loc` (800 lines), `test_coverage` (>= 70%), `complexity` (CC 12),
  `method_size` (80 lines / 8 params), `public_docs` (dartdoc on public API).
- `crap4dart.yaml` in the repo root configures this; `sources` includes
  `test/`, so **test code is gated too** — keep test files small and split
  them by topic instead of growing giant `main()` bodies.
- Do not relax thresholds in `crap4dart.yaml` to make a change pass;
  refactor or add tests instead.

## Architecture

```
bin/crap4dart.dart           # entry point -> Crap4DartRunner
lib/src/cli/runner.dart      # commands: analyze, check, init, install, profile
lib/src/config/              # crap4dart.yaml model, loader (strict), template
lib/src/analysis/            # analyzer wrappers: parser, method extractor, CC
lib/src/coverage/            # LCOV parser, per-method coverage, test runner
lib/src/crap/                # CRAP formula, analyzer, console report
lib/src/gates/               # Gate framework + 8 gates
lib/src/files/               # source finder, git changed files, diff parser
lib/src/report/              # JSON reporter
lib/src/profile/             # source-instrumentation profiler, per-method timing
lib/src/hooks/               # git hook installer, CI workflow installer
```

Conventions:

- AST work goes through `package:analyzer` (parsed, unresolved units are
  enough) — never regex-parsing of Dart code.
- Gate implementations produce `GateResult` with `GateViolation`s carrying
  `file` and (when known) `line`; diff-mode filtering relies on `line`.
- Exit codes: `0` success, `1` usage/config error, `2` threshold/gate
  failure. `check` and `analyze` must keep stdout JSON-only under
  `--format json` (warnings go to stderr).
- New config keys require: model field in `lib/src/config/config.dart`,
  strict validation in `config_loader.dart`, an entry in
  `config_template.dart`, README + spec updates, and tests (unknown keys
  must remain errors).
- Coverage attribution only trusts project-relative LCOV paths; entries
  outside the project root (e.g. `.pub-cache`) are ignored everywhere.

## Testing

- `package:test`; fixtures are inline strings or temp directories created
  per test (see `test/gates/gate_test_utils.dart`, `test/cli/`).
- CLI tests run **in-process** via `runCliInProcess` (see
  `test/cli/cli_test_utils.dart`): it invokes
  `Crap4DartRunner(projectRoot: workDir)` directly and captures
  stdout/stderr through `IOOverrides.runZoned`, so command code gets real
  coverage attribution. Assert on the returned `CliResult`
  (exitCode/stdout/stderr), never on the global `exitCode` setter.
- Subprocess execution (`runCli` → `Process.run('dart', ['run', ...])`)
  is reserved for the smoke tests in `test/cli/cli_smoke_test.dart`
  (`--help`, `--version`, `check --help`) that verify the real binary
  entry point; do not add new subprocess tests.
- `Crap4DartRunner` and all commands accept an optional `projectRoot`
  (default: `Directory.current`) — pass it instead of changing cwd.
  Config-relative LCOV paths resolve against the project root.
- Never run the project's own test suite from inside unit tests
  (`coverage_runner` paths are tested via flag parsing only).

## Release checklist

1. `dart test`, `dart analyze`, `dart format` clean; self `check` and
   `analyze` green.
2. `CHANGELOG.md` updated; version bumped in `pubspec.yaml` and
   `lib/src/cli/runner.dart` (`--version`).
3. `dart pub publish --dry-run` reports 0 warnings.
