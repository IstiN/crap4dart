/// Shared result types of the runner's command preparation steps.
library;

import '../config/config.dart';
import '../files/diff_parser.dart';

/// Outcome of `--diff` / `--diff-base` resolution: the diff line map,
/// the effective base ref, and whether diff mode is active at all.
typedef ResolvedDiff = ({DiffLineMap? map, String? base, bool ok});

/// Everything a command's run needs: the loaded config, the selected
/// files, the diff state and an early exit code (or `null` to proceed).
///
/// A class rather than a record: six fields outgrow the tuple idea
/// (the `record_size` gate caps records at five), and `partialSelection`
/// defaults to `false` at the type level.
class PreparedRun {
  /// Creates a [PreparedRun].
  const PreparedRun({
    this.config,
    this.files,
    this.diffMap,
    this.diffBase,
    this.partialSelection = false,
    this.exitCode,
  });

  /// The loaded configuration, `null` when the run stops early.
  final Crap4DartConfig? config;

  /// The selected files, `null` when the run stops early.
  final List<String>? files;

  /// The diff line map of a diff-scoped run, `null` otherwise.
  final DiffLineMap? diffMap;

  /// The effective diff base ref, `null` when not in diff mode.
  final String? diffBase;

  /// Whether [files] is a partial selection (diff/changed/staged).
  final bool partialSelection;

  /// The early exit code, or `null` to proceed with the command.
  final int? exitCode;
}
