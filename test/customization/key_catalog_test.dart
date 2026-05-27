import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';

void main() {
  group('renderColorIdFor', () {
    test('returns saved color when style supports it', () {
      final style = keyStyleById('key_4');
      expect(renderColorIdFor(style, 'gold'), 'gold');
      expect(renderColorIdFor(style, 'bronze'), 'bronze');
    });

    test('falls back to grey when style does not support saved color', () {
      // key_4 has gold/silver/bronze/grey; curse is not supported.
      final style = keyStyleById('key_4');
      expect(renderColorIdFor(style, 'curse'), 'grey');
    });

    test('falls back to first color when style has neither saved nor grey', () {
      // Synthetic style for the defensive branch.
      const style = KeyStyle(
        id: 'synthetic',
        displayName: 'X',
        animated: false,
        frameCount: 1,
        frameWidth: 1,
        frameHeight: 1,
        colors: [
          KeyColorOption(id: 'rust', displayName: 'Rust', swatchColor: 0),
        ],
      );
      expect(renderColorIdFor(style, 'gold'), 'rust');
    });
  });

  group('colorCenterIndex', () {
    test('returns the index of the saved color when supported', () {
      final style = keyStyleById('key_4');
      // _standardColors order: grey, bronze, silver, gold.
      expect(colorCenterIndex(style, 'grey'), 0);
      expect(colorCenterIndex(style, 'bronze'), 1);
      expect(colorCenterIndex(style, 'gold'), 3);
    });

    test('returns the grey index when saved color is unsupported', () {
      final style = keyStyleById('key_4');
      // grey is at index 0 in _standardColors.
      expect(colorCenterIndex(style, 'curse'), 0);
    });

    test('returns 0 when neither saved color nor grey are present', () {
      const style = KeyStyle(
        id: 'synthetic',
        displayName: 'X',
        animated: false,
        frameCount: 1,
        frameWidth: 1,
        frameHeight: 1,
        colors: [
          KeyColorOption(id: 'rust', displayName: 'Rust', swatchColor: 0),
        ],
      );
      expect(colorCenterIndex(style, 'gold'), 0);
    });
  });

  group('keyColorForRender', () {
    test('returns the resolved KeyColorOption (grey for unsupported)', () {
      final style = keyStyleById('key_4');
      final resolved = keyColorForRender(style, 'curse');
      expect(resolved.id, 'grey');
    });

    test('returns the saved KeyColorOption when supported', () {
      final style = keyStyleById('key_8');
      final resolved = keyColorForRender(style, 'curse');
      expect(resolved.id, 'curse');
    });
  });
}
