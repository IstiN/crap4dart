/// Body whose only differences between clones are local names.
String renamedMethod(
  String name,
  String value,
  String i,
  String item,
  String prefix,
  String suffix,
  String result,
) =>
    '''
void $name(List<String> $value, String $prefix, String $suffix,
    List<String> $result) {
  for (var $i = 0; $i < $value.length; $i++) {
    final $item = $value[$i];
    if ($item.isEmpty) {
      continue;
    }
    if ($item.startsWith($prefix)) {
      $result.add($item.substring($prefix.length));
    } else if ($item.endsWith($suffix)) {
      $result.add($item.substring(0, $item.length - $suffix.length));
    } else {
      $result.add($item.toLowerCase());
    }
  }
}
''';

/// Body using two params in one order.
String swappable(String name, String a, String b, String total) => '''
int $name(int $a, int $b) {
  var $total = 0;
  for (var i = 0; i < $a; i++) {
    $total += $b;
    if ($total > $a) {
      $total -= 1;
    }
  }
  while ($total < $b) {
    $total += $a;
  }
  return $total;
}
''';

/// Same body with the two params crossed — a semantic swap.
String swapped(String name, String x, String y, String total) => '''
int $name(int $x, int $y) {
  var $total = 0;
  for (var i = 0; i < $y; i++) {
    $total += $x;
    if ($total > $y) {
      $total -= 1;
    }
  }
  while ($total < $x) {
    $total += $y;
  }
  return $total;
}
''';

/// Body whose calls differ on [method] in every branch, so no
/// `min_tokens` window can avoid the difference.
String callee(String name, String value, String result, String method) => '''
void $name(List<String> $value, List<String> $result) {
  for (var i = 0; i < $value.length; i++) {
    final item = $value[i];
    if (item.isEmpty) {
      $result.$method(item);
    } else if (item.startsWith('x')) {
      $result.$method(item);
    } else if (item.endsWith('y')) {
      $result.$method(item.toLowerCase());
    } else {
      $result.$method(item.trim());
    }
  }
}
''';

/// Class whose method reads a private field; clones differ in the field
/// name, which is API surface, not a local.
String repo(String className, String field, String key, String value) => '''
class $className {
  final Map<String, int> $field = {};
  int load(String $key) {
    if ($field.containsKey($key)) {
      return $field[$key] ?? 0;
    }
    final $value = parse($key);
    $field[$key] = $value;
    return $value;
  }
}
int parse(String s) => s.length;
''';

/// Body whose only differences between clones are literals.
String literal(String name, int limit, String label) => '''
void $name(List<String> value, List<String> result) {
  for (var i = 0; i < value.length; i++) {
    if (value.length > $limit) {
      throw StateError('$label');
    }
    final item = value[i];
    if (item.startsWith('$label')) {
      result.add(item);
    } else if (item.endsWith('$label')) {
      result.add(item.toLowerCase());
    } else {
      result.add(item.trim());
    }
  }
}
''';

/// Body exercising every masked declaration kind: record patterns,
/// for-in variables, local functions, catch parameters, and string
/// interpolation of a local.
String kinds(
  String name,
  String input,
  String head,
  String tail,
  String count,
  String piece,
  String helper,
  String err,
) =>
    '''
int $name(dynamic $input) {
  try {
    final ($head, $tail) = ($input.toString(), $input.hashCode);
    var $count = 0;
    for (final $piece in [$head.length, $tail.toRadixString(2).length]) {
      $count += $piece;
    }
    int $helper(String s) => s.length + $count;
    return $helper('\$$count');
  } on StateError catch ($err) {
    return $err.hashCode;
  }
}
''';

/// The renamed-clone pair used by [duplicationNormalization] tests.
String renamedOriginal() => renamedMethod(
    'process', 'value', 'i', 'item', 'prefix', 'suffix', 'result');

/// The renamed-clone counterpart of [renamedOriginal].
String renamedClone() =>
    renamedMethod('handle', 'data', 'idx', 'entry', 'start', 'end', 'out');

/// The all-declaration-kinds original body.
String kindsOriginal() =>
    kinds('run', 'input', 'head', 'tail', 'count', 'piece', 'helper', 'err');

/// The all-declaration-kinds renamed counterpart.
String kindsClone() =>
    kinds('go', 'source', 'first', 'rest', 'total', 'part', 'assist', 'e');
