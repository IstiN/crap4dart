import '../gate.dart';
import '../gate_context.dart';
import 'record_types_analyzer.dart';

/// The `inline_record_types` gate: record types must be named.
///
/// Flags an inline record type annotation in a function signature
/// (return type or parameter type, including nested in `Future<...>`
/// type arguments): consumers diff the shape field-by-field instead of
/// going to one type definition, and "similar but not exact" inline
/// shapes silently drift apart. Declare the shape as a `typedef` (or a
/// class when nominal identity is needed) and reference it by name.
///
/// Record type aliases are the blessed declaration form and are not
/// scanned; a function-type alias blesses nothing — an inline record
/// inside `typedef F = int Function((int, int));` is still flagged.
///
/// Default severity is `warning`: shape drift is a maintainability
/// risk, not a bug.
class InlineRecordTypesGate implements Gate {
  /// Creates an [InlineRecordTypesGate].
  const InlineRecordTypesGate();

  @override
  String get id => 'inline_record_types';

  @override
  Future<GateResult> run(GateContext context) async {
    return runRecordGate(context, id, const {
      RecordFindingKind.inlineType,
    });
  }
}
