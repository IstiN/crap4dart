import 'dart:io';

import 'gate.dart';
import 'gate_context.dart';

/// The `loc` gate: fails files longer than `gates.loc.max_lines`.
class LocGate implements Gate {
  /// Creates a [LocGate].
  const LocGate();

  @override
  String get id => 'loc';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.loc;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      checked++;
      final lines = _lineCount(File(file).readAsStringSync());
      if (lines > config.maxLines) {
        violations.add(
          GateViolation(
            file: context.relativePath(file),
            message: '$lines lines > max ${config.maxLines}',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked files within ${config.maxLines} lines'
        : '${violations.length}/$checked files over ${config.maxLines} lines';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  int _lineCount(String content) {
    if (content.isEmpty) return 0;
    final newlines = '\n'.allMatches(content).length;
    return content.endsWith('\n') ? newlines : newlines + 1;
  }
}
