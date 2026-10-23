// A fake `flutter` tool for the flutter-memory e2e test: prints the
// spawn trace line and the json suite event, then exits — exactly the
// lines `flutter test --verbose -j1 -r json` emits that the profiler
// rides on. All paths derive from this script's own location.
// Driven by test/memory/flutter_memory_e2e_test.dart.
import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final fixtureDir = p.dirname(p.fromUri(Platform.script));
  final tester = p.join(fixtureDir, 'fake_flutter_tester.dart');
  final dill = p.join(Directory.systemTemp.path, 'fake_e2e_listener.dill');
  File(dill).writeAsStringSync('// fake dill');
  stdout.writeln(
    '[   +1 ms] test 0: Starting flutter_tester process with '
    'command=[dart, $tester, --disable-vm-service, --non-interactive, '
    '--use-test-fonts, $dill], '
    'environment={SERVER_PORT: 53199, APP_NAME: fake_app}',
  );
  stdout.writeln(
    '{"suite":{"id":0,"path":"$fixtureDir/fake_e2e_test.dart"},'
    '"type":"suite"}',
  );
}
