import 'dart:io';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `folder_structure` gate.
///
/// Two checks over the configured `dirs` (literal paths or glob
/// patterns — `lib/src/*`, `packages/**` — expand to every matching
/// directory):
///
/// - **Loose-file sprawl** (`max_loose_files`, default 0): a directory
///   holding more `.dart` files directly than allowed — a flat-file
///   sprawl that should be organized into feature packages. Typical
///   AI artifact: instead of creating a domain package, an agent keeps
///   dumping sibling files into one directory until nothing is
///   findable.
/// - **Fan-out cap** (`max_files`, disabled by default): a directory
///   holding more `.dart` files in its whole subtree — bounded
///   fan-out keeps navigation cheap even when the direct structure
///   looks organized (the experiment evidence: one 310-file package
///   inside a decent human structure was the worst exploration
///   hotspot).
///
/// Counting rules (both checks): generated siblings of a source file
/// collapse into one logical unit — `magic.dart`, `magic.g.dart`,
/// `magic.freezed.dart` share the stem `magic` and count once; `exclude`
/// globs exempt matching paths (files for the loose count, files or
/// whole subdirectories for the fan-out count).
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
    var looseDirs = 0;
    for (final dir in dirs) {
      final loose = _looseCount(context, dir, config);
      looseDirs++;
      if (loose > config.maxLooseFiles) {
        violations.add(
          GateViolation(
            file: dir,
            message: '$loose loose .dart files directly in '
                '$dir — group them into feature packages '
                '(max ${config.maxLooseFiles})',
          ),
        );
      }
      if (config.maxFiles == null) continue;
      final fanOut = _fanOutCount(context, dir, config);
      if (fanOut > config.maxFiles!) {
        violations.add(
          GateViolation(
            file: dir,
            message: '$fanOut source files under $dir (recursively) — '
                'split into subpackages (max_files ${config.maxFiles})',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$looseDirs directories organized into packages'
        : '${violations.length} directory(ies) over their file limits';
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
  int _looseCount(
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

  /// Number of distinct logical `.dart` units in [dir]'s whole
  /// subtree. Excluded files don't count; an excluded directory
  /// removes its subtree.
  int _fanOutCount(
    GateContext context,
    String dir,
    FolderStructureGateConfig config,
  ) {
    final root = Directory('${context.projectRoot}/$dir');
    if (!root.existsSync()) return 0;
    final stems = <String>{};
    void walk(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (context.matchesAnyGlob(entity.path, config.exclude)) {
          continue; // excluded file — or excluded directory subtree
        }
        if (entity is Directory) {
          walk(entity);
        } else if (entity is File && entity.path.endsWith('.dart')) {
          stems.add(_stem(entity.path));
        }
      }
    }

    walk(root);
    return stems.length;
  }

  /// The logical unit of a Dart file: everything before the first
  /// dot of the basename — `magic.dart`, `magic.g.dart` and
  /// `magic.freezed.dart` are one unit named `magic`; generated
  /// siblings never inflate a count.
  String _stem(String path) =>
      path.split(Platform.pathSeparator).last.split('.').first;
}
