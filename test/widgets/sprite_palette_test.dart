import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/widgets/sprite_palette.dart';

void main() {
  group('pickBurstColors', () {
    final palette = [
      for (var i = 0; i < 10; i++) Color(0xFF000000 | i),
    ];

    test('returns the whole palette when it fits within the shard count', () {
      expect(pickBurstColors(palette, 10), palette);
      expect(pickBurstColors(palette, 30), palette);
    });

    test('returns a subset sized to the shard count when there are more '
        'colours than shards', () {
      final picked = pickBurstColors(palette, 4, math.Random(1));
      expect(picked.length, 4);
      // Every picked colour comes from the source palette, with no repeats.
      expect(picked.toSet().length, 4);
      for (final c in picked) {
        expect(palette, contains(c));
      }
    });

    test('is deterministic for a given seed', () {
      expect(
        pickBurstColors(palette, 4, math.Random(7)),
        pickBurstColors(palette, 4, math.Random(7)),
      );
    });

    test('handles a non-positive count by returning the palette unchanged', () {
      expect(pickBurstColors(palette, 0), palette);
    });
  });
}
