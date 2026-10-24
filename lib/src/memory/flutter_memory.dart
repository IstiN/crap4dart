// Flutter-suite support for the `memory` command.
//
// `flutter test` (3.4x) offers no way to pass VM flags such as
// `--verbose_gc` through to the per-file `flutter_tester` processes it
// spawns (the engine's `--dart-flags` whitelist rejects it). The
// profiler rides on the `--verbose` trace instead: it prints the EXACT
// command line and environment of every spawn, and for each one we
// re-run the same command with the VM Service enabled
// (`--vm-service-port=0` replacing `--disable-vm-service`), point the
// suite's WebSocket listener at a local server of ours, and DRIVE the
// suite over package:test's remote protocol (`initial` -> `success` ->
// `run`/`close` per test).
//
// Metrics come from the VM Service of the measured copy:
//  * per-test ALLOCATED bytes — `getAllocationProfile` is reset before
//    each test and read after it (exact, more precise than the dart
//    engine's reclaimed-new-gen proxy);
//  * GC events — the `GC` stream, routed by arrival to the running
//    test (counts, durations, old-gen growth).
//
// Cost: every test file executes twice (the tool's own run plus ours).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'gc_log.dart';
import 'memory_profiler.dart';

/// The remote protocol's `result: success` marker.
const String _successResult = 'success';

/// The serialized `Metadata` the remote protocol expects in `initial`.
const Map<String, Object?> _initialMetadata = {
  'testOn': null,
  'timeout': {'duration': 600000000}, // 10 min, microseconds
  'skip': false,
  'skipReason': null,
  'verboseTrace': false,
  'chainStackTraces': false,
  'retry': 0,
  'tags': <String>[],
  'onPlatform': <Object>[],
  'forTag': <String, Object?>{},
  'languageVersionComment': null,
};

/// One traced `flutter_tester` spawn: its argv and environment.
class FlutterTesterSpawn {
  /// argv[0] — the flutter_tester binary.
  final String executable;

  /// argv[1..]: engine flags, package config, assets dir, dill.
  final List<String> arguments;

  /// Env map printed by the trace (merged over the parent env).
  final Map<String, String> environment;

  /// Creates a spawn description.
  const FlutterTesterSpawn({
    required this.executable,
    required this.arguments,
    required this.environment,
  });
}

/// Parses a `--verbose` trace line reporting a flutter_tester spawn.
///
/// Returns `null` for lines that are not spawn reports.
FlutterTesterSpawn? parseTesterSpawnLine(String line) {
  final m = RegExp(
    'Starting flutter_tester process with command=\\[(.+)\\], '
    'environment=\\{(.+)\\}\$',
  ).firstMatch(line);
  if (m == null) return null;
  final rawArgs = m.group(1)!.split(', ');
  if (rawArgs.any((a) => a.isEmpty)) return null;
  final env = <String, String>{};
  for (final kv in m.group(2)!.split(', ')) {
    final idx = kv.indexOf(': ');
    if (idx <= 0) continue;
    env[kv.substring(0, idx)] = kv.substring(idx + 2);
  }
  return FlutterTesterSpawn(
    executable: rawArgs.first,
    arguments: rawArgs.sublist(1),
    environment: env,
  );
}

/// Extracts the test-file path from the generated listener source next
/// to the compiled dill (`import 'file://…' as test;`), '' if unknown.
String testPathFromListener(String dillPath) {
  final listener = File.fromUri(
    File(dillPath).parent.uri.resolve('listener.dart'),
  );
  if (!listener.existsSync()) return '';
  final m = RegExp("import 'file://([^']+)' as test;")
      .firstMatch(listener.readAsStringSync());
  return m?.group(1) ?? '';
}

/// A test collected from the suite description.
class RemoteTest {
  /// The test's display name (flattened group prefix + test name).
  final String name;

  /// Suite-side channel id; the runner addresses it as `id + 1`.
  final int channel;

  RemoteTest(this.name, this.channel);
}

