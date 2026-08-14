import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../files/flutter_project.dart';
import 'collector_template.dart';
import 'source_instrumenter.dart';

/// Per-method timing data collected from an instrumented test run.
class MethodTiming {
  /// Creates a [MethodTiming].
  const MethodTiming({
    required this.className,
    required this.methodName,
    required this.calls,
    required this.totalMicros,
    required this.minMicros,
    required this.maxMicros,
  });

  /// Owning class name (or `(top-level)`).
  final String className;

  /// Method name.
  final String methodName;

  /// Number of times the method was called.
  final int calls;

  /// Total execution time in microseconds across all calls.
  final int totalMicros;

  /// Minimum single-call time in microseconds.
  final int minMicros;

  /// Maximum single-call time in microseconds.
  final int maxMicros;

  /// Mean execution time in microseconds.
  double get meanMicros => calls > 0 ? totalMicros / calls : 0.0;

  /// Total execution time in milliseconds.
  double get totalMillis => totalMicros / 1000.0;

  /// Mean execution time in microseconds (formatted).
  double get meanMillis => meanMicros / 1000.0;
}

/// Merged timing result from an instrumented test run.
class ProfileResult {
  /// Creates a [ProfileResult].
  const ProfileResult({required this.timings});

  /// Per-method timing data, sorted by total time descending.
  final List<MethodTiming> timings;
}

/// Signature of a process run — matches [Process.run] so tests can inject
/// a fake.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

/// Test selection options forwarded to `dart test` / `flutter test`.
class TestFilter {
  /// Creates a [TestFilter].
  const TestFilter({
    this.name,
    this.tags,
    this.excludeTags,
    this.paths = const [],
  });

  /// Run only tests whose name matches this substring or regex.
  final String? name;

  /// Run only tests with these tags.
  final List<String>? tags;

  /// Exclude tests with these tags.
  final List<String>? excludeTags;

  /// Explicit test file/directory paths.
  final List<String> paths;
}

/// Runs the project's test suite against instrumented source code and
/// collects per-method timing data.
///
/// Creates a temporary copy of the project with every method body wrapped
/// in a `Stopwatch`-based `try/finally` block. Tests are run normally; the
/// collector accumulates timing data and writes it to a JSON file.
class ProfileRunner {
  /// Creates a [ProfileRunner].
  ///
  /// [runner] defaults to [Process.run]; tests inject a fake.
  const ProfileRunner({ProcessRunner? runner})
      : _runner = runner ?? Process.run;

  final ProcessRunner _runner;

  /// Runs the tests of the project at [projectRoot] under instrumentation
  /// and returns the timing result, or `null` on failure.
  ///
  /// [filter] controls which tests are run (by name, tags, or paths).
  Future<ProfileResult?> run(
    String projectRoot, {
    TestFilter filter = const TestFilter(),
  }) async {
    Directory? tempDir;
    final keepTemp = Platform.environment['CRAP_PROFILE_DEBUG'] != null;
    try {
      final packageName = _readPackageName(projectRoot);
      if (packageName == null) {
        stderr.writeln('Warning: could not read package name from pubspec.');
        return null;
      }

      tempDir = await _createInstrumentedCopy(projectRoot, packageName);
      _ensureGitignore(projectRoot);
      if (!await _prepareWorkspaceTemp(projectRoot, tempDir)) return null;
      final outputFile = File(p.join(tempDir.path, '.crap_profile.json'));

      stderr.writeln('Running instrumented tests...');
      final testArgs = _buildTestArgs(projectRoot, filter);
      final result = await _runTests(
        projectRoot,
        tempDir,
        testArgs,
        outputFile,
      );

      _reportTestErrors(result);
      return _readResult(outputFile);
    } on Exception catch (e) {
      stderr.writeln('Warning: profiling failed: $e');
      return null;
    } finally {
      if (tempDir != null && !keepTemp) {
        try {
          tempDir.deleteSync(recursive: true);
        } on Exception {
          // Best effort cleanup.
        }
      }
    }
  }

  /// Runs `pub get` in [tempDir] for workspace members; a no-op for
  /// regular projects. Returns whether the project is ready.
  Future<bool> _prepareWorkspaceTemp(
    String projectRoot,
    Directory tempDir,
  ) async {
    if (!_isWorkspaceMember(projectRoot)) return true;
    return _runPubGet(projectRoot, tempDir);
  }

