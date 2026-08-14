import 'dart:io';

import 'package:glob/glob.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The `loc` gate: fails files longer than `gates.loc.max_lines`.
/// Per-path overrides may relax or tighten the limit via `entries`.
class LocGate implements Gate {
  /// Creates a [LocGate].
  const LocGate();

  @override
  String get id => 'loc';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.loc;
    final globs = [
      for (final entry in config.entries)
        for (final path in entry.paths)
          (glob: Glob(path), maxLines: entry.maxLines),
    ];
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      checked++;
      final relative = context.relativePath(file);
      final maxLines = _limitFor(relative, config.maxLines, globs);
      final lines = _lineCount(File(file).readAsStringSync());
      if (lines > maxLines) {
        violations.add(
          GateViolation(
            file: relative,
            message: '$lines lines > max $maxLines',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked files within $checked limits'
        : '${violations.length}/$checked files over their limit';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// The effective limit for [relative]: the first matching entry's
  /// threshold, or [defaultMax].
  int _limitFor(
    String relative,
    int defaultMax,
    List<({Glob glob, int maxLines})> globs,
  ) {
    for (final entry in globs) {
      if (entry.glob.matches(relative)) return entry.maxLines;
    }
    return defaultMax;
  }

  int _lineCount(String content) {
    if (content.isEmpty) return 0;
    final newlines = '\n'.allMatches(content).length;
    return content.endsWith('\n') ? newlines : newlines + 1;
  }
}