/// Flattens a serialized group tree into an ordered test list.
List<RemoteTest> flattenGroup(Map<String, Object?> node, String prefix) {
  final name = node['name'] as String? ?? '';
  final full =
      prefix.isEmpty ? name : (name.isEmpty ? prefix : '$prefix $name');
  final entries = node['entries'] as List<Object?>? ?? const [];
  final tests = <RemoteTest>[];
  for (final entry in entries) {
    final map = entry as Map<String, Object?>;
    if (map['type'] == 'group') {
      tests.addAll(flattenGroup(map, full));
    } else {
      final test = full.isEmpty
          ? (map['name'] as String? ?? '')
          : '$full ${map['name']}';
      tests.add(RemoteTest(test, (map['channel'] as num).toInt()));
    }
  }
  return tests;
}

/// Routes GC rows arriving on stderr to the current test, or to the
/// loading bucket while no test is running.
class _RowCollector {
  final loading = <GcEvent>[];

  /// Non-null while a test is being driven; rows land there.
  List<GcEvent>? current;

  /// Route one parsed row.
  void add(GcEvent? row) {
    if (row == null) return;
    (current ?? loading).add(row);
  }
}

/// File-level measurement outcome.
class MeasuredFile {
  /// Absolute test-file path (or the dill path when unknown).
  final String path;

  /// Per-test entries.
  final List<MemoryEntry> tests;

  /// GC rows that arrived outside any test window.
  final List<GcEvent> loadingRows;

  /// Bytes allocated while the suite loaded (before the first test),
  /// from the VM allocation profile.
  final int allocatedLoadingBytes;

  /// Why the file could not be measured, if it could not.
  final String? error;

  /// Creates the outcome.
  MeasuredFile({
    required this.path,
    required this.tests,
    required this.loadingRows,
    this.allocatedLoadingBytes = 0,
    this.error,
  });
}

/// Drives one flutter_tester process over the remote protocol and
/// attributes GC rows to the currently-running test.
class FlutterSuiteDriver {
  /// Sink for progress notes (never stdout).
  final void Function(String line) note;

  /// Creates a driver.
  FlutterSuiteDriver({required this.note});