  /// Runs the (instrumented) test suite of [tempDir], writing timings
  /// to [outputFile].
  Future<ProcessResult> _runTests(
    String projectRoot,
    Directory tempDir,
    List<String> testArgs,
    File outputFile,
  ) {
    return _runner(
      isFlutterProject(projectRoot) ? 'flutter' : 'dart',
      testArgs,
      workingDirectory: tempDir.path,
      environment: {
        ...Platform.environment,
        'CRAP_PROFILE_OUTPUT': outputFile.path,
      },
    );
  }

  /// Builds the `dart test` / `flutter test` argument list from [filter].
  List<String> _buildTestArgs(String projectRoot, TestFilter filter) {
    final isFlutter = isFlutterProject(projectRoot);
    // --compiler source bypasses kernel caching that would use
    // the original (non-instrumented) source.
    final args =
        isFlutter ? <String>['test'] : <String>['test', '--compiler', 'source'];

    if (filter.name != null) {
      args.addAll(['--name', filter.name!]);
    }
    if (filter.tags != null && filter.tags!.isNotEmpty) {
      args.addAll(['--tags', filter.tags!.join(',')]);
    }
    if (filter.excludeTags != null && filter.excludeTags!.isNotEmpty) {
      args.addAll(['-x', filter.excludeTags!.join(',')]);
    }
    // Explicit test paths go at the end.
    args.addAll(filter.paths);
    return args;
  }

  /// Reports test errors to stderr.
  void _reportTestErrors(ProcessResult result) {
    if (result.exitCode != 0) {
      stderr.writeln('Warning: tests exited with code ${result.exitCode}.');
      final err = '${result.stderr}'.trim();
      if (err.isNotEmpty) {
        stderr.writeln(err.split('\n').take(30).join('\n'));
      }
      final out = '${result.stdout}'.trim();
      if (out.isNotEmpty) {
        stderr.writeln(out.split('\n').take(30).join('\n'));
      }
    }
  }

  /// Reads and parses the profiling output file.
  ProfileResult? _readResult(File outputFile) {
    if (!outputFile.existsSync()) {
      stderr.writeln('Warning: no profiling data was produced.');
      return null;
    }
    final json =
        jsonDecode(outputFile.readAsStringSync()) as Map<String, dynamic>;
    final timings = <MethodTiming>[];
    for (final entry in json.entries) {
      final key = entry.key;
      final stats = entry.value as Map<String, dynamic>;
      final dotIndex = key.indexOf('.');
      timings.add(MethodTiming(
        className: dotIndex > 0 ? key.substring(0, dotIndex) : '(top-level)',
        methodName: dotIndex > 0 ? key.substring(dotIndex + 1) : key,
        calls: stats['calls'] as int? ?? 0,
        totalMicros: stats['totalMicros'] as int? ?? 0,
        minMicros: stats['minMicros'] as int? ?? 0,
        maxMicros: stats['maxMicros'] as int? ?? 0,
      ));
    }
    timings.sort((a, b) => b.totalMicros.compareTo(a.totalMicros));
    return ProfileResult(timings: timings);
  }

  /// Creates a temporary copy of the project with instrumented `lib/`.
  Future<Directory> _createInstrumentedCopy(
    String projectRoot,
    String packageName,
  ) async {
    // Create temp dir as a sibling of the project so workspace path
    // dependencies resolve correctly.
    final tempDir = Directory(
      p.join(projectRoot, '.crap_profile_temp'),
    );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    tempDir.createSync(recursive: true);
    final workspaceMember = _isWorkspaceMember(projectRoot);
    _symlinkTopLevelEntries(projectRoot, tempDir, skipPubspec: workspaceMember);
    if (workspaceMember) {
      // A workspace member's pubspec (`resolution: workspace`) cannot be
      // resolved from the temp dir — no workspace root lists it. Write a
      // standalone pubspec instead; `pub get` runs in `run` afterwards.
      _writeStandalonePubspec(projectRoot, tempDir);
    }
    _copyTestDir(projectRoot, tempDir);
    if (!workspaceMember) {
      // Workspace members keep package resolution in the workspace root's
      // .dart_tool, not their own — `pub get` in the temp dir rebuilds it.
      _copyDartToolFrom(projectRoot, tempDir, packageName);
    }
    _instrumentLibDir(projectRoot, tempDir, packageName);
    return tempDir;
  }

