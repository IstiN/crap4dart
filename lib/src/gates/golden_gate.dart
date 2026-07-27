import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `golden` gate: requires golden (screenshot) tests for widgets.
///
/// Widgets are public classes in `gates.golden.widget_dirs` extending one of
/// [widgetBaseClasses]. A widget counts as covered when a test file under
/// `gates.golden.test_dirs` both invokes `matchesGoldenFile` and references
/// the widget — by name or by an import of the widget's file.
///
/// Skipped for non-Flutter projects and for projects without widgets.
class GoldenGate implements Gate {
  /// Creates a [GoldenGate].
  const GoldenGate();

  /// Superclass names that mark a class as a widget.
  static const Set<String> widgetBaseClasses = {
    'StatelessWidget',
    'StatefulWidget',
    'ConsumerWidget',
    'ConsumerStatefulWidget',
  };

  @override
  String get id => 'golden';

  @override
  Future<GateResult> run(GateContext context) async {
    if (!context.isFlutterProject) {
      return GateResult.skip(id, 'not a Flutter project');
    }
    final config = context.config.gates.golden;
    final widgets =
        _findWidgets(context, config.widgetDirs, config.excludeWidgets.toSet());
    if (widgets.isEmpty) return GateResult.skip(id, 'no widgets found');
    final covered = _findCoveredWidgets(context, config.testDirs, widgets);
    final percent = covered.length / widgets.length * 100;
    final summary = '${covered.length}/${widgets.length} widgets with golden '
        'tests (${percent.toStringAsFixed(1)}%)';
    if (percent >= config.minWidgetCoverage) {
      return GateResult.pass(id, summary: summary);
    }
    final violations = [
      for (final widget in widgets)
        if (!covered.contains(widget.name))
          GateViolation(
            file: widget.file,
            line: widget.line,
            message: 'widget ${widget.name} has no golden test',
          ),
    ];
    return GateResult.fail(id, violations, summary: summary);
  }

  List<_WidgetInfo> _findWidgets(
    GateContext context,
    List<String> widgetDirs,
    Set<String> excludeWidgets,
  ) {
    final widgets = <_WidgetInfo>[];
    for (final file in _dartFiles(context.projectRoot, widgetDirs)) {
      final parsed = DartParser().parse(
        content: File(file).readAsStringSync(),
        path: file,
      );
      final visitor = _WidgetVisitor(
        context.relativePath(file),
        parsed,
        excludeWidgets,
      );
      parsed.unit.accept(visitor);
      widgets.addAll(visitor.widgets);
    }
    return widgets;
  }

  Set<String> _findCoveredWidgets(
    GateContext context,
    List<String> testDirs,
    List<_WidgetInfo> widgets,
  ) {
    final covered = <String>{};
    final byName = {for (final w in widgets) w.name: w};
    for (final file in _dartFiles(context.projectRoot, testDirs)) {
      final parsed = DartParser().parse(
        content: File(file).readAsStringSync(),
        path: file,
      );
      final visitor = _GoldenTestVisitor();
      parsed.unit.accept(visitor);
      if (!visitor.hasGoldenMatcher) continue;
      covered.addAll(visitor.referencedTypes.where(byName.containsKey));
      covered.addAll(_widgetsFromImports(visitor.importUris, widgets));
    }
    return covered;
  }

  Set<String> _widgetsFromImports(
    Set<String> importUris,
    List<_WidgetInfo> widgets,
  ) =>
      {
        for (final widget in widgets)
          if (importUris.any(
            (uri) =>
                uri.endsWith(widget.file) ||
                uri.endsWith(_withoutLibPrefix(widget.file)),
          ))
            widget.name,
      };

  String _withoutLibPrefix(String path) =>
      path.startsWith('lib/') ? path.substring(4) : path;

  List<String> _dartFiles(String projectRoot, List<String> dirs) => [
        for (final dir in dirs)
          if (Directory(p.join(projectRoot, dir)).existsSync())
            ...Directory(p.join(projectRoot, dir))
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .map((f) => f.path),
      ];
}

class _WidgetInfo {
  _WidgetInfo(this.name, this.file, this.line);

  final String name;
  final String file;
  final int line;
}

class _WidgetVisitor extends RecursiveAstVisitor<void> {
  _WidgetVisitor(this._file, this._parsed, this._exclude);

  final String _file;
  final ParsedUnit _parsed;
  final Set<String> _exclude;
  final List<_WidgetInfo> widgets = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass.name2.lexeme;
    final name = node.name.lexeme;
    if (superclass != null &&
        GoldenGate.widgetBaseClasses.contains(superclass) &&
        !name.startsWith('_') &&
        !_exclude.contains(name)) {
      widgets.add(
        _WidgetInfo(
          name,
          _file,
          _parsed.lineInfo.getLocation(node.name.offset).lineNumber,
        ),
      );
    }
    super.visitClassDeclaration(node);
  }
}

class _GoldenTestVisitor extends RecursiveAstVisitor<void> {
  bool hasGoldenMatcher = false;
  final Set<String> referencedTypes = {};
  final Set<String> importUris = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'matchesGoldenFile') hasGoldenMatcher = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    referencedTypes.add(node.name2.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Bare type references in expression position (e.g.
    // `find.byType(MyWidget)`) parse as identifiers in an unresolved AST.
    referencedTypes.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) importUris.add(uri);
    super.visitImportDirective(node);
  }
}
