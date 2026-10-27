import 'package:path/path.dart' as p;

import 'gate.dart';
import 'gate_context.dart';

/// Line comment marker that suppresses every ignorable gate's
/// violation on its line (or the following line). Only honored when
/// the gate sets `ignorable: true` in the config — suppression is
/// opt-in.
const String ignoreMarker = 'crap:ignore';

/// File-level marker (anywhere in the first 5 lines) that suppresses
/// all violations of ignorable gates in that file.
const String ignoreFileMarker = 'crap:ignore-file';

/// Granular line marker — `// ignore:<gate-id>` — suppresses only
/// that gate on its line (or the following line). Several markers on
/// one line combine; an empty id (`// ignore:`) suppresses every
/// ignorable gate, matching [ignoreMarker].
final RegExp ignoreLineRule = RegExp(r'//\s*ignore:([^\s/]*)');

/// Granular file marker — `// ignore-file:<gate-id>` — suppresses
/// only that gate in the whole file (first 5 lines); several markers
/// combine. An empty id matches [ignoreFileMarker].
final RegExp ignoreFileRule = RegExp(r'//\s*ignore-file:([^\s/]*)');

/// The gate-id set carried by one ignore comment: [blanket] marks the
/// no-list form (suppress everything ignorable), [ids] the named
/// gates.
class _IgnoreScope {
  final bool blanket;
  final Set<String> ids;

  const _IgnoreScope(this.blanket, this.ids);

  static const empty = _IgnoreScope(false, {});

  bool matches(String gateId) => blanket || ids.contains(gateId);

  _IgnoreScope union(_IgnoreScope other) => _IgnoreScope(
        blanket || other.blanket,
        {...ids, ...other.ids},
      );
}

/// Parses every `// ignore:`-style comment on one source line and
/// unions their gate ids — one gate per marker, Dart lint style.
_IgnoreScope _parseLine(String? line, RegExp rule) {
  if (line == null) return _IgnoreScope.empty;
  var scope = _IgnoreScope.empty;
  for (final match in rule.allMatches(line)) {
    final id = match.group(1)!.trim();
    scope = scope.union(
      id.isEmpty ? const _IgnoreScope(true, {}) : _IgnoreScope(false, {id}),
    );
  }
  return scope;
}

/// Drops violations of ignorable gates suppressed by ignore markers.
///
/// A violation is suppressed when its file carries a file-scoped
/// marker that names the gate — `// crap:ignore-file` (everything) or
/// `// ignore-file:<ids>` — within the first 5 lines, or when the
/// violation's line or the line above carries a line-scoped marker
/// that names it — `// crap:ignore` or `// ignore:<ids>`. Violations
/// without a line number are only suppressed by the file-level
/// markers.
GateResult filterIgnored(GateResult result, GateContext context) {
  if (result.passed || result.violations.isEmpty) return result;
  final kept = <GateViolation>[];
  for (final violation in result.violations) {
    if (!_isIgnored(violation, result.gateId, context)) kept.add(violation);
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

bool _isIgnored(
  GateViolation violation,
  String gateId,
  GateContext context,
) {
  final path = p.isAbsolute(violation.file)
      ? violation.file
      : p.join(context.projectRoot, violation.file);
  if (_ignoredByFileMarker(path, gateId, context)) return true;
  final line = violation.line;
  if (line == null) return false;
  return _ignoredByLineMarker(path, line, gateId, context);
}

/// Whether [file]'s first five lines carry a file-scoped marker that
/// suppresses [gateId] (unreadable files are never ignored).
bool _ignoredByFileMarker(
  String file,
  String gateId,
  GateContext context,
) {
  if (!context.hasLine(file, 1)) return false;
  var scope = _IgnoreScope.empty;
  var blanket = false;
  for (var i = 1; i <= 5; i++) {
    final line = context.line(file, i);
    if (line == null) break;
    if (line.contains(ignoreFileMarker)) blanket = true;
    scope = scope.union(_parseLine(line, ignoreFileRule));
  }
  return blanket || scope.matches(gateId);
}

/// Whether [line] carries a suppressing marker itself, or the run of
/// whole-line ignore markers directly above it names [gateId] —
/// stacked `// ignore: a` / `// ignore: b` lines all apply to the
/// code line that ends the run.
bool _ignoredByLineMarker(
  String path,
  int line,
  String gateId,
  GateContext context,
) {
  final onLine = context.line(path, line);
  if (onLine != null) {
    if (onLine.contains(ignoreMarker)) return true;
    if (_parseLine(onLine, ignoreLineRule).matches(gateId)) return true;
  }
  var i = line - 1;
  while (i >= 1) {
    final above = context.line(path, i);
    if (above == null) return false;
    if (above.contains(ignoreMarker)) return true;
    final scope = _parseLine(above, ignoreLineRule);
    if (scope.matches(gateId)) return true;
    if (!_isWholeLineIgnoreMarker(above)) return false;
    i--;
  }
  return false;
}

/// Whether the line is nothing but an ignore comment — only such
/// lines continue the stacked-marker run above a violation.
bool _isWholeLineIgnoreMarker(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('// ignore:') ||
      trimmed.startsWith('// ignore-file:');
}