  /// Symlinks every top-level entry of the project into [tempDir],
  /// except the directories that need real copies or instrumentation
  /// (`lib/`, `build/`, `.dart_tool/`, `test/`).
  ///
  /// When [skipPubspec] is set (workspace member), `pubspec.yaml` is written
  /// as a standalone rewrite instead of a symlink.
  void _symlinkTopLevelEntries(
    String projectRoot,
    Directory tempDir, {
    bool skipPubspec = false,
  }) {
    for (final entity in Directory(projectRoot).listSync()) {
      final name = p.basename(entity.path);
      if (_isManagedCopy(name)) continue;
      if (skipPubspec && name == 'pubspec.yaml') continue;
      final target = p.join(tempDir.path, name);
      try {
        Link(target).createSync(entity.path, recursive: false);
      } on FileSystemException {
        _copyPath(entity.path, target);
      }
    }
  }

  /// Whether the top-level entry [name] is copied or instrumented instead
  /// of being symlinked into the temporary project.
  bool _isManagedCopy(String name) =>
      name == 'lib' ||
      name == 'build' ||
      name == '.dart_tool' ||
      name == 'test';

  /// Copies `test/` into [tempDir] — it must contain real files, not
  /// symlinks, because `dart test` resolves `package:` imports relative
  /// to the test file's real path, not to the working directory.
  void _copyTestDir(String projectRoot, Directory tempDir) {
    final testDir = Directory(p.join(projectRoot, 'test'));
    if (testDir.existsSync()) {
      _copyPath(testDir.path, p.join(tempDir.path, 'test'));
    }
  }

  /// Copies `.dart_tool/` into [tempDir] and rewrites
  /// `package_config.json` so [packageName] resolves to the temp copy.
  void _copyDartToolFrom(
    String projectRoot,
    Directory tempDir,
    String packageName,
  ) {
    final dartToolSrc = Directory(p.join(projectRoot, '.dart_tool'));
    final dartToolDest = Directory(p.join(tempDir.path, '.dart_tool'));
    if (dartToolSrc.existsSync()) {
      _copyDartTool(dartToolSrc, dartToolDest, tempDir.path, packageName);
    }
  }

  /// Creates the instrumented `lib/` copy in [tempDir] and writes the
  /// collector library alongside it.
  void _instrumentLibDir(
    String projectRoot,
    Directory tempDir,
    String packageName,
  ) {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    final tempLib = Directory(p.join(tempDir.path, 'lib'));
    tempLib.createSync(recursive: true);
    if (libDir.existsSync()) {
      final instrumenter = SourceInstrumenter(packageName: packageName);
      _instrumentDir(libDir, tempLib, instrumenter, projectRoot);
    }

    // Write collector library.
    final collectorFile = File(
      p.join(tempDir.path, 'lib', '__crap_collector.dart'),
    );
    collectorFile.writeAsStringSync(collectorSource);

    // .dart_tool is symlinked, so package resolution (including path
    // dependencies) is inherited from the original project — no pub get
    // needed.
  }

  /// Recursively instruments all `.dart` files from [src] into [dest].
  void _instrumentDir(
    Directory src,
    Directory dest,
    SourceInstrumenter instrumenter,
    String projectRoot,
  ) {
    for (final entity in src.listSync()) {
      final relative = p.relative(entity.path, from: projectRoot);
      final destPath =
          p.join(dest.path, p.relative(entity.path, from: src.path));
      if (entity is Directory) {
        Directory(destPath).createSync(recursive: true);
        _instrumentDir(entity, Directory(destPath), instrumenter, projectRoot);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        final source = entity.readAsStringSync();
        final instrumented =
            instrumenter.instrument(source, filePath: relative);
        File(destPath).writeAsStringSync(instrumented);
      }
    }
  }

  /// Recursively copies a path (file or directory).
  void _copyPath(String src, String dest) {
    final entity = FileSystemEntity.typeSync(src);
    if (entity == FileSystemEntityType.directory) {
      Directory(dest).createSync(recursive: true);
      for (final e in Directory(src).listSync()) {
        _copyPath(e.path, p.join(dest, p.basename(e.path)));
      }
    } else if (entity == FileSystemEntityType.file) {
      File(src).copySync(dest);
    }
  }

