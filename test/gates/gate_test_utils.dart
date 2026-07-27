import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:crap4dart/src/gates/gate_context.dart';
import 'package:path/path.dart' as p;

/// Creates a temporary project directory for gate tests.
Directory createTempProject() =>
    Directory.systemTemp.createTempSync('crap4dart_gate_test_');

/// Writes [content] to [relative] under [root], creating directories.
void writeFile(Directory root, String relative, String content) {
  final file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Adds a pubspec marking [root] as a Flutter project.
void makeFlutterProject(Directory root) => writeFile(
      root,
      'pubspec.yaml',
      'name: fixture\n'
          'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n',
    );

/// Builds a [GateContext] over [relativeFiles] of [root].
GateContext makeContext(
  Directory root,
  List<String> relativeFiles, {
  String? configYaml,
  List<FileCoverage>? lcov,
}) {
  final config = configYaml == null
      ? Crap4DartConfig.defaults()
      : const ConfigLoader().loadString(configYaml);
  return GateContext(
    projectRoot: root.path,
    config: config,
    files: [for (final f in relativeFiles) p.join(root.path, f)],
    lcov: lcov,
  );
}
