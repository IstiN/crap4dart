/// Shared result types of the runner's command preparation steps.
library;

import '../config/config.dart';
import '../files/diff_parser.dart';

/// Outcome of `--diff` / `--diff-base` resolution: the diff line map,
/// the effective base ref, and whether diff mode is active at all.
typedef ResolvedDiff = ({DiffLineMap? map, String? base, bool ok});

/// Everything a command's run needs: the loaded config, the selected
/// files, the diff state and an early exit code (or `null` to proceed).
typedef PreparedRun = ({
  Crap4DartConfig? config,
  List<String>? files,
  DiffLineMap? diffMap,
  String? diffBase,
  bool partialSelection,
  int? exitCode,
});
