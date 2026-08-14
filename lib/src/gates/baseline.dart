import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'gate.dart';

/// Baseline file name, relative to the project root.
const String baselineFileName = '.crap-baseline.json';

/// Stored gate violations a project starts from; `check --baseline`
/// fails only on violations not present here.
class Baseline {
  /// Creates a [Baseline] over the stored [entries].
  const Baseline(this.entries);

  /// Loads the baseline of [projectRoot], or returns an empty baseline
  /// when no baseline file exists.
  factory Baseline.load(String projectRoot) {
    final file = File(p.join(projectRoot, baselineFileName));
    if (!file.existsSync()) return Baseline(const {});
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final entries = json['violations'] as List<dynamic>? ?? const [];
      return Baseline({
        for (final entry in entries)
          if (entry is Map<String, dynamic>)
            _key(
              entry['gate'] as String,
              entry['file'] as String,
              entry['line'] as int?,
              entry['message'] as String,
            ),
      });
    } on FormatException {
      return Baseline(const {});
    }
  }

  /// The stored violation keys ("gate|file|line|message").
  final Set<String> entries;

  /// Whether [violation] of [gateId] is covered by the baseline.
  bool contains(String gateId, GateViolation violation) => entries.contains(
      _key(gateId, violation.file, violation.line, violation.message));

  static String _key(String gate, String file, int? line, String message) =>
      '$gate|$file|$line|$message';
}

/// Writes the current violations of [results] to the baseline file of
/// [projectRoot]. Returns the number of stored violations.
int writeBaseline(String projectRoot, List<GateResult> results) {
  final violations = <Map<String, Object?>>[];
  for (final result in results) {
    for (final violation in result.violations) {
      violations.add({
        'gate': result.gateId,
        'file': violation.file,
        'line': violation.line,
        'message': violation.message,
      });
    }
  }
  final file = File(p.join(projectRoot, baselineFileName));
  file.writeAsStringSync(
    JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'violations': violations,
    }),
  );
  return violations.length;
}

/// Strips baseline-covered violations from [result]; a gate with every
/// violation covered passes.
GateResult applyBaseline(String gateId, GateResult result, Baseline baseline) {
  if (result.passed || result.violations.isEmpty) return result;
  final fresh = [
    for (final violation in result.violations)
      if (!baseline.contains(gateId, violation)) violation,
  ];
  if (fresh.length == result.violations.length) return result;
  return GateResult(
    gateId: gateId,
    passed: fresh.isEmpty,
    violations: fresh,
    summary: result.summary,
    warning: result.warning,
  );
}
