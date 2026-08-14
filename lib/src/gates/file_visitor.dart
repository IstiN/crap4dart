import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// Outcome of visiting a single file: how many declarations were checked
/// and the violations found among them.
typedef FileVisitOutcome = (int checked, List<GateViolation> violations);

/// Runs [visit] on every file in [context.files] that is not matched by
/// [exclude], and returns the accumulated outcome across all files.
FileVisitOutcome visitGateFiles(
  GateContext context,
  List<String> exclude,
  FileVisitOutcome Function(String relative, ParsedUnit parsed) visit,
) {
  var checked = 0;
  final violations = <GateViolation>[];
  for (final file in context.files) {
    if (context.matchesAnyGlob(file, exclude)) continue;
    final parsed = context.parsed(file);
    final outcome = visit(context.relativePath(file), parsed);
    checked += outcome.$1;
    violations.addAll(outcome.$2);
  }
  return (checked, violations);
}
