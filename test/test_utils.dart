import 'package:crap4dart/src/analysis/complexity.dart';
import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/analysis/method_extractor.dart';

/// Parses [source] and returns the extracted methods with their AST nodes.
List<ExtractedMethod> parseMethods(String source) {
  final parsed = DartParser().parse(content: source, path: 'test.dart');
  return const MethodExtractor()
      .extractWithNodes(parsed.unit, parsed.lineInfo, filePath: 'test.dart');
}

/// Returns the cyclomatic complexity of the single method in [source].
int complexityOf(String source) {
  final methods = parseMethods(source);
  assert(methods.length == 1, 'expected exactly one method in fixture');
  return const ComplexityCalculator().compute(methods.single.node);
}
