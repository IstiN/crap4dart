import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Whether the project at [root] is a Flutter project (its pubspec
/// declares a `flutter` dependency).
bool isFlutterProject(String root) {
  final pubspec = File(p.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  final doc = loadYaml(pubspec.readAsStringSync());
  if (doc is! YamlMap) return false;
  for (final section in const ['dependencies', 'dev_dependencies']) {
    final deps = doc[section];
    if (deps is YamlMap && deps.containsKey('flutter')) return true;
  }
  return false;
}
