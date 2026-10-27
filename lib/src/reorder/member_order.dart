import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../analysis/dart_parser.dart';

/// One body rewrite: the [BodyReplacement.start]..[BodyReplacement.end]
/// span of a class body and the [BodyReplacement.text] that replaces it.
typedef BodyReplacement = ({int start, int end, String text});

/// The canonical member order this tool enforces, following the
/// de-facto Dart/Flutter convention (Effective Dart itself prescribes
/// ordering only for directives; this sequence matches common practice
/// in the Flutter SDK and the ecosystem's `member-ordering` lints):
///
/// 1. constants (`static const`)
/// 2. static fields
/// 3. instance fields
/// 4. constructors
/// 5. static methods
/// 6. getters and setters
/// 7. public methods (and operators)
/// 8. private methods
///
/// Members of the same category keep their original relative order —
/// the transform is a stable partition, never an alphabetical sort.
class MemberOrder {
  static const int _constants = 0;

  static const int _staticFields = 1;

  static const int _fields = 2;

  static const int _constructors = 3;

  static const int _staticMethods = 4;

  static const int _accessors = 5;

  static const int _methods = 6;

  static const int _privateMethods = 7;

  const MemberOrder._();

  /// Category index of [member] in the canonical order.
  static int categoryOf(ClassMember member) => switch (member) {
        FieldDeclaration() => _fieldCategory(member),
        ConstructorDeclaration() => _constructors,
        MethodDeclaration() => _methodCategory(member),
        _ => _methods,
      };

  static int _fieldCategory(FieldDeclaration field) {
    if (!field.isStatic) return _fields;
    return field.fields.isConst ? _constants : _staticFields;
  }

  static int _methodCategory(MethodDeclaration method) {
    if (method.isStatic) return _staticMethods;
    if (method.isGetter || method.isSetter) return _accessors;
    return _isPrivate(method.name.lexeme) ? _privateMethods : _methods;
  }

  static bool _isPrivate(String name) => name.startsWith('_');
}

/// One sliced member: its source span (with attached doc comments,
/// metadata and directly-preceding `//` lines) plus its sort keys.
class _MemberSlice {
  final int category;

  final int index;

  final int start;

  final int end;

  const _MemberSlice(this.category, this.index, this.start, this.end);
}

/// Deterministically reorders class members of [source] into the
/// canonical [MemberOrder].
///
/// Pure function: the same input always produces the same output, and
/// already-canonical input is returned unchanged. Classes, mixins and
/// extensions are reordered; enums are left untouched (value order is
/// semantics). Comments directly above a member move with it.
String reorderSource(String source, {String path = ''}) {
  final parsed = DartParser().parse(content: source, path: path);
  final unit = parsed.unit;
  final lineInfo = parsed.lineInfo;
  // Apply replacements back-to-front so earlier offsets stay valid.
  final replacements = <BodyReplacement>[];

  for (final declaration in unit.declarations) {
    final members = _classMembers(declaration);
    if (members == null || members.isEmpty) continue;
    final body = _classBody(declaration);
    if (body == null) continue;
    final reordered = _reorderedSpan(
      members,
      source,
      lineInfo,
      body,
      declaration.end,
    );
    if (reordered != null) replacements.add(reordered);
  }

  var result = source;
  for (final (:start, :end, :text) in replacements.reversed) {
    result = result.substring(0, start) + text + result.substring(end);
  }
  return result;
}

/// The members of a class-like declaration, or null for non-class or
/// enum declarations (enum value order is semantics).
List<ClassMember>? _classMembers(CompilationUnitMember declaration) {
  if (declaration is EnumDeclaration) return null;
  if (declaration is ClassDeclaration) return declaration.body.members;
  if (declaration is MixinDeclaration) return declaration.body.members;
  if (declaration is ExtensionDeclaration) return declaration.body.members;
  return null;
}