  /// Runs [spawn] with the VM Service enabled, drives every test, and
  /// returns the measured file.
  Future<MeasuredFile> measure(FlutterTesterSpawn spawn) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dill = spawn.arguments.last;
    final testPath = testPathFromListener(dill);
    final env = {...Platform.environment, ...spawn.environment}
      ..['SERVER_PORT'] = '${server.port}';
    final args = [
      for (final arg in spawn.arguments)
        arg == '--disable-vm-service' ? '--vm-service-port=0' : arg,
    ];
    final process = await Process.start(
      spawn.executable,
      args,
      environment: env,
    );
    final collector = _RowCollector();
    final stderrTail = <String>[];
    final vmUri = Completer<Uri?>();
    // The engine prints its VM Service URI (stdout or stderr — it
    // varies); engine errors go to stderr. Both pipes must be drained
    // or the child blocks.
    void scanVmUri(String line) {
      // The engine writes "The Dart VM service is listening on …"
      // (lowercase 'service' on some engines).
      if (vmUri.isCompleted ||
          !line.toLowerCase().contains('dart vm service')) {
        return;
      }
      final match = RegExp(r'https?://[^\s]+').firstMatch(line)?.group(0);
      vmUri.complete(match == null ? null : Uri.tryParse(match));
    }

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(scanVmUri);
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrTail.add(line);
      if (stderrTail.length > 6) stderrTail.removeAt(0);
      scanVmUri(line);
    });
    final label = testPath.isEmpty ? dill : testPath;
    VmServiceClient? service;
    try {
      final socket = await server.first.timeout(const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('suite never connected'));
      final ws = await WebSocketTransformer.upgrade(socket);
      final channel = _JsonChannel(ws);
      service = await _connectService(vmUri, collector, note);
      return await _drive(channel, label, collector, service);
    } on Object catch (e) {
      note('  suite driver failure: $e; child stderr tail: $stderrTail');
      return MeasuredFile(
        path: label,
        tests: const [],
        loadingRows: collector.loading,
        error: 'driver failure: $e',
      );
    } finally {
      await service?.close();
      process.kill();
      await process.exitCode;
      await stdoutSub.cancel();
      await stderrSub.cancel();
      await server.close(force: true);
    }
  }

  /// Connects the measured copy's VM Service, or returns `null` (and
  /// notes it) when the engine never announced one.
  Future<VmServiceClient?> _connectService(
    Completer<Uri?> vmUri,
    _RowCollector collector,
    void Function(String line) note,
  ) async {
    final uri = await vmUri.future
        .timeout(const Duration(seconds: 30), onTimeout: () => null);
    if (uri == null) {
      note('  no VM Service URI announced; metrics will be empty');
      return null;
    }
    // The engine prints `…/<auth>/` with a trailing slash; the service
    // websocket lives at `…/<auth>/ws`.
    final basePath = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return VmServiceClient.connect(
      uri.replace(scheme: 'ws', path: '${basePath}ws'),
      collector.add,
    );
  }

  /// Speaks the protocol: initial -> success -> run every test.
  Future<MeasuredFile> _drive(
    _JsonChannel channel,
    String label,
    _RowCollector collector,
    VmServiceClient? service,
  ) async {
    await channel.send([
      0,
      {
        'type': 'initial',
        'platform': {
          'runtime': 'vm',
          'os': Platform.operatingSystem,
          'inGoogle': false,
        },
        'metadata': _initialMetadata,
        'asciiGlyphs': false,
        'path': label,
        'collectTraces': false,
        'noRetry': true,
        'platformVariables': <String>[],
        'allowDuplicateTestNames': true,
        'ignoreTimeouts': false,
        'foldTraceExcept': <String>[],
        'foldTraceOnly': <String>[],
      },
    ]);
    final tests = <RemoteTest>[];
    while (true) {
      final msg = await channel.receive().timeout(const Duration(minutes: 5));
      if (msg[0] != 0) continue;
      final body = msg[1] as Map<String, Object?>;
      final type = body['type'] as String?;
      if (type == 'error') {
        await channel.close();
        return MeasuredFile(
          path: label,
          tests: const [],
          loadingRows: collector.loading,
          error: 'suite failed to load: ${body['error']}',
        );
      }
      if (type == 'success') {
        tests.addAll(flattenGroup(body['root'] as Map<String, Object?>, ''));
        break;
      }
    }
    // The accumulators have been running since isolate start: reading
    // them now (before any reset) captures the LOAD allocations.
    var loadingBytes = 0;
    if (service != null) {
      loadingBytes =
          await service.allocatedBytes().catchError((_) => null) ?? 0;
    }
    final entries = <MemoryEntry>[];
    for (final test in tests) {
      entries.add(await _runOne(channel, test, collector, service));
    }
    await channel.send([
      0,
      {'type': 'close'}
    ]);
    await channel.close();
    return MeasuredFile(
      path: label,
      tests: entries,
      loadingRows: collector.loading,
      allocatedLoadingBytes: loadingBytes,
    );
  }

  /// Runs [test]; GC rows arriving meanwhile land on its entry.
  Future<MemoryEntry> _runOne(
    _JsonChannel channel,
    RemoteTest test,
    _RowCollector collector,
    VmServiceClient? service,
  ) async {
    final live = _nextLiveId;
    _nextLiveId += 2;
    final gcs = <GcEvent>[];
    await service?.resetAllocationProfile().catchError((_) {});
    await channel.send([
      test.channel + 1,
      {'command': 'run', 'channel': live},
    ]);
    collector.current = gcs;
    var result = _successResult;
    var completed = false;
    // The suite's live channel for id `live` RECEIVES on [live, …] and
    // SENDS its events as [live + 1, …] (MultiChannel id scheme).
    while (!completed) {
      final msg = await channel.receive().timeout(const Duration(minutes: 10),
          onTimeout: () {
        completed = true;
        result = 'timeout';
        return <Object?>[-1, const {}];
      });
      if (msg[0] != live + 1) continue;
      final outcome = _applyTestEvent(msg[1] as Map<String, Object?>);
      if (outcome == null) continue;
      completed = true;
      if (outcome != _successResult) result = outcome;
    }
    collector.current = null;
    await channel.send([
      live,
      {'command': 'close'}
    ]);
    if (result != _successResult) note('  test failed: ${test.name} ($result)');
    final entry = MemoryEntry(test.name);
    entry.gcs.addAll(gcs);
    if (service != null) {
      entry.allocatedBytes =
          await service.allocatedBytes().catchError((_) => null);
    }
    return entry;
  }

  /// Applies one live-channel event: `null` while the test runs, the
  /// final result string once it completes.
  static String? _applyTestEvent(Map<String, Object?> body) {
    switch (body['type'] as String?) {
      case 'state-change':
        return body['status'] == 'complete'
            ? (body['result'] as String? ?? _successResult)
            : null;
      case 'error':
        return 'error';
      case 'complete':
        return _successResult;
      default:
        return null;
    }
  }

  int _nextLiveId = 3;
}

