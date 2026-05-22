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

  group('lightnessWeights', () {
    const black = Color(0xFF000000);
    const grey = Color(0xFF808080);
    const white = Color(0xFFFFFFFF);

    test('bias 0 weights every colour equally', () {
      expect(lightnessWeights([black, grey, white], 0), [1.0, 1.0, 1.0]);
    });

    test('weights climb with lightness once biased', () {
      final w = lightnessWeights([black, grey, white], 1);
      expect(w[0], lessThan(w[1])); // black under grey
      expect(w[1], lessThan(w[2])); // grey under white
      expect(w.last, 1.0); // brightest colour anchors at 1
    });

    test('a stronger bias widens the gap between dark and light', () {
      final mild = lightnessWeights([grey, white], 0.4);
      final strong = lightnessWeights([grey, white], 1.0);
      // Both anchor white at 1, so the darker colour's weight shrinks as bias
      // grows — a steeper skew toward the lighter colour.
      expect(strong.first, lessThan(mild.first));
    });

    test('falls back to equal weights when there is no lightness to separate', () {
      expect(lightnessWeights([black, black], 1), [1.0, 1.0]);
    });

    test('returns an entry per colour', () {
      expect(lightnessWeights([black, grey, white], 0.5).length, 3);
      expect(lightnessWeights(const [], 1), isEmpty);
    });
  });

  group('lockBurstPalette', () {
    const red = Color(0xFFB02D28);
    const gold = Color(0xFFD4A437);
    const white = Color(0xFFFFFFFF);

    test('no white mix leaves the lock colours and weights untouched', () {
      final p = lockBurstPalette([red, gold], 0, 0);
      expect(p.colors, [red, gold]);
      expect(p.weights, lightnessWeights([red, gold], 0));
    });

    test('white mix appends white carrying its share of the total weight', () {
      final p = lockBurstPalette([red, gold], 0, 0.25);
      expect(p.colors.last, white);
      expect(p.colors.length, 3);
      final total = p.weights.reduce((a, b) => a + b);
      // White's weight is 25% of the whole, the lock colours split the rest.
      expect(p.weights.last / total, closeTo(0.25, 1e-9));
    });

    test('white share is independent of the lightness bias', () {
      double whiteShare(double bias) {
        final p = lockBurstPalette([red, gold], bias, 0.3);
        return p.weights.last / p.weights.reduce((a, b) => a + b);
      }

      expect(whiteShare(0), closeTo(0.3, 1e-9));
      expect(whiteShare(1), closeTo(0.3, 1e-9));
    });

    test('full white mix drives every lock weight to zero', () {
      final p = lockBurstPalette([red, gold], 0.5, 1);
      expect(p.colors.last, white);
      expect(p.weights.sublist(0, 2), everyElement(0.0));
      expect(p.weights.last, 1.0);
    });
  });
}
