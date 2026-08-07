import 'dart:io';

import 'gate_test_utils.dart';

/// A non-trivial method body used for duplication tests.
String duplicatedBody() => '''
  if (value == null) {
    throw ArgumentError.notNull('value');
  }
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item == null || item.isEmpty) {
      continue;
    }
    if (item.startsWith(prefix)) {
      result.add(item.substring(prefix.length));
    } else if (item.endsWith(suffix)) {
      result.add(item.substring(0, item.length - suffix.length));
    } else {
      result.add(item.toLowerCase());
    }
  }
  return result;
''';

/// Writes a single method with the duplicated body to [path].
void writeSingleMethod(Directory project, String path, String name) {
  writeFile(
    project,
    path,
    'void $name(List<String> value, String prefix, String suffix, '
    'List<String> result) {\n${duplicatedBody()}}\n',
  );
}

/// Writes two identical methods with the duplicated body to the same file.
void writeDuplicatedFile(
  Directory project,
  String path,
  String nameA,
  String nameB,
) {
  final body = duplicatedBody();
  writeFile(
    project,
    path,
    'void $nameA(List<String> value, String prefix, String suffix, '
    'List<String> result) {\n$body}\n'
    '\n'
    'void $nameB(List<String> value, String prefix, String suffix, '
    'List<String> result) {\n$body}\n',
  );
}