/// A minimal VM Service JSON-RPC client for the measured copy:
/// request/response by id, plus the `GC` event stream routed into the
/// collector by arrival (the running test owns whatever arrives).
class VmServiceClient {
  final WebSocket _socket;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final void Function(GcEvent?) _gcSink;
  int _nextId = 1;

  VmServiceClient._(this._socket, this._gcSink) {
    _socket.listen((data) {
      final decoded = jsonDecode(data as String) as Map<String, Object?>;
      final id = decoded['id'];
      if (id is int && _pending.containsKey(id)) {
        _pending.remove(id)!.complete(decoded);
        return;
      }
      if (decoded['method'] == 'streamNotify') {
        final params = decoded['params'] as Map<String, Object?>;
        if (params['streamId'] == 'GC') {
          _gcSink(_gcEventOf(params['event'] as Map<String, Object?>));
        }
      }
    });
  }

  /// Connects, subscribes to the GC stream and resolves the isolate.
  static Future<VmServiceClient> connect(
    Uri wsUri,
    void Function(GcEvent?) gcSink,
  ) async {
    final socket = await WebSocket.connect(wsUri.toString()).timeout(
      const Duration(seconds: 30),
    );
    final client = VmServiceClient._(socket, gcSink);
    await client.rpc('streamListen', {'streamId': 'GC'});
    await client._resolveIsolate();
    return client;
  }

  /// The root isolate registers with the service some time AFTER the
  /// engine prints its URI (the listener connects, then loads) — poll
  /// until it lists.
  Future<void> _resolveIsolate() async {
    for (var attempt = 0; attempt < 150; attempt++) {
      final vm = await rpc('getVM', const {});
      final isolates =
          (vm['result'] as Map<String, Object?>)['isolates'] as List<Object?>?;
      final id = (isolates?.first as Map<String, Object?>?)?['id']?.toString();
      if (id != null) {
        _isolateIdRaw = id;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  // The service uses opaque string ids like `isolates/123`.
  String? _isolateIdRaw;

  /// One JSON-RPC call.
  Future<Map<String, Object?>> rpc(
    String method,
    Map<String, Object?> params,
  ) async {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }));
    return completer.future.timeout(const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('vm rpc $method'));
  }

  /// Old-gen used after the previous service event (per connection,
  /// i.e. per measured isolate); chains `oldBefore` across events.
  double? _lastOldAfterMb;

  /// Maps a service GC event onto a [GcEvent] (old-gen before chains
  /// from the previous event; new-gen reclaimed is not reported by the
  /// service, so allocation volume comes from the profile instead).
  GcEvent? _gcEventOf(Map<String, Object?> event) {
    final newSpace = event['new'] as Map<String, Object?>?;
    final oldSpace = event['old'] as Map<String, Object?>?;
    if (newSpace == null || oldSpace == null) return null;
    final seq = ((newSpace['collections'] as num?)?.toInt() ?? 0) +
        ((oldSpace['collections'] as num?)?.toInt() ?? 0);
    double mb(Object? value) => (value as num?)?.toDouble() ?? 0;
    final oldAfter = mb(oldSpace['used']) / 1048576;
    final chained = GcEvent(
      isolate:
          (event['isolate'] as Map<String, Object?>?)?['name'] as String? ??
              'main',
      seq: seq,
      startSeconds: ((event['timestamp'] as num?)?.toDouble() ?? 0) / 1000,
      newBeforeMb: 0, // not reported by the service stream
      newAfterMb: mb(newSpace['used']) / 1048576,
      oldBeforeMb: _lastOldAfterMb ?? oldAfter,
      oldAfterMb: oldAfter,
    );
    _lastOldAfterMb = oldAfter;
    return chained;
  }

