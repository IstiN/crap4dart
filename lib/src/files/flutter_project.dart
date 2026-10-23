import '../common/constants.dart';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The pubspec dependency that marks a project as Flutter-backed.
const String _flutterDepName = 'flutter';

/// Whether the project at [root] is a Flutter project (its pubspec
/// declares a `flutter` dependency).
bool isFlutterProject(String root) {
  final pubspec = File(p.join(root, kPubspec));
  if (!pubspec.existsSync()) return false;
  final doc = loadYaml(pubspec.readAsStringSync());
  if (doc is! YamlMap) return false;
  for (final section in const ['dependencies', 'dev_dependencies']) {
    final deps = doc[section];
    if (deps is YamlMap && deps.containsKey(_flutterDepName)) {
      return true;
    }
  }
  return false;
}
