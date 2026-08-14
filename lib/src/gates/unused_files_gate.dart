import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `unused_files` gate: flags files under `gates.unused_files.dirs`
/// (default `lib`) that are never imported by any analyzed file. Files
/// containing a `main()`, `part of` files and the package entry library
/// (`lib/<packageName>.dart`) are never reported.
class UnusedFilesGate implements Gate {
  /// Creates an [UnusedFilesGate].
  const UnusedFilesGate();

  @override
  String get id => 'unused_files';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.unusedFiles;
    final imported = <String>{};
    final candidates = <String>[];
    for (final file in context.files) {
      final relative = context.relativePath(file);
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      imported.addAll(_importedTargets(parsed, relative, context));
      if (_isCandidate(parsed, relative, config.dirs, context)) {
        candidates.add(relative);
      }
    }
    final violations = [
      for (final candidate in candidates)
        if (!imported.contains(candidate))
          GateViolation(file: candidate, message: 'file is never imported'),
    ];
    final summary = violations.isEmpty
        ? '${candidates.length} files in ${config.dirs.join(', ')} are used'
        : '${violations.length}/${candidates.length} files are never '
            'imported';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Project-relative paths imported by [relative]'s unit.
  Set<String> _importedTargets(
    ParsedUnit parsed,
    String relative,
    GateContext context,
  ) {
    final targets = <String>{};
    for (final directive in parsed.unit.directives) {
      if (directive is! ImportDirective) continue;
      final target =
          _resolveImport(directive.uri.stringValue, relative, context);
      if (target != null) targets.add(target);
    }
    return targets;
  }

  /// Whether [relative] is a checkable candidate: inside [dirs], not a
  /// `part of` file, no `main()`, and not the package entry library.
  bool _isCandidate(
    ParsedUnit parsed,
    String relative,
    List<String> dirs,
    GateContext context,
  ) {
    if (!_inDirs(relative, dirs)) return false;
    if (parsed.unit.directives.any((d) => d is PartOfDirective)) {
      return false;
    }
    final visitor = _MainVisitor();
    parsed.unit.accept(visitor);
    if (visitor.hasMain) return false;
    return relative != p.join('lib', '${context.packageName}.dart');
  }

  bool _inDirs(String relative, List<String> dirs) => dirs.any(
        (dir) => relative == dir || relative.startsWith('$dir/'),
      );

  /// Resolves an import URI to a project-relative path when it targets
  /// the project itself; `null` for external packages and dart: URIs.
  String? _resolveImport(
    String? uri,
    String importerRelative,
    GateContext context,
  ) {
    if (uri == null || uri.startsWith('dart:')) return null;
    if (uri.startsWith('package:')) {
      final rest = uri.substring('package:'.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) return null;
      if (rest.substring(0, slash) != context.packageName) return null;
      return p.join('lib', rest.substring(slash + 1));
    }
    final importerDir = p.dirname(importerRelative);
    return p.normalize(p.join(importerDir, uri));
  }
}

/// Detects whether a compilation unit declares a `main` function.
class _MainVisitor extends RecursiveAstVisitor<void> {
  bool hasMain = false;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit && node.name.lexeme == 'main') {
      hasMain = true;
    }
  }
}
