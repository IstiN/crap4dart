/// Inline Dart fixtures for the implicit_state gate tests.
library;

/// Three lifecycle flags mutated across three methods.
const String clusterSource = '''
class Downloader {
  bool isRunning = false;
  bool hasFailed = false;
  bool isDisposed = false;

  void start() {
    isRunning = true;
    hasFailed = false;
  }

  void stop() {
    isRunning = false;
    isDisposed = true;
  }

  void fail() {
    hasFailed = true;
    isRunning = false;
  }
}
''';

/// Two lifecycle flags — below the default `min_flags: 3`.
const String twoFlagsSource = '''
class Small {
  bool isRunning = false;
  bool hasFailed = false;

  void start() {
    isRunning = true;
    hasFailed = false;
  }

  void stop() {
    isRunning = false;
    hasFailed = true;
  }
}
''';

/// One flag mutated from three methods.
const String oneFlagSource = '''
class Job {
  bool isDone = false;

  void run() {
    isDone = false;
  }

  void complete() {
    isDone = true;
  }

  void reset() {
    isDone = false;
  }
}
''';

/// A status field assigned from several methods.
const String statusSource = '''
enum JobState { idle, running, done }

class Job {
  String status = 'idle';

  void run() {
    status = 'running';
  }

  void finish() {
    status = 'done';
  }
}
''';

/// Static and final bool fields — not mutable lifecycle flags.
const String immutableSource = '''
class Config {
  static bool isGlobalEnabled = false;
  final bool isReady = true;
  final bool hasFailed = false;
}
''';

/// One mutation site — below the default `min_mutators: 2`.
const String onceSource = '''
class Once {
  bool isStarted = false;

  void start() {
    isStarted = true;
  }
}
''';

/// A getter and an if reading two lifecycle flags at once.
const String comboSource = '''
class Guard {
  bool isLoading = false;
  bool hasFailed = false;

  bool get stalled => isLoading && hasFailed;

  void check() {
    if (isLoading || hasFailed) {
      return;
    }
  }
}
''';

/// Member accesses (`other.isReady`) and single-flag conditions.
const String plainSource = '''
class Plain {
  bool isReady = false;

  void check(Plain other) {
    if (other.isReady) {
      return;
    }
    if (isReady) {
      return;
    }
  }
}
''';

/// Bool fields whose names carry no lifecycle signal.
const String mutedSource = '''
class Settings {
  bool verbose = false;
  bool colored = true;
  bool strict = false;

  void toggle() {
    verbose = !verbose;
    colored = !colored;
    strict = !strict;
  }

  void reset() {
    verbose = false;
    colored = true;
    strict = false;
  }
}
''';

/// A class with no fields at all.
const String cleanSource = 'class Clean {}\n';