  /// Bytes allocated since the last reset (whole isolate).
  Future<int?> allocatedBytes() async {
    final isolate = await _isolate();
    if (isolate == null) return null;
    final resp = await rpc('getAllocationProfile', {
      'isolateId': isolate,
    });
    final result = resp['result'] as Map<String, Object?>?;
    final members = result?['members'] as List<Object?>? ?? const [];
    var total = 0;
    for (final member in members) {
      total += ((member as Map<String, Object?>)['accumulatedSize'] as num?)
              ?.toInt() ??
          0;
    }
    return total;
  }

  /// Zeroes the allocation accumulators.
  Future<void> resetAllocationProfile() async {
    final isolate = await _isolate();
    if (isolate == null) return;
    await rpc('getAllocationProfile', {
      'isolateId': isolate,
      'reset': true,
    });
  }

  /// The isolate id, re-resolving if the first attempt raced the
  /// isolate registration.
  Future<String?> _isolate() async {
    if (_isolateIdRaw != null) return _isolateIdRaw;
    await _resolveIsolate();
    return _isolateIdRaw;
  }

  /// Closes the service socket.
  Future<void> close() async {
    try {
      await rpc('streamCancel', {'streamId': 'GC'});
    } on Object {
      // best effort
    }
    await _socket.close();
  }
}

/// The `[id, message]` WebSocket envelope of the remote protocol, with
/// a lossless inbox (a broadcast stream would drop messages in the
/// async gap between two `receive()` calls — a lost `complete` would
/// hang the driver).
class _JsonChannel {
  final WebSocket _socket;
  final _inbox = <List<Object?>>[];
  final _waiters = <Completer<List<Object?>>>[];

  _JsonChannel(this._socket) {
    _socket.listen((data) {
      final decoded = jsonDecode(data as String) as List<Object?>;
      if (_waiters.isEmpty) {
        _inbox.add(decoded);
      } else {
        _waiters.removeAt(0).complete(decoded);
      }
    });
  }

  Future<void> send(List<Object?> envelope) async =>
      _socket.add(jsonEncode(envelope));

  Future<List<Object?>> receive() {
    if (_inbox.isNotEmpty) return Future.value(_inbox.removeAt(0));
    final completer = Completer<List<Object?>>();
    _waiters.add(completer);
    return completer.future;
  }

  Future<void> close() => _socket.close();
}

/// Runs `flutter test --verbose --no-pub -j1 -r json` in [projectRoot]
/// and measures every traced flutter_tester spawn alongside it,
/// returning the aggregated [MemoryReport].
///
/// Every file executes twice (the tool's own run plus the measurement
/// copy); paths inside the trace must not contain commas (a limitation
/// of the tool's plain `List.toString()` trace).
Future<MemoryReport> runFlutterMemory(
  String projectRoot,
  void Function(String line) note, {
  String? flutterBinary,

  /// Overrides the tool argv (tests inject a fake `flutter` tool).
  List<String> toolArgs = const [
    'test',
    '--verbose',
    '--no-pub',
    '-j1',
    '-r',
    'json'
  ],
}) async {
  final flutter = flutterBinary ?? _defaultFlutterBinary();
  final tool = await Process.start(
    flutter,
    toolArgs,
    workingDirectory: projectRoot,
  );
  // Never await the driver inline while reading stdout: the tool's
  // pipe would fill up and deadlock. Feed spawns to a queue consumed
  // sequentially beside the reading loop.
  final spawns = StreamController<FlutterTesterSpawn>();
  final suitePaths = <String>[];
  final measuring = () async {
    final files = <MeasuredFile>[];
    await for (final spawn in spawns.stream) {
      note('measuring spawn #${files.length}');
      files.add(await FlutterSuiteDriver(note: note).measure(spawn));
    }
    return files;
  }();
  tool.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(note);
  final snapshots = await _feedSpawns(tool, spawns, suitePaths, note);
  await spawns.close();
  final files = await measuring;
  // The tool runs files serially: spawn k produced suite event k. Pair
  // them for display paths (the driver itself only sees temp dills).
  for (var i = 0; i < files.length && i < suitePaths.length; i++) {
    files[i] = MeasuredFile(
      path: suitePaths[i],
      tests: files[i].tests,
      loadingRows: files[i].loadingRows,
      error: files[i].error,
    );
  }
  final code = await tool.exitCode;
  if (code != 0) note('flutter test exited with code $code');
  for (final snap in snapshots) {
    try {
      snap.deleteSync();
    } on Object {
      // best effort
    }
  }
  return _aggregate(projectRoot, files);
}