  /// Copies `.dart_tool/` and rewrites `package_config.json` so that
  /// `package:<packageName>/` resolves to the instrumented temp `lib/`.
  void _copyDartTool(
    Directory src,
    Directory dest,
    String tempRoot,
    String packageName,
  ) {
    _copyPath(src.path, dest.path);
    final configFile = File(p.join(dest.path, 'package_config.json'));
    if (!configFile.existsSync()) return;
    // Parse JSON, rewrite the package entry, write back.
    final json = jsonDecode(configFile.readAsStringSync());
    final packages = json['packages'] as List<dynamic>?;
    if (packages == null) return;
    final tempRootUri = Uri.directory(tempRoot).toString();
    for (final pkg in packages) {
      if (pkg is Map<String, dynamic> && pkg['name'] == packageName) {
        pkg['rootUri'] = tempRootUri;
      }
    }
    configFile.writeAsStringSync(jsonEncode(json));
  }

  /// Ensures `.gitignore` contains entries for profiling artifacts.
  void _ensureGitignore(String root) {
    const entries = ['profile-reports/', '.crap_profile_temp/'];
    final file = File(p.join(root, '.gitignore'));
    var content = '';
    if (file.existsSync()) {
      content = file.readAsStringSync();
    }
    final missing = entries.where((e) => !content.contains(e)).toList();
    if (missing.isEmpty) return;
    final addition = StringBuffer();
    if (!content.endsWith('\n') && content.isNotEmpty) {
      addition.writeln();
    }
    addition.writeln('# crap4dart profiling');
    for (final e in missing) {
      addition.writeln(e);
    }
    file.writeAsStringSync('$content$addition', mode: FileMode.append);
  }

  /// Reads the package name from `pubspec.yaml`.
  String? _readPackageName(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    final match = RegExp(
      r'^name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    return match?.group(1)?.trim();
  }

  /// Whether the pubspec at [root] declares `resolution: workspace` — i.e.
  /// the package is a workspace member whose resolution lives in a parent
  /// workspace pubspec that does not list the profiling temp dir.
  bool _isWorkspaceMember(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    return RegExp(
      r'^resolution:\s*workspace\s*$',
      multiLine: true,
    ).hasMatch(pubspec.readAsStringSync());
  }

  /// Writes a standalone `pubspec.yaml` for the temp copy of a workspace
  /// member: strips the `resolution: workspace` marker (the temp dir belongs
  /// to no workspace) and absolutizes relative `path:` dependencies (from
  /// one level deeper they would resolve to the wrong directory).
  void _writeStandalonePubspec(String projectRoot, Directory tempDir) {
    final src = File(p.join(projectRoot, 'pubspec.yaml'));
    final absRoot = p.absolute(projectRoot);
    final rewritten = StringBuffer();
    for (final line in src.readAsLinesSync()) {
      if (RegExp(r'^resolution:\s*workspace\s*$').hasMatch(line)) continue;
      final dep = RegExp(r'^(\s*path:\s*)(\.\.?[/\\].*)$').firstMatch(line);
      if (dep != null) {
        final abs = p.normalize(p.join(absRoot, dep.group(2)!));
        rewritten.writeln('${dep.group(1)}$abs');
        continue;
      }
      rewritten.writeln(line);
    }
    File(p.join(tempDir.path, 'pubspec.yaml'))
        .writeAsStringSync(rewritten.toString());
  }

  /// Resolves dependencies in the temp copy of a workspace member. The
  /// copied `.dart_tool` bookkeeping belongs to the original package, so the
  /// temp dir needs its own resolution before the tests can run.
  Future<bool> _runPubGet(String projectRoot, Directory tempDir) async {
    final result = await _runner(
      isFlutterProject(projectRoot) ? 'flutter' : 'dart',
      ['pub', 'get'],
      workingDirectory: tempDir.path,
    );
    if (result.exitCode != 0) {
      stderr.writeln('Warning: pub get failed in profile temp dir.');
      final err = '${result.stderr}'.trim();
      if (err.isNotEmpty) {
        stderr.writeln(err.split('\n').take(10).join('\n'));
      }
      return false;
    }
    return true;
  }
}
