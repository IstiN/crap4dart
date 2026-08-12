import '../analysis/method_extractor.dart';
import '../report/table_formatter.dart';
import 'profile_runner.dart';

/// Per-method profile data combining [MethodInfo] with timing data.
class MethodProfile {
  /// Creates a [MethodProfile].
  const MethodProfile({
    required this.method,
    required this.timing,
  });

  /// The analyzed method.
  final MethodInfo method;

  /// Timing data from the instrumented run.
  final MethodTiming timing;
}

/// Renders CPU profiling results as a console table.
class ProfileReport {
  /// Creates a [ProfileReport].
  const ProfileReport({required this.profiles});

  /// Attributed per-method profiles.
  final List<MethodProfile> profiles;

  /// Column headers of the report table.
  static const List<String> headers = [
    'TOTAL(ms)',
    '%',
    'CALLS',
    'MEAN(µs)',
    'MAX(µs)',
    '@60fps(ms)',
    'METHOD',
    'FILE:LINE',
  ];

  /// Profiles sorted by total time descending.
  List<MethodProfile> get sorted {
    final copy = List<MethodProfile>.of(profiles);
    copy.sort((a, b) => b.timing.totalMicros.compareTo(a.timing.totalMicros));
    return copy;
  }

  /// Total time across all profiled methods.
  int get totalMicros {
    var sum = 0;
    for (final p in profiles) {
      sum += p.timing.totalMicros;
    }
    return sum;
  }

  /// Renders the report table, optionally limited to [top] entries and
  /// flagged against [thresholdMs].
  String render({
    int? top,
    double? thresholdMs,
    String? header,
  }) {
    final allSorted = sorted;
    final shown =
        top != null && top > 0 ? allSorted.take(top).toList() : allSorted;
    final rows = shown.map(_rowFor).toList();

    final buffer = StringBuffer();
    if (header != null) buffer.writeln(header);
    buffer.writeln(
      'Profile Report (${profiles.length} methods, '
      'total ${_fmt(totalMicros / 1000.0)}ms)',
    );
    buffer.writeln(
      TableFormatter(numericColumnCount: 6).renderTable(headers, rows),
    );
    buffer.writeln();

    if (thresholdMs != null) {
      final exceeding = profiles.where(
        (p) => p.timing.totalMillis > thresholdMs,
      );
      final count = exceeding.length;
      if (count > 0) {
        buffer.writeln(
          'Threshold: ${_fmt(thresholdMs)}ms — '
          '$count method${count == 1 ? ' exceeds' : 's exceed'}',
        );
      } else {
        buffer.writeln('Threshold: ${_fmt(thresholdMs)}ms — all methods OK');
      }
    }

    return buffer.toString().trimRight();
  }

  List<String> _rowFor(MethodProfile p) {
    final pct =
        totalMicros > 0 ? p.timing.totalMicros / totalMicros * 100.0 : 0.0;
    // Estimate cost at 60fps: if a widget rebuilds every frame, calls ~60/sec.
    // This shows the "hidden" cost of frequently-rebuilt widgets.
    final fps60ms = p.timing.meanMicros * 60.0 / 1000.0;
    return [
      _fmt(p.timing.totalMillis),
      '${pct.toStringAsFixed(1)}%',
      '${p.timing.calls}',
      p.timing.meanMicros.toStringAsFixed(1),
      '${p.timing.maxMicros}',
      _fmt(fps60ms),
      '${p.method.className}.${p.method.methodName}',
      '${p.method.filePath}:${p.method.startLine}',
    ];
  }

  static String _fmt(double value) => value.toStringAsFixed(2);
}

/// Attributes raw [MethodTiming] data to [MethodInfo] by class.method name.
class ProfileAttributor {
  /// Creates a [ProfileAttributor].
  const ProfileAttributor();

  /// Attributes [timings] to [methods] and returns per-method profiles.
  List<MethodProfile> attribute(
    List<MethodTiming> timings,
    List<MethodInfo> methods,
  ) {
    // Index methods by "ClassName.methodName" key.
    final byKey = <String, List<MethodInfo>>{};
    for (final m in methods) {
      final key = '${m.className}.${m.methodName}';
      byKey.putIfAbsent(key, () => []).add(m);
    }

    final result = <MethodProfile>[];
    for (final t in timings) {
      final key = '${t.className}.${t.methodName}';
      final candidates = byKey[key];
      if (candidates == null || candidates.isEmpty) continue;

      // Take the first matching method.
      result.add(MethodProfile(method: candidates.first, timing: t));
    }

    return result;
  }
}
