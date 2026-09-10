import 'package:crap4dart/src/analysis/complexity.dart';
import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/analysis/method_extractor.dart';

/// Parses [source] and returns the extracted methods with their AST nodes.
///
/// [countConstructors] is forwarded to the [MethodExtractor].
List<ExtractedMethod> parseMethods(
  String source, {
  bool countConstructors = false,
}) {
  final parsed = DartParser().parse(content: source, path: 'test.dart');
  return MethodExtractor(countConstructors: countConstructors)
      .extractWithNodes(parsed.unit, parsed.lineInfo, filePath: 'test.dart');
}

/// Returns the cyclomatic complexity of the single method in [source].
///
/// [countConstructors] is forwarded to the [MethodExtractor].
int complexityOf(String source, {bool countConstructors = false}) {
  final methods = parseMethods(source, countConstructors: countConstructors);
  assert(methods.length == 1, 'expected exactly one method in fixture');
  return const ComplexityCalculator().compute(methods.single.node);
}
