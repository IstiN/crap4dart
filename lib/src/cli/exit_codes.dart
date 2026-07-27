/// Exit codes used by the crap4dart CLI.
abstract final class ExitCodes {
  /// Successful analysis (including empty selections and reports where all
  /// scores are at or below the threshold).
  static const int success = 0;

  /// Command-line usage error.
  static const int usageError = 1;

  /// The maximum CRAP score exceeded the configured threshold.
  static const int thresholdExceeded = 2;
}