/// The offset of a class-like declaration's opening brace, or null
/// for declarations this tool does not reorder.
int? _classBody(CompilationUnitMember declaration) {
  if (declaration is EnumDeclaration) return null;
  if (declaration is ClassDeclaration) return declaration.body.offset;
  if (declaration is MixinDeclaration) return declaration.body.offset;
  if (declaration is ExtensionDeclaration) {
    return declaration.body.offset;
  }
  return null;
}

/// Computes the reordered body span for one declaration, or null when
/// the members already follow the canonical order.
BodyReplacement? _reorderedSpan(
  List<ClassMember> members,
  String source,
  LineInfo lineInfo,
  int bodyStart,
  int declarationEnd,
) {
  final slices = <_MemberSlice>[];
  for (var i = 0; i < members.length; i++) {
    final member = members[i];
    final end = member.endToken.end;
    final boundary = i == 0 ? bodyStart + 1 : members[i - 1].endToken.end;
    final start = max(
      _sliceStart(source, lineInfo, member, boundary),
      boundary,
    );
    slices.add(_MemberSlice(MemberOrder.categoryOf(member), i, start, end));
  }
  final sorted = [...slices]..sort((a, b) {
      final byCategory = a.category.compareTo(b.category);
      return byCategory != 0 ? byCategory : a.index.compareTo(b.index);
    });
  // Already canonical? Keep the file byte-identical whatever its
  // member layout looks like (single-line bodies, odd spacing).
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].index != i) {
      final separator = source.contains('\r\n') ? '\r\n\r\n' : '\n\n';
      final spanStart = slices.map((s) => s.start).reduce(min);
      final bodyEnd = slices.map((s) => s.end).reduce(max);
      final canonical = sorted.map((s) => source.substring(s.start, s.end));
      final tail = source.substring(bodyEnd, declarationEnd);
      return (
        start: spanStart,
        end: declarationEnd,
        text: canonical.join(separator) + tail,
      );
    }
  }
  return null;
}

/// The first token offset of a member: declaration start, doc comment
/// or metadata — whichever comes first.
int _firstTokenOffset(ClassMember member) {
  var start = member.offset;
  final doc = member.documentationComment;
  if (doc != null && doc.offset < start) start = doc.offset;
  if (member.metadata.isNotEmpty) {
    final meta = member.metadata.first.offset;
    if (meta < start) start = meta;
  }
  return start;
}

/// The inclusive start offset of a member's slice: its first token
/// (doc comment and metadata included), extended upward over
/// whole-line `//` comments attached directly above it.
int _sliceStart(
  String source,
  LineInfo lineInfo,
  ClassMember member,
  int previousBoundary,
) {
  final start = _firstTokenOffset(member);
  var line0 = lineInfo.getLocation(start).lineNumber - 1;
  // Never walk above the previous member (or the class opening).
  final floor0 = lineInfo.getLocation(previousBoundary).lineNumber;
  while (line0 - 1 >= floor0) {
    final offset = lineInfo.getOffsetOfLine(line0 - 1);
    final lineText = source.substring(offset, _lineEnd(source, offset)).trim();
    if (lineText.startsWith('//')) {
      line0--;
      continue;
    }
    // A blank line continues the run only when the line above it is a
    // comment: one blank line between a comment block and its member
    // keeps them together; two (or a member boundary) detach.
    if (lineText.isEmpty && line0 - 2 >= floor0) {
      final above = source
          .substring(
            lineInfo.getOffsetOfLine(line0 - 2),
            _lineEnd(source, lineInfo.getOffsetOfLine(line0 - 2)),
          )
          .trim();
      if (above.startsWith('//')) {
        line0 -= 2;
        continue;
      }
    }
    break;
  }
  return lineInfo.getOffsetOfLine(line0);
}

int _lineEnd(String source, int from) {
  final newline = source.indexOf('\n', from);
  return newline == -1 ? source.length : newline;
}
