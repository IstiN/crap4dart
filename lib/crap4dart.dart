/// CRAP metric analyzer for Dart and Flutter projects.
///
/// Combines cyclomatic complexity with test coverage to compute
/// Change Risk Anti-Patterns (CRAP) scores per method.
library;

export 'src/analysis/complexity.dart';
export 'src/analysis/dart_parser.dart';
export 'src/analysis/method_extractor.dart';
export 'src/config/config.dart';
export 'src/config/config_loader.dart';
export 'src/coverage/lcov_parser.dart';
export 'src/coverage/method_coverage.dart';
export 'src/crap/crap_analyzer.dart';
export 'src/crap/crap_score.dart';
export 'src/files/diff_parser.dart';
export 'src/report/json_reporter.dart';
