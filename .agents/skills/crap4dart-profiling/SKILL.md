---
name: crap4dart-profiling
description: CPU profiling for Dart/Flutter projects using crap4dart. Use when the user wants to find performance bottlenecks, measure method execution time, profile tests, or optimize Dart/Flutter code. Activated by keywords like "profile", "performance", "bottleneck", "slow methods", "optimize timing", "microseconds".
---

# crap4dart Profiling Skill

## When to Use

Use this skill when the user wants to:

- Find performance bottlenecks in Dart/Flutter code
- Measure per-method execution time (microsecond precision)
- Profile test suites to see which methods are expensive
- Identify frequently-called methods that accumulate cost
- Optimize Flutter UI jank (60fps budget analysis)

## What is crap4dart profile?

`crap4dart profile` is a source-instrumentation profiler. It wraps every
method body in `lib/` with `Stopwatch` + `try/finally`, runs the test suite
against the instrumented code, and reports precise per-method timing.

Unlike VM-service sampling (statistical, 1kHz), this gives **exact**
microsecond timing for every single call — no missed fast methods.

## Prerequisites

```bash
# Install crap4dart
dart pub global activate crap4dart

# Or run from source
dart run /path/to/crap4dart/bin/crap4dart.dart profile
```

## Basic Usage

```bash
# Profile all tests — full report
crap4dart profile

# Filter by test name
crap4dart profile --name "collaboration"

# Filter by tags
crap4dart profile --tags "golden,integration"

# Specific test file/directory
crap4dart profile test/collaboration_test.dart

# Limit output to top N (console only)
crap4dart profile --top 10

# Threshold check (exit code 2 if exceeded)
crap4dart profile --threshold 10.0

# JSON output for CI/scripts
crap4dart profile --format json
```

## Reading the Report

After profiling, full reports are saved to `profile-reports/`:

- `profile-reports/profile-report.txt` — human-readable table
- `profile-reports/profile-report.json` — machine-readable JSON

### Console columns

| Column | Meaning |
|---|---|
| `TOTAL(ms)` | Total time across all calls |
| `%` | Share of total profiling time |
| `CALLS` | Number of invocations |
| `MEAN(µs)` | Average time per call |
| `MAX(µs)` | Worst single call |
| `@60fps(ms)` | Cost if called every frame (mean × 60) |

### The @60fps column

This is the key metric for Flutter optimization:
- Budget per frame at 60fps = 16ms
- If `@60fps(ms)` > 16ms, the method **will** cause jank if called during build/layout
- Example: mean=300µs → @60fps=18ms → jank!

## Analyzing Results — Workflow

### Step 1: Run the profiler

```bash
crap4dart profile --format json > /tmp/profile.json 2>/dev/null
```

### Step 2: Read the JSON report

```python
import json
with open('profile-reports/profile-report.json') as f:
    d = json.load(f)
# Sort by totalMicros descending
methods = sorted(d['methods'], key=lambda m: -m['totalMicros'])
```

### Step 3: Identify optimization targets

Look for:

1. **High TOTAL + high CALLS** — method called too often. Cache/debounce it.
2. **High MEAN** — single call is expensive. Algorithm/data structure issue.
3. **High @60fps** — will cause UI jank. Must optimize or move off build path.
4. **High MAX >> MEAN** — occasional spikes. GC, I/O, or contention.

### Step 4: Optimize and re-profile

```bash
# After making changes, re-profile to verify improvement
crap4dart profile --diff  # only changed methods
```

## Config (optional)

```yaml
# crap4dart.yaml
profile:
  enabled: true        # enable/disable profiling
  threshold_ms: 10.0   # warn on methods above this (optional)
  # top: 20            # limit console output (optional)
```

## How It Works

1. Creates `.crap_profile_temp/` with instrumented copy of `lib/`
2. Every method body wrapped in `Stopwatch` + `try/finally`
3. `package_config.json` rewritten to point to instrumented code
4. Tests run with `--compiler source` (bypasses kernel cache)
5. Collector merges timing data across isolates (atomic file writes)
6. Temp directory cleaned up automatically
7. Reports saved to `profile-reports/`

## Limitations

- Expression-body methods (`=> ...`) are not instrumented (no block to wrap)
- Abstract/empty methods are skipped
- Test files in `test/` are not instrumented (only `lib/`)
- Flutter workspace projects need profiling from workspace root
- Profiling adds ~×2-3 overhead (Stopwatch + I/O)
