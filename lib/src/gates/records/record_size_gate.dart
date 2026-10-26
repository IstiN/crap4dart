import '../gate.dart';
import '../gate_context.dart';
import 'record_types_analyzer.dart';

/// The `record_size` gate: caps how many fields a record type may
/// have (`max_fields`, default 5).
///
/// A record with more fields than the cap has outgrown the tuple idea
/// — it carries structure that deserves a name per member, invariants,
/// and behavior. The gate counts positional plus named fields of every
/// record type annotation in a signature and of every record type
/// alias declaration, and asks to transform the record into a class.
///
/// Nested records count towards their own arity: the inner record of
/// `((int, int, int, int, int, int), bool)` is flagged, the outer
/// (2 fields) is not.
///
/// Default severity is `warning`: exceeding the cap is a design
/// signal, not a bug.
class RecordSizeGate implements Gate {
  /// Creates a [RecordSizeGate].
  const RecordSizeGate();

  @override
  String get id => 'record_size';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.recordSize;
    return runRecordGate(
      context,
      id,
      const {RecordFindingKind.oversized},
      maxFields: config.maxFields,
    );
  }
}
