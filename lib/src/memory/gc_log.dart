/// One row of the Dart VM `--verbose_gc` table.
class GcEvent {
  /// Creates a [GcEvent].
  const GcEvent({
    required this.isolate,
    required this.seq,
    required this.startSeconds,
    required this.newBeforeMb,
    required this.newAfterMb,
    required this.oldBeforeMb,
    required this.oldAfterMb,
  });

  /// Isolate name as printed (e.g. `main`, `test_suite:file:///…`).
  final String isolate;

  /// The GC number within the isolate.
  final int seq;

  /// Monotonic seconds since VM start.
  final double startSeconds;

  /// New-gen used before the GC, MB.
  final double newBeforeMb;

  /// New-gen used after the GC, MB.
  final double newAfterMb;

  /// Old-gen used before the GC, MB.
  final double oldBeforeMb;

  /// Old-gen used after the GC, MB.
  final double oldAfterMb;

  /// How much new-gen memory this GC reclaimed (allocated volume that
  /// had accumulated since the previous GC).
  double get reclaimedNewMb =>
      newBeforeMb > newAfterMb ? newBeforeMb - newAfterMb : 0;

  /// Signed old-gen growth across this GC (positive = objects
  /// promoted/retained, negative = old-gen memory freed).
  double get oldDeltaMb => oldAfterMb - oldBeforeMb;

  /// A copy with a different [isolate] (straggler reattribution).
  GcEvent copyWith({String? isolate}) => GcEvent(
        isolate: isolate ?? this.isolate,
        seq: seq,
        startSeconds: startSeconds,
        newBeforeMb: newBeforeMb,
        newAfterMb: newAfterMb,
        oldBeforeMb: oldBeforeMb,
        oldAfterMb: oldAfterMb,
      );
}

/// Tracks which isolate owns the rows arriving on the GC stream:
/// announcement lines switch the current isolate, and every row is
/// matched against BOTH isolates' GC-number continuations — the VM
/// numbers each isolate's GCs from 1, so a row continuing the previous
/// isolate's numbering (even after the new one opened) is a straggler
/// of the previous one.
class _IsolateTracker {
  var current = '';
  var previous = '';
  var _currentLastSeq = 0;
  var _previousLastSeq = 0;

  /// Consumes an announcement line; `true` when [line] was one.
  bool announce(String line) {
    final full = GcLogParser.fullIsolateName(line);
    if (full == null) return false;
    if (full != current) {
      previous = current;
      _previousLastSeq = _currentLastSeq;
      current = full;
      _currentLastSeq = 0;
    }
    return true;
  }

  /// Attributes [event] by GC-number continuation: the current
  /// isolate's next expected number wins; a row continuing the
  /// previous isolate's numbering is its late flush and returns to it.
  GcEvent assign(GcEvent event) {
    if (event.seq == _currentLastSeq + 1) {
      _currentLastSeq = event.seq;
      return event;
    }
    if (previous.isNotEmpty && event.seq == _previousLastSeq + 1) {
      _previousLastSeq = event.seq;
      return event.copyWith(isolate: previous);
    }
    // Unrecognized numbering: best effort — keep it with the current
    // isolate.
    _currentLastSeq = event.seq;
    return event;
  }
}

/// Parses the `--verbose_gc` table: fixed-column CSV rows between two
/// header lines, printed on stderr by the VM.
class GcLogParser {
  /// Whether [line] is a table row (starts with `[ ` and has the
  /// expected comma-separated shape).
  static bool isRow(String line) =>
      line.startsWith('[ ') &&
      line.contains(',') &&
      _numbers(line).length >= 15;

  /// The events of a full log, in order.
  ///
  /// The table truncates isolate names to a fixed column width
  /// (`test_suite:fi…`), so rows alone cannot identify an isolate.
  /// Instead the stream is scanned chronologically: any line carrying
  /// a FULL isolate name (the `hard_threshold=…` spawn announcements)
  /// switches the current isolate; subsequent truncated rows belong to
  /// it. With `--concurrency=1` isolates run sequentially, so a row
  /// never precedes its isolate's spawn line.
  static List<GcEvent> parse(Iterable<String> lines) {
    final tracker = _IsolateTracker();
    final events = <GcEvent>[];
    for (final line in lines) {
      if (tracker.announce(line)) continue;
      if (isRow(line)) {
        events.add(tracker.assign(_parseRow(line, tracker.current)));
      }
    }
    return events;
  }

  /// The full isolate name carried by an announcement line
  /// (`<name>: hard_threshold=…MB`), or `null` for other lines.
  static String? fullIsolateName(String line) {
    if (!line.contains('test_suite:file://')) return null;
    if (!line.contains(': hard_threshold=')) return null;
    final start = line.indexOf('test_suite:file://');
    final end = line.indexOf(': hard_threshold=');
    return line.substring(start, end);
  }

  /// Splits [line] on commas; GC rows have 21 comma-separated fields.
  static List<String> _fields(String line) => line.split(',');

  /// The numeric fields of [line] (used by [isRow]'s shape check).
  static List<double> _numbers(String line) => [
        for (final field in _fields(line)) double.tryParse(field.trim()) ?? -1,
      ];

  static GcEvent _parseRow(String line, String currentIsolate) {
    final f = _fields(line);
    double num(int i) => double.tryParse(f[i].trim()) ?? 0;
    // [0] isolate, [1] space (reason), [2] GC#, [3] start (s),
    // [4] time (ms), [5]/[6] new used before/after, …, [11]/[12] old
    // used before/after, …, [19] delta new, [20] delta old.
    return GcEvent(
      isolate:
          currentIsolate.isNotEmpty ? currentIsolate : f[0].substring(1).trim(),
      seq: int.tryParse(f[2].trim()) ?? 0,
      startSeconds: num(3),
      newBeforeMb: num(5),
      newAfterMb: num(6),
      oldBeforeMb: num(11),
      oldAfterMb: num(12),
    );
  }
}
