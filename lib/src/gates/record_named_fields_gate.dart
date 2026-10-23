import 'gate.dart';
import 'gate_context.dart';
import 'record_types_analyzer.dart';

/// The `record_named_fields` gate: record fields must be named.
///
/// Two violation kinds from the shared record scan: a positional
/// (unnamed) record field in a signature, and a `.$1`-style positional
/// field access anywhere — the access carries zero self-documentation
/// and is the fingerprint of positional shapes. Use named fields
/// (`({int x, int y})`), a destructuring pattern, or a class.
///
/// Record *values* (literals, locals, destructuring patterns) remain
/// legal; record type aliases are the blessed declaration form and
/// their internals are not scanned.
///
/// Default severity is `warning`: a positional shape is a readability
/// debt, not a bug.
class RecordNamedFieldsGate implements Gate {
  /// Creates a [RecordNamedFieldsGate].
  const RecordNamedFieldsGate();

  @override
  String get id => 'record_named_fields';

  @override
  Future<GateResult> run(GateContext context) async {
    return runRecordGate(context, id, const {
      RecordFindingKind.unnamedFields,
      RecordFindingKind.positionalAccess,
    });
  }
}