/// Reads the tool's stdout line by line, collecting suite paths and
/// forwarding every traced spawn to [spawns] — after snapshotting its
/// temp dill: the tool deletes each file's dill when the file finishes
/// and at -j1 it outruns the measured copy (every file runs twice).
Future<List<File>> _feedSpawns(
  Process tool,
  StreamController<FlutterTesterSpawn> spawns,
  List<String> suitePaths,
  void Function(String line) note,
) async {
  final snapshots = <File>[];
  var snapshot = 0;
  await for (final line
      in tool.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
    final suitePath = _suitePathOf(line);
    if (suitePath != null) suitePaths.add(suitePath);
    final spawn = parseTesterSpawnLine(line);
    if (spawn == null) continue;
    snapshots.add(_snapshotDill(spawn, snapshot++, note));
    spawns.add(spawn);
  }
  return snapshots;
}

/// Copies the spawn's dill aside and points the spawn at the copy; on
/// failure the spawn keeps the live (racing) path.
File _snapshotDill(
  FlutterTesterSpawn spawn,
  int index,
  void Function(String line) note,
) {
  final copy = File('${Directory.systemTemp.path}/'
      'crap4dart_dill_${pid}_$index.dill');
  try {
    File(spawn.arguments.last).copySync(copy.path);
    spawn.arguments[spawn.arguments.length - 1] = copy.path;
  } on Object catch (e) {
    note('  dill snapshot failed ($e); measuring the live path');
  }
  return copy;
}

/// `$FLUTTER_ROOT/bin/flutter` when set, else `flutter` on PATH.
String _defaultFlutterBinary() {
  final root = Platform.environment['FLUTTER_ROOT'];
  return root == null ? 'flutter' : '$root/bin/flutter';
}

/// The `path` of a package:test json `suite` event line, or `null`.
String? _suitePathOf(String line) {
  if (!line.startsWith('{"suite":')) return null;
  final decoded = jsonDecode(line) as Map<String, Object?>;
  final suite = decoded['suite'] as Map<String, Object?>?;
  final path = suite?['path'] as String?;
  return (path == null || path.isEmpty) ? null : path;
}

/// Builds the report: file entries carry ALL their rows (loading ones
/// included — one process per file makes them confidently file-local),
/// tests carry only their in-window rows.
MemoryReport _aggregate(String projectRoot, List<MeasuredFile> files) {
  final suites = <MemoryEntry>[];
  final tests = <MemoryEntry>[];
  for (final file in files) {
    final rel = p.relative(file.path, from: projectRoot);
    final suite = MemoryEntry(rel);
    suite.gcs.addAll(file.loadingRows);
    suite.allocatedBytes = file.allocatedLoadingBytes;
    for (final test in file.tests) {
      suite.gcs.addAll(test.gcs);
      suite.allocatedBytes =
          (suite.allocatedBytes ?? 0) + (test.allocatedBytes ?? 0);
      final entry = MemoryEntry(test.label, suitePath: rel);
      entry.gcs.addAll(test.gcs);
      entry.allocatedBytes = test.allocatedBytes;
      tests.add(entry);
    }
    suites.add(suite);
  }
  final all = [
    for (final suite in suites) ...suite.gcs,
  ];
  return MemoryReport(
    testCount: tests.length,
    totalGcs: all,
    suites: suites,
    tests: tests,
    churnAvailable: false,
    unattributedGcs: [
      for (final file in files)
        if (file.error != null) ...file.loadingRows,
    ],
  );
}
