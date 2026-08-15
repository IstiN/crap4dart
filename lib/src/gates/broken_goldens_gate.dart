import 'dart:io';

import 'package:image/image.dart' as img;

import 'gate.dart';
import 'gate_context.dart';

/// The stripe classification of a pixel in the overflow pattern.
enum _StripeKind { none, yellow, black }

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
    if (_hasOverflowStripes(image, minStripeRun)) {
      return 'overflow stripes (yellow/black) rendered in the golden — '
          'the widget overflows and the snapshot recorded it';
    }
    if (_hasErrorScreen(image)) {
      return 'build-error screen (dark red) rendered in the golden — '
          'the widget tree threw during the snapshot';
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
  bool _hasOverflowStripes(img.Image image, int minStripeRun) {
    for (var y = 0; y < image.height; y++) {
      if (_alternatingRun(
          image.width, minStripeRun, (i) => image.getPixel(i, y))) {
        return true;
      }
    }
    for (var x = 0; x < image.width; x++) {
      if (_alternatingRun(
          image.height, minStripeRun, (i) => image.getPixel(x, i))) {
        return true;
      }
    }
    return false;
  }

  /// Whether the pixel line of [length] sampled by [pixelAt] contains
  /// a stripe run: a mix of yellow and black pixels, long enough, with
  /// real alternation (>= 4 color transitions) and a yellow share of
  /// at least a third — dark UIs with sparse yellow text never qualify.
  bool _alternatingRun(
    int length,
    int minRun,
    img.Pixel Function(int i) pixelAt,
  ) {
    var run = 0;
    var transitions = 0;
    var last = _StripeKind.none;
    var yellows = 0;
    for (var i = 0; i < length; i++) {
      final kind = _stripeKind(pixelAt(i));
      if (kind == _StripeKind.none) {
        if (_qualifies(run, transitions, yellows, minRun)) return true;
        run = 0;
        transitions = 0;
        yellows = 0;
        last = _StripeKind.none;
        continue;
      }
      if (kind != last) {
        transitions++;
        last = kind;
      }
      run++;
      if (kind == _StripeKind.yellow) yellows++;
      if (_qualifies(run, transitions, yellows, minRun)) return true;
    }
    return false;
  }

  /// Whether an accumulated run counts as a stripe: long enough, has
  /// alternated at least 4 times (>= 2 full color cycles) and yellow
  /// makes up at least a third of it (sparse text on black never does).
  bool _qualifies(int run, int transitions, int yellows, int minRun) =>
      run >= minRun && transitions >= 4 && yellows * 3 >= run;

  /// The stripe classification of [pixel]: yellow, black or neither.
  _StripeKind _stripeKind(img.Pixel pixel) {
    if (_isYellow(pixel)) return _StripeKind.yellow;
    if (_isBlack(pixel)) return _StripeKind.black;
    return _StripeKind.none;
  }

  /// Whether the pixel is the yellow of an overflow stripe, matched
  /// with tolerance: high R+G, low B.
  bool _isYellow(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    return r > 200 && g > 180 && b < 90;
  }

  /// Whether the pixel is stripe black (not just any dark UI pixel —
  /// the threshold is deliberately strict).
  bool _isBlack(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    return r < 60 && g < 60 && b < 60;
  }

  /// Whether ≥ [errorThreshold] of the image is the dark-red
  /// ErrorWidget background (R high-ish, G/B very low).
  bool _hasErrorScreen(img.Image image) {
    const errorThreshold = 0.15;
    var red = 0;
    var total = 0;
    for (final pixel in image) {
      total++;
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      // RenderErrorBox background: dark red (#900000 at 94% opacity).
      if (r > 100 && r < 200 && g < 40 && b < 40) red++;
    }
    return total > 0 && red / total >= errorThreshold;
  }
}
