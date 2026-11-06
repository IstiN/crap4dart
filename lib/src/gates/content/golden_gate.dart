import '../../common/constants.dart';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../../analysis/dart_parser.dart';
import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// The `golden` gate: requires golden (screenshot) tests for widgets.
///
/// Widgets are public classes in `gates.golden.widget_dirs` extending one of
/// [widgetBaseClasses]. A widget counts as covered when a test file under
/// `gates.golden.test_dirs` both invokes `matchesGoldenFile` and references
/// the widget — by name or by an import of the widget's file.
///
/// Skipped for non-Flutter projects and for projects without widgets.
class GoldenGate implements Gate {
  /// Superclass names that mark a class as a widget.
  static const Set<String> widgetBaseClasses = {
    'StatelessWidget',
    'StatefulWidget',
    'ConsumerWidget',
    'ConsumerStatefulWidget',
  };

  /// Creates a [GoldenGate].
  const GoldenGate();

  @override
  String get id => GateIds.golden;

  @override
  Future<GateResult> run(GateContext context) async {
    if (!context.isFlutterProject) {
      return GateResult.skip(id, kNotFlutterProject);
    }
    final config = context.config.gates.golden;
    final widgets =
        _findWidgets(context, config.widgetDirs, config.excludeWidgets.toSet());
    if (widgets.isEmpty) return GateResult.skip(id, 'no widgets found');
    final matrixViolations = config.requireViewportMatrix
        ? _matrixViolations(context, config.testDirs)
        : <GateViolation>[];
    final covered = _findCoveredWidgets(context, config.testDirs, widgets);
    final percent = covered.length / widgets.length * 100;
    final summary = '${covered.length}/${widgets.length} widgets with golden '
        'tests (${percent.toStringAsFixed(1)}%)';
    final violations = [
      ...matrixViolations,
      if (percent < config.minWidgetCoverage)
        for (final widget in widgets)
          if (!covered.contains(widget.name))
            GateViolation(
              file: widget.file,
              line: widget.line,
              message: 'widget ${widget.name} has no golden test',
            ),
    ];
    if (violations.isEmpty) {
      return GateResult.pass(id, summary: summary);
    }
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
    for (final goldenTest in _goldenTests(context, testDirs)) {
      covered.addAll(goldenTest.referencedTypes.where(byName.containsKey));
      covered.addAll(_widgetsFromImports(goldenTest.importUris, widgets));
    }
    return covered;
  }

  /// Golden test files under [testDirs] — files invoking
  /// `matchesGoldenFile` — parsed once each with their visitor.
  Iterable<_GoldenTestVisitor> _goldenTests(
    GateContext context,
    List<String> testDirs,
  ) sync* {
    for (final file in _dartFiles(context.projectRoot, testDirs)) {
      final parsed = DartParser().parse(
        content: File(file).readAsStringSync(),
        path: file,
      );
      final visitor = _GoldenTestVisitor();
      parsed.unit.accept(visitor);
      if (!visitor.hasGoldenMatcher) continue;
      visitor.file = context.relativePath(file);
      yield visitor;
    }
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

  /// Golden test files under [testDirs] that never vary theme
  /// (light/dark) or viewport (phone/desktop) — the visual-regression
  /// matrix. A golden test that always pumps the same surface records
  /// one quadrant of the matrix and silently misses regressions in the
  /// others (e.g. a theme scope lost on pushed routes).
  List<GateViolation> _matrixViolations(
    GateContext context,
    List<String> testDirs,
  ) =>
      [
        for (final goldenTest in _goldenTests(context, testDirs))
          if (!goldenTest.hasThemeVariation || !goldenTest.hasViewportVariation)
            GateViolation(
              file: goldenTest.file,
              message: 'golden test never varies '
                  '${_missingAxes(goldenTest)} — a single-surface '
                  'golden misses theme-scope and layout regressions '
                  'on the other surfaces',
            ),
      ];

  /// The matrix axes [goldenTest] does not vary.
  String _missingAxes(_GoldenTestVisitor goldenTest) => [
        if (!goldenTest.hasThemeVariation) 'theme (light/dark)',
        if (!goldenTest.hasViewportVariation) 'viewport (phone/desktop)',
      ].join(' and ');

  String _withoutLibPrefix(String path) =>
      path.startsWith(kLibPrefix) ? path.substring(kLibPrefix.length) : path;

  List<String> _dartFiles(String projectRoot, List<String> dirs) => [
        for (final dir in dirs)
          if (Directory(p.join(projectRoot, dir)).existsSync())
            ...Directory(p.join(projectRoot, dir))
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith(kDartExtension))
                .map((f) => f.path),
      ];
}

class _WidgetInfo {
  final String name;

  final String file;

  final int line;

  _WidgetInfo(this.name, this.file, this.line);
}

class _WidgetVisitor extends RecursiveAstVisitor<void> {
  final String _file;

  final ParsedUnit _parsed;

  final Set<String> _exclude;

  final List<_WidgetInfo> widgets = [];

  _WidgetVisitor(this._file, this._parsed, this._exclude);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass.name.lexeme;
    final name = node.namePart.typeName.lexeme;
    if (superclass != null &&
        GoldenGate.widgetBaseClasses.contains(superclass) &&
        !name.startsWith('_') &&
        !_exclude.contains(name)) {
      widgets.add(
        _WidgetInfo(
          name,
          _file,
          _parsed.lineInfo
              .getLocation(node.namePart.typeName.offset)
              .lineNumber,
        ),
      );
    }
    super.visitClassDeclaration(node);
  }
}

class _GoldenTestVisitor extends RecursiveAstVisitor<void> {
  /// Project-relative path of the test file, set by [GoldenGate._goldenTests].
  String file = '';

  bool hasGoldenMatcher = false;
  bool hasThemeVariation = false;
  bool hasViewportVariation = false;
  final Set<String> referencedTypes = {};
  final Set<String> importUris = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'matchesGoldenFile') hasGoldenMatcher = true;
    _trackMatrix(node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    referencedTypes.add(node.name.lexeme);
    _trackMatrix(node.name.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Bare type references in expression position (e.g.
    // `find.byType(MyWidget)`) parse as identifiers in an unresolved AST.
    referencedTypes.add(node.name);
    _trackMatrix(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) importUris.add(uri);
    super.visitImportDirective(node);
  }

  /// Marks the theme/viewport axis when [name] matches one of the
  /// matrix variation patterns. Matching is lexical — helper
  /// functions like `pumpGolden(tester, theme: ...)` surface as
  /// identifiers carrying the theme/viewport signal.
  void _trackMatrix(String name) {
    final lower = name.toLowerCase();
    if (_themePattern.hasMatch(lower)) hasThemeVariation = true;
    if (_viewportPattern.hasMatch(lower)) hasViewportVariation = true;
  }

  static final RegExp _themePattern = RegExp(r'theme|brightness|dark|light');

  static final RegExp _viewportPattern = RegExp(
    r'surface|viewport|screensize|screen_size|phone|desktop|device|'
    r'orientation|narrow|wide',
  );
}
