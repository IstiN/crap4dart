import 'dart:io';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// One directory to check with its effective cap.
typedef FolderCap = ({String dir, int cap});

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
    final checks = _checks(context, config);
    final violations = <GateViolation>[];
    var checked = 0;
    for (final check in checks) {
      final units = _unitCount(context, check.dir, config);
      checked++;
      if (units > check.cap) {
        violations.add(
          GateViolation(
            file: check.dir,
            message: '$units loose .dart files directly in '
                '${check.dir} — group them into feature packages '
                '(max ${check.cap})',
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

  /// Every directory to check with its effective cap: the list form
  /// gives every directory [FolderStructureGateConfig.maxLooseFiles];
  /// the map form gives each pattern's directory its own cap (a
  /// directory matched by several patterns uses the first one's).
  List<FolderCap> _checks(
    GateContext context,
    FolderStructureGateConfig config,
  ) {
    final out = <FolderCap>[];
    final seen = <String>{};
    void add(String dir, int cap) {
      if (!seen.add(dir)) return; // first pattern wins
      out.add((dir: dir, cap: cap));
    }

    if (config.caps.isNotEmpty) {
      for (final entry in config.caps.entries) {
        for (final dir in _expand(context, entry.key)) {
          add(dir, entry.value);
        }
      }
      return out;
    }
    for (final dir in _expandList(context, config.dirs)) {
      add(dir, config.maxLooseFiles);
    }
    return out;
  }

  /// The configured list entries resolved to existing directories: a
  /// literal path passes through (when it exists); a glob pattern
  /// expands to every matching directory under the project root.
  List<String> _expandList(GateContext context, List<String> entries) {
    final resolved = <String>{};
    for (final entry in entries) {
      resolved.addAll(_expand(context, entry));
    }
    return resolved.toList()..sort();
  }

  /// One `dirs` entry resolved to existing directories.
  List<String> _expand(GateContext context, String entry) {
    if (Directory('${context.projectRoot}/$entry').existsSync()) {
      return [entry];
    }
    return _globDirs(context, entry);
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
