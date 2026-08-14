import 'package:analyzer/dart/ast/ast.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// A compiled rule of the `banned_imports` gate.
class _CompiledRule {
  _CompiledRule(this.from, this.forbid, this.message);

  final Glob from;
  final List<Glob> forbid;
  final String? message;
}

/// The `banned_imports` gate: enforces architectural boundaries declared
/// in `gates.banned_imports.rules`. Each rule maps a `from` glob of the
/// importing file to `forbid` globs matched against import URIs (and,
/// for relative and `package:<self>` imports, against their
/// project-relative resolved paths).
class BannedImportsGate implements Gate {
  /// Creates a [BannedImportsGate].
  const BannedImportsGate();

  @override
  String get id => 'banned_imports';

  @override
  Future<GateResult> run(GateContext context) async {
    final rules = context.config.gates.bannedImports.rules;
    if (rules.isEmpty) {
      return GateResult.pass(
        'banned_imports',
        summary: 'no rules configured',
      );
    }
    final compiled = [
      for (final rule in rules)
        _CompiledRule(
          Glob(rule.from),
          [for (final pattern in rule.forbid) Glob(pattern)],
          rule.message,
        ),
    ];
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final relative = context.relativePath(file);
      final applicable =
          compiled.where((rule) => rule.from.matches(relative)).toList();
      if (applicable.isEmpty) continue;
      checked++;
      violations.addAll(_violationsIn(file, relative, applicable, context));
    }
    final summary = violations.isEmpty
        ? '$checked files comply with ${rules.length} rule(s)'
        : '${violations.length} banned import(s) in $checked files';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Violations of [rules] in the imports of [file].
  List<GateViolation> _violationsIn(
    String file,
    String relative,
    List<_CompiledRule> rules,
    GateContext context,
  ) {
    final parsed = context.parsed(file);
    final violations = <GateViolation>[];
    for (final directive in parsed.unit.directives) {
      if (directive is! ImportDirective) continue;
      final violation =
          _firstViolation(directive, relative, rules, context, parsed);
      if (violation != null) violations.add(violation);
    }
    return violations;
  }

  /// The first rule violation of [directive], or `null`.
  GateViolation? _firstViolation(
    ImportDirective directive,
    String relative,
    List<_CompiledRule> rules,
    GateContext context,
    ParsedUnit parsed,
  ) {
    final line = parsed.lineInfo.getLocation(directive.offset).lineNumber;
    for (final rule in rules) {
      if (!_anyForbidMatches(rule, directive, relative, context)) continue;
      final extra = rule.message == null ? '' : ' — ${rule.message}';
      return GateViolation(
        file: relative,
        line: line,
        message: 'import ${directive.uri.stringValue} is banned '
            'for $relative$extra',
      );
    }
    return null;
  }

  /// Whether any `forbid` glob of [rule] matches [directive].
  bool _anyForbidMatches(
    _CompiledRule rule,
    ImportDirective directive,
    String relative,
    GateContext context,
  ) =>
      rule.forbid.any(
        (pattern) =>
            _matches(pattern, directive.uri.stringValue, relative, context),
      );

  /// Whether [pattern] matches the import [uri] or its resolved
  /// project-relative path ([importerRelative] is the importing file).
  bool _matches(
    Glob pattern,
    String? uri,
    String importerRelative,
    GateContext context,
  ) {
    if (uri == null) return false;
    if (pattern.matches(uri)) return true;
    final resolved = _resolve(uri, importerRelative, context);
    return resolved != null && pattern.matches(resolved);
  }

  /// Resolves a relative or self-`package:` import URI to a
  /// project-relative path; returns `null` for anything else.
  String? _resolve(
    String uri,
    String importerRelative,
    GateContext context,
  ) {
    if (uri.startsWith('package:')) {
      return _resolvePackage(uri, context.packageName);
    }
    if (uri.startsWith('dart:')) return null;
    final importerDir = p.dirname(importerRelative);
    return p.normalize(p.join(importerDir, uri));
  }

  /// Resolves a `package:<self>/...` URI to `lib/...`, or `null`.
  String? _resolvePackage(String uri, String? packageName) {
    if (packageName == null) return null;
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    if (slash <= 0 || rest.substring(0, slash) != packageName) return null;
    return p.join('lib', rest.substring(slash + 1));
  }
}
