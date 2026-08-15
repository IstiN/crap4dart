import 'dart:io';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `folder_structure` gate: flags directories that accumulate more
/// than `max_loose_files` (default 0) `.dart` files directly — a
/// flat-file sprawl that should be organized into feature packages.
///
/// Loose-file sprawl is a typical AI artifact: instead of creating a
/// domain package (`lib/src/web_search/`), an agent keeps dumping
/// sibling files into a directory until nothing is findable.
class FolderStructureGate implements Gate {
  /// Creates a [FolderStructureGate].
  const FolderStructureGate();

  @override
  String get id => 'folder_structure';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.folderStructure;
    final violations = <GateViolation>[];
    var checked = 0;
    final looseFiles = <String, int>{
      for (final dir in _existingDirs(context, config))
        dir: _looseCount(context, dir, config),
    };
    for (final entry in looseFiles.entries) {
      checked++;
      if (entry.value > config.maxLooseFiles) {
        violations.add(
          GateViolation(
            file: entry.key,
            message: '${entry.value} loose .dart files directly in '
                '${entry.key} — group them into feature packages '
                '(max ${config.maxLooseFiles})',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked directories organized into packages'
        : '${violations.length} directory(ies) with loose-file sprawl';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Existing configured directory paths (project-relative).
  List<String> _existingDirs(
    GateContext context,
    FolderStructureGateConfig config,
  ) =>
      [
        for (final dir in config.dirs)
          if (Directory('${context.projectRoot}/$dir').existsSync()) dir,
      ];

  /// Number of non-excluded `.dart` files directly inside [dir].
  int _looseCount(
    GateContext context,
    String dir,
    FolderStructureGateConfig config,
  ) {
    var count = 0;
    for (final entity in Directory('${context.projectRoot}/$dir').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (context.matchesAnyGlob(entity.path, config.exclude)) continue;
      count++;
    }
    return count;
  }
}
