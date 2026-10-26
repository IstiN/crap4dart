import 'dart:io';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `folder_structure` gate: flags directories that accumulate more
/// than `max_files` logical `.dart` units directly — a flat-file
/// sprawl that should be organized into feature packages.
///
/// Loose-file sprawl is a typical AI artifact: instead of creating a
/// domain package (`lib/src/web_search/`), an agent keeps dumping
/// sibling files into a directory until nothing is findable. Only a
/// directory's OWN contents count — files in subdirectories are the
/// organized form, and a parent is never penalized for a tidy tree
/// below it (configure the directories you care about, or a glob like
/// `lib/src/*` to check each package on its own).
///
/// Counting rules: generated siblings of a source file collapse into
/// one logical unit — `magic.dart`, `magic.g.dart`,
/// `magic.freezed.dart` share the stem `magic` and count once;
/// `exclude` globs exempt matching files.
class FolderStructureGate implements Gate {
  /// Creates a [FolderStructureGate].
  const FolderStructureGate();

  @override
  String get id => 'folder_structure';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.folderStructure;
    final dirs = _resolveDirs(context, config);
    final violations = <GateViolation>[];
    var checked = 0;
    for (final dir in dirs) {
      final units = _unitCount(context, dir, config);
      checked++;
      if (units > config.maxLooseFiles) {
        violations.add(
          GateViolation(
            file: dir,
            message: '$units loose .dart files directly in '
                '$dir — group them into feature packages '
                '(max ${config.maxLooseFiles})',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked directories organized into packages'
        : '${violations.length} directory(ies) with file sprawl';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// The configured `dirs` entries resolved to existing directories:
  /// a literal path passes through (when it exists); a glob pattern
  /// expands to every matching directory under the project root.
  List<String> _resolveDirs(
    GateContext context,
    FolderStructureGateConfig config,
  ) {
    final resolved = <String>{};
    for (final entry in config.dirs) {
      final literal = Directory('${context.projectRoot}/$entry');
      if (literal.existsSync()) {
        resolved.add(entry);
        continue;
      }
      resolved.addAll(_globDirs(context, entry));
    }
    return resolved.toList()..sort();
  }

  /// Every directory under the project root matching [pattern].
  /// Skips hidden, build and tooling directories — structure gates
  /// have no business enumerating `.git` or `.dart_tool`.
  List<String> _globDirs(GateContext context, String pattern) {
    final root = Directory(context.projectRoot);
    const skip = {'.git', '.dart_tool', 'build', '.idea', '.fah'};
    final found = <String>[];
    void walk(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = entity.path
            .split(Platform.pathSeparator)
            .where((segment) => segment.isNotEmpty)
            .last;
        if (name.startsWith('.') || skip.contains(name)) continue;
        found.add(context.relativePath(entity.path));
        walk(entity);
      }
    }

    walk(root);
    return found
        .where((dir) => context.matchesAnyGlob(dir, [pattern]))
        .toList();
  }

  /// Number of distinct logical `.dart` units directly inside [dir]:
  /// files grouped by stem (see [_stem]), so generated siblings do
  /// not inflate the count.
  int _unitCount(
    GateContext context,
    String dir,
    FolderStructureGateConfig config,
  ) {
    final stems = <String>{};
    for (final entity in Directory('${context.projectRoot}/$dir').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (context.matchesAnyGlob(entity.path, config.exclude)) continue;
      stems.add(_stem(entity.path));
    }
    return stems.length;
  }

  /// The logical unit of a Dart file: everything before the first
  /// dot of the basename — `magic.dart`, `magic.g.dart` and
  /// `magic.freezed.dart` are one unit named `magic`; generated
  /// siblings never inflate a count.
  String _stem(String path) =>
      path.split(Platform.pathSeparator).last.split('.').first;
}
