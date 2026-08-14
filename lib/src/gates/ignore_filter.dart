import 'package:path/path.dart' as p;

import 'gate.dart';
import 'gate_context.dart';

/// Line comment marker that suppresses a gate violation on its line
/// (or the following line). Only honored when the gate sets
/// `ignorable: true` in the config — suppression is opt-in.
const String ignoreMarker = 'crap:ignore';

/// File-level marker (anywhere in the first 5 lines) that suppresses all
/// violations of ignorable gates in that file.
const String ignoreFileMarker = 'crap:ignore-file';

/// Drops violations of ignorable gates suppressed by ignore markers.
///
/// A violation is suppressed when its file starts with
/// `// crap:ignore-file` (first 5 lines), or when the violation's line or
/// the line above carries a `// crap:ignore` comment. Violations without
/// a line number are only suppressed by the file-level marker.
GateResult filterIgnored(GateResult result, GateContext context) {
  if (result.passed || result.violations.isEmpty) return result;
  final kept = <GateViolation>[];
  for (final violation in result.violations) {
    if (!_isIgnored(violation, context)) kept.add(violation);
  }
  if (kept.length == result.violations.length) return result;
  return GateResult(
    gateId: result.gateId,
    passed: kept.isEmpty,
    violations: kept,
    summary: result.summary,
    warning: result.warning,
  );
}

bool _isIgnored(GateViolation violation, GateContext context) {
  final path = p.isAbsolute(violation.file)
      ? violation.file
      : p.join(context.projectRoot, violation.file);
  if (_ignoredByFileMarker(path, context)) return true;
  final line = violation.line;
  if (line == null) return false;
  return _ignoredByLineMarker(path, line, context);
}

/// Whether [file] carries the file-level ignore marker in its first
/// five lines (unreadable files are never ignored).
bool _ignoredByFileMarker(String file, GateContext context) {
  if (!context.hasLine(file, 1)) return false;
  for (var i = 1; i <= 5; i++) {
    final line = context.line(file, i);
    if (line == null) break;
    if (line.contains(ignoreFileMarker)) return true;
  }
  return false;
}

/// Whether [line] (or the line above it) of [path] carries the
/// line-level ignore marker.
bool _ignoredByLineMarker(String path, int line, GateContext context) {
  final onLine = context.line(path, line);
  final aboveLine = line > 1 ? context.line(path, line - 1) : null;
  final marked = (onLine != null && onLine.contains(ignoreMarker)) ||
      (aboveLine != null && aboveLine.contains(ignoreMarker));
  return marked;
}
