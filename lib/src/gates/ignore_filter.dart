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

/// Granular line marker — `// ignore:<gate-id>[,<gate-id>...]` —
/// suppresses only the named gates on its line (or the following
/// line). An empty list (`// ignore:`) suppresses every ignorable
/// gate, matching [ignoreMarker].
final RegExp ignoreLineRule = RegExp(r'//\s*ignore:([^/]*)');

/// Granular file marker — `// ignore-file:<gate-id>[,<gate-id>...]` —
/// suppresses only the named gates in the whole file (first 5 lines).
/// An empty list matches [ignoreFileMarker].
final RegExp ignoreFileRule = RegExp(r'//\s*ignore-file:([^/]*)');

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
/// unions their gate-id sets.
_IgnoreScope _parseLine(String? line, RegExp rule) {
  if (line == null) return _IgnoreScope.empty;
  var scope = _IgnoreScope.empty;
  for (final match in rule.allMatches(line)) {
    final list = match.group(1)!.trim();
    if (list.isEmpty) {
      scope = scope.union(const _IgnoreScope(true, {}));
      continue;
    }
    final ids = [
      for (final id in list.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ];
    scope = scope.union(
      ids.isEmpty
          ? const _IgnoreScope(true, {})
          : _IgnoreScope(false, ids.toSet()),
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

/// Whether [line] (or the line above it) of [path] carries a
/// line-scoped marker that suppresses [gateId].
bool _ignoredByLineMarker(
  String path,
  int line,
  String gateId,
  GateContext context,
) {
  final onLine = context.line(path, line);
  final aboveLine = line > 1 ? context.line(path, line - 1) : null;
  for (final source in [onLine, aboveLine]) {
    if (source == null) continue;
    if (source.contains(ignoreMarker)) return true;
    if (_parseLine(source, ignoreLineRule).matches(gateId)) return true;
  }
  return false;
}
