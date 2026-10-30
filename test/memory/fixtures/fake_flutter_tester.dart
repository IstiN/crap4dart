// A fake `flutter_tester` for the flutter-memory e2e test: speaks
// package:test's remote protocol on SERVER_PORT and a fake VM Service
// (JSON-RPC + GC stream) on a WebSocket of its own, the way the real
// engine does. Driven by test/memory/flutter_memory_e2e_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _fakeAllocatedBytes = 47185920; // 45 MB

Future<void> main(List<String> args) async {
  // The engine announces its VM Service on stdout before the isolate
  // registers (lowercase 'service' — one of the engine's spellings).
  final service = await HttpServer.bind('127.0.0.1', 0);
  stdout.writeln(
    'The Dart VM service is listening on '
    'http://127.0.0.1:${service.port}/auth=/',
  );
  final serviceSockets = <WebSocket>[];
  final gcPushed = Completer<void>();
  unawaited(
    service.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      serviceSockets.add(ws);
      ws.listen((data) => _onServiceRpc(ws, data, gcPushed));
    }).asFuture<void>(),
  );

  // The suite side of the remote protocol.
  final port = Platform.environment['SERVER_PORT']!;
  final suite = await WebSocket.connect('ws://127.0.0.1:$port');
  suite.listen((data) => _onSuiteMessage(suite, serviceSockets, gcPushed,
      jsonDecode(data as String) as List<Object?>));
}

/// Answers one fake VM Service JSON-RPC call.
Future<void> _onServiceRpc(
  WebSocket ws,
  Object data,
  Completer<void> gcPushed,
) async {
  final msg = jsonDecode(data as String) as Map<String, Object?>;
  final id = msg['id'] as int?;
  final method = msg['method'] as String?;
  final params = msg['params'] as Map<String, Object?>? ?? const {};
  void reply([Object? result]) => ws.add(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': result ?? <String, Object?>{},
      }));
  switch (method) {
    case 'streamListen':
      reply();
    case 'getVM':
      reply({
        'isolates': [
          {'id': 'isolates/1', 'name': 'main'}
        ]
      });
    case 'getAllocationProfile':
      reply({
        'members': [
          {'accumulatedSize': params['reset'] == true ? 0 : _fakeAllocatedBytes}
        ]
      });
      if (!gcPushed.isCompleted) gcPushed.complete();
    case 'streamCancel':
      reply();
  }
}

/// Handles one suite-protocol envelope from the runner under test.
Future<void> _onSuiteMessage(
  WebSocket suite,
  List<WebSocket> serviceSockets,
  Completer<void> gcPushed,
  List<Object?> msg,
) async {
  final body = msg[1] as Map<String, Object?>;
  if (msg[0] == 0 && body['type'] == 'initial') {
    suite.add(jsonEncode([
      0,
      {
        'type': 'success',
        'root': {
          'type': 'group',
          'name': '',
          'entries': [
            {'type': 'test', 'name': 'fake churns', 'channel': 1}
          ]
        }
      }
    ]));
  } else if (body['command'] == 'run') {
    await _runFakeTest(suite, serviceSockets, gcPushed, body);
  } else if (msg[0] == 0 && body['type'] == 'close') {
    await suite.close();
    exit(0);
  }
}

/// Pushes one GC event through the fake service, then completes the
/// test on the live channel (the suite's virtualChannel(live) sends
/// its events as [live + 1]).
Future<void> _runFakeTest(
  WebSocket suite,
  List<WebSocket> serviceSockets,
  Completer<void> gcPushed,
  Map<String, Object?> body,
) async {
  await gcPushed.future;
  for (final ws in serviceSockets) {
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'method': 'streamNotify',
      'params': {
        'streamId': 'GC',
        'event': {
          'kind': 'GC',
          'gcType': 'Scavenge',
          'timestamp': 1792708993094,
          'reason': 'new space',
          'isolate': {'name': 'main'},
          'new': {'used': 460128, 'collections': 1},
          'old': {'used': 56705840, 'collections': 8},
        }
      }
    }));
  }
  final live = (body['channel'] as num).toInt();
  suite.add(jsonEncode([
    live + 1,
    {'type': 'state-change', 'status': 'complete', 'result': 'success'}
  ]));
  suite.add(jsonEncode([
    live + 1,
    {'type': 'complete'}
  ]));
}
