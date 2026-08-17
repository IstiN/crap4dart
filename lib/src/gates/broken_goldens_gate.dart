import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'gate.dart';
import 'tofu_detector.dart';
import 'gate_context.dart';

/// The stripe classification of a pixel in the overflow pattern.

/// Stripe pixel classification codes used by [BrokenGoldensGate] and
/// its [_PixelStats]: 0 none, 1 yellow, 2 black.
const int _noneCode = 0;
const int _yellowCode = 1;
const int _redCode = 3;
const int _blackCode = 2;

/// The `broken_goldens` gate: scans golden PNG files for rendered
/// Flutter error artifacts — yellow/black overflow stripes and the red
/// build-error screen (dark red background with yellow text).
///
/// Golden tests do not fail on these: the broken frame gets captured
/// (often permanently, via `--update-goldens`), so the pixels are the
/// only witness.
class BrokenGoldensGate implements Gate {
  /// Creates a [BrokenGoldensGate].
  const BrokenGoldensGate();

  @override
  String get id => 'broken_goldens';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.brokenGoldens;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final dir in config.dirs) {
      final directory = Directory('${context.projectRoot}/$dir');
      if (!directory.existsSync()) continue;
      for (final png in _goldenFiles(directory, config.exclude, context)) {
        checked++;
        final violation = _violation(png, config.minStripeRun, context);
        if (violation != null) violations.add(violation);
      }
    }
    final summary = violations.isEmpty
        ? '$checked golden images clean'
        : '${violations.length}/$checked golden images contain error '
            'artifacts';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Non-excluded PNG files under [directory].
  Iterable<File> _goldenFiles(
    Directory directory,
    List<String> exclude,
    GateContext context,
  ) =>
      [
        for (final entity in directory.listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.png') &&
              !context.matchesAnyGlob(entity.path, exclude))
            entity,
      ];

  /// The violation for [png], or `null` when the image is clean.
  GateViolation? _violation(
    File png,
    int minStripeRun,
    GateContext context,
  ) {
    final message = _analyze(png, minStripeRun);
    if (message == null) return null;
    return GateViolation(
      file: context.relativePath(png.path),
      message: message,
    );
  }

  /// Returns a violation message for [file], or `null` when clean.
  String? _analyze(File file, int minStripeRun) {
    final image = img.decodeImage(file.readAsBytesSync());
    if (image == null) return null;
    // One pixel classification pass feeds both detectors.
    final stats = _PixelStats.of(image);
    if (stats.hasYellow && _hasOverflowStripes(stats, image, minStripeRun)) {
      return 'overflow stripes (yellow/black) rendered in the golden — '
          'the widget overflows and the snapshot recorded it';
    }
    if (stats.redFraction >= 0.15) {
      return 'build-error screen (dark red) rendered in the golden — '
          'the widget tree threw during the snapshot';
    }
    if (const TofuDetector().hasTofuIcons(image)) {
      return 'broken icon placeholder(s) (box with an X) rendered in '
          'the golden — an icon failed to load';
    }
    return null;
  }

  /// Whether the image contains a run of alternating yellow/black
  /// pixels at least [minStripeRun] long (horizontal or vertical).
  ///
  /// Flutter's overflow stripes are a diagonal checkerboard: any row or
  /// column crossing them shows STRICT yellow/black alternation. Plain
  /// "yellow and black pixels in a line" is not enough — dark UIs with
  /// yellow text produce long mixed runs and would false-positive.
  bool _hasOverflowStripes(
    _PixelStats stats,
    img.Image image,
    int minStripeRun,
  ) {
    final kinds = stats.kinds;
    final width = image.width;
    final height = image.height;
    for (var y = 0; y < height; y++) {
      if (_alternatingRun(width, minStripeRun, (i) => kinds[y * width + i])) {
        return true;
      }
    }
    for (var x = 0; x < width; x++) {
      if (_alternatingRun(height, minStripeRun, (i) => kinds[i * width + x])) {
        return true;
      }
    }
    return false;
  }

  /// Whether the pixel line of [length] sampled by [kindAt] contains
  /// a stripe run: a mix of yellow and black pixels, long enough, with
  /// real alternation (>= 4 color transitions) and a yellow share of
  /// at least a third — dark UIs with sparse yellow text never qualify.
  bool _alternatingRun(
    int length,
    int minRun,
    int Function(int i) kindAt,
  ) {
    var run = 0;
    var transitions = 0;
    var last = _noneCode;
    var yellows = 0;
    for (var i = 0; i < length; i++) {
      final kind = kindAt(i);
      if (kind == _noneCode) {
        if (_qualifies(run, transitions, yellows, minRun)) return true;
        run = 0;
        transitions = 0;
        yellows = 0;
        last = _noneCode;
        continue;
      }
      if (kind != last) {
        transitions++;
        last = kind;
      }
      run++;
      if (kind == _yellowCode) yellows++;
      if (_qualifies(run, transitions, yellows, minRun)) return true;
    }
    return false;
  }

  /// Whether an accumulated run counts as a stripe: long enough, has
  /// alternated at least 4 times (>= 2 full color cycles) and yellow
  /// makes up at least a third of it (sparse text on black never does).
  bool _qualifies(int run, int transitions, int yellows, int minRun) =>
      run >= minRun && transitions >= 4 && yellows * 3 >= run;
}

/// Single-pass pixel statistics feeding both golden detectors.
class _PixelStats {
  _PixelStats(this.kinds, this.hasYellow, this.redFraction);

  /// Stripe classification code per pixel (see
  /// [BrokenGoldensGate._stripeKindOf]).
  final Uint8List kinds;

  /// Whether any pixel is stripe yellow (stripes are impossible
  /// without it — skips the row/column scan for most images).
  final bool hasYellow;

  /// Share of pixels matching the dark-red error background.
  final double redFraction;

  /// Classifies every pixel of [image] once.
  static _PixelStats of(img.Image image) {
    final kinds = Uint8List(image.width * image.height);
    var hasYellow = false;
    var red = 0;
    var i = 0;
    for (final pixel in image) {
      final kind = _classify(pixel);
      if (kind == _yellowCode) hasYellow = true;
      if (kind == _redCode) red++;
      kinds[i++] = kind;
    }
    final total = kinds.length;
    return _PixelStats(
      kinds,
      hasYellow,
      total > 0 ? red / total : 0.0,
    );
  }

  /// The classification of one pixel: none, stripe yellow, stripe
  /// black or error-screen red.
  static int _classify(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    final kind = _stripeKind(r, g, b);
    if (kind != _noneCode) return kind;
    // RenderErrorBox background: dark red (#900000 at 94% opacity).
    return _isErrorRed(r, g, b) ? _redCode : _noneCode;
  }

  /// The stripe classification: yellow, black or none.
  static int _stripeKind(int r, int g, int b) {
    if (r > 200 && g > 180 && b < 90) return _yellowCode;
    if (r < 60 && g < 60 && b < 60) return _blackCode;
    return _noneCode;
  }

  /// Whether RGB matches the error-screen background.
  static bool _isErrorRed(int r, int g, int b) =>
      r > 100 && r < 200 && g < 40 && b < 40;
}
