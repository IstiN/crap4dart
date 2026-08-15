import 'dart:io';

import 'package:path/path.dart' as p;

/// Rewrites pubspec.yaml for the temp copy of a workspace member.
class WorkspacePubspec {
  /// Creates a rewriter for the member at [projectRoot].
  WorkspacePubspec(this.projectRoot);

  /// The workspace member being profiled.
  final String projectRoot;

  static const String _pubspecFileName = 'pubspec.yaml';

  /// Writes a standalone `pubspec.yaml` for the temp copy: strips the
  /// `resolution: workspace` marker (the temp dir belongs to no
  /// workspace), absolutizes relative `path:` dependencies (from one
  /// level deeper they would resolve to the wrong directory), and
  /// carries over the workspace root's `dependency_overrides:` section —
  /// it is what makes conflicting member constraints resolve inside the
  /// workspace, and without it `pub get` in the temp dir fails.
  void writeStandalone(Directory tempDir) {
    final src = File(p.join(projectRoot, _pubspecFileName));
    final absRoot = p.absolute(projectRoot);
    final overrides = dependencyOverrides();
    final rewritten = StringBuffer();
    var wroteOverrides = overrides == null;
    for (final line in src.readAsLinesSync()) {
      if (_workspaceMarker.hasMatch(line)) continue;
      if (_overridesHeader.hasMatch(line)) {
        // The member has its own overrides; the workspace root's win.
        wroteOverrides = true;
      }
      final dep = _relativePathDep.firstMatch(line);
      if (dep != null) {
        final abs = p.normalize(p.join(absRoot, dep.group(2)!));
        rewritten.writeln('${dep.group(1)}$abs');
        continue;
      }
      rewritten.writeln(line);
    }
    if (!wroteOverrides && overrides != null) {
      rewritten
        ..writeln()
        ..writeln('# Inherited from the workspace root pubspec.')
        ..writeln('dependency_overrides:')
        ..write(overrides);
    }
    File(p.join(tempDir.path, _pubspecFileName))
        .writeAsStringSync(rewritten.toString());
  }

  /// The `dependency_overrides:` section (with body, without the
  /// header) of the nearest ancestor pubspec that declares a
  /// `workspace:` listing this package, or null when there is none.
  String? dependencyOverrides() {
    Directory? dir = Directory(p.absolute(projectRoot)).parent;
    while (dir != null) {
      final overrides = _overridesOfPubspecAt(dir.path);
      if (overrides != null) return overrides;
      // Stop at the filesystem root (parent of '/' is '/' itself).
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// The overrides body of a workspace pubspec at [dir], or `null`
  /// when the pubspec is absent, not a workspace root, or declares no
  /// overrides.
  String? _overridesOfPubspecAt(String dir) {
    final pubspec = File(p.join(dir, _pubspecFileName));
    if (!pubspec.existsSync()) return null;
    final content = pubspec.readAsStringSync();
    if (!RegExp(r'^workspace:', multiLine: true).hasMatch(content)) {
      return null;
    }
    final start = RegExp(
      r'^dependency_overrides:\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (start == null) return null;
    // Keep only the section body: up to the next top-level key.
    final tail = content.substring(start.end);
    final nextKey = RegExp(
      r'^[A-Za-z][A-Za-z0-9_-]*:',
      multiLine: true,
    ).firstMatch(tail);
    return nextKey == null ? tail : tail.substring(0, nextKey.start);
  }

  /// The `resolution: workspace` marker line of a member pubspec.
  static final RegExp _workspaceMarker =
      RegExp(r'^resolution:\s*workspace\s*$');

  /// The `dependency_overrides:` section header line.
  static final RegExp _overridesHeader = RegExp(r'^dependency_overrides:\s*$');

  /// A relative `path:` dependency line (`group(1)` is the prefix,
  /// `group(2)` the relative path).
  static final RegExp _relativePathDep =
      RegExp(r'^(\s*path:\s*)(\.\.?[/\\].*)$');
}
