import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Reads the distinct colours out of a lock sprite sheet so the landing burst
/// can be tinted from the lock's own palette instead of fixed swatches.
///
/// Decoding a sheet and scanning every pixel is cheap (the sheets are tiny
/// pixel-art PNGs) but not free, so results are cached by asset path — a lock is
/// only ever decoded once.
class SpritePalette {
  SpritePalette._();

  static final Map<String, List<Color>> _cache = {};

  /// Pixels at or above this alpha count toward the palette; fainter pixels
  /// (the transparent background, the odd anti-aliased edge) are ignored. The
  /// locks are crisp pixel art, so in practice this just drops the background.
  static const int _alphaFloor = 128;

  /// Distinct opaque colours found in [assetPath]'s image, in raster order.
  /// Returns an empty list if the asset can't be decoded or has no qualifying
  /// pixels; callers fall back to their own palette in that case. Cached.
  static Future<List<Color>> of(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) return cached;

    List<Color> colors;
    try {
      final image = await _decode(assetPath);
      colors = await _extract(image);
    } catch (_) {
      colors = const [];
    }
    _cache[assetPath] = colors;
    return colors;
  }

  static Future<List<Color>> _extract(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    final bytes = data.buffer.asUint8List();
    final seen = <int>{};
    final colors = <Color>[];
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i + 3] < _alphaFloor) continue;
      // Key on RGB alone so shades dedupe on colour, not on edge alpha; the
      // stored colour is forced opaque because the burst applies its own fade.
      final rgb = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      if (seen.add(rgb)) colors.add(Color(0xFF000000 | rgb));
    }
    return colors;
  }

  static Future<ui.Image> _decode(String assetPath) {
    final completer = Completer<ui.Image>();
    final stream = AssetImage(assetPath).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// Picks the shard colours for a lock-palette burst: when the lock has more
/// colours than there are shards, a random subset of [count]; otherwise the
/// whole palette (shards then repeat colours, which is the small-palette case).
/// Returns [palette] unchanged when it already fits, so callers can pass the
/// result straight to the burst.
List<Color> pickBurstColors(List<Color> palette, int count, [math.Random? rng]) {
  if (palette.length <= count || count <= 0) return palette;
  final pool = List<Color>.of(palette)..shuffle(rng ?? math.Random());
  return pool.sublist(0, count);
}
