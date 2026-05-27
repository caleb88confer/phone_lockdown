import 'sprite_defaults.dart';

class KeyColorOption {
  final String id;
  final String displayName;
  final int swatchColor;

  const KeyColorOption({
    required this.id,
    required this.displayName,
    required this.swatchColor,
  });
}

class KeyStyle {
  final String id;
  final String displayName;
  final bool animated;
  final int frameCount;
  final int frameWidth;
  final int frameHeight;
  final List<KeyColorOption> colors;
  // Multiplier applied to render size to compensate for sprites whose frame
  // canvas is bigger than the standard 10x28 (e.g., key_8's 21x47 canvas
  // includes particle-effect padding around the visible key glyph).
  final double displayScale;
  // Per-frame duration in ms. Null falls back to kDefaultKeyFrameMs.
  final int? frameMs;
  // Vertical paint offset as a fraction of rendered height. Negative shifts
  // the sprite up, positive shifts it down. Layout footprint is unaffected.
  // Use to compensate for sprites whose visible glyph isn't centered in
  // their canvas (e.g. when particle padding is on one side).
  final double centerOffsetY;

  const KeyStyle({
    required this.id,
    required this.displayName,
    required this.animated,
    required this.frameCount,
    required this.frameWidth,
    required this.frameHeight,
    required this.colors,
    this.displayScale = 1.0,
    this.frameMs,
    this.centerOffsetY = 0.0,
  });

  String spritesheetPath(String colorId) =>
      'assets/sprites/keys/${id}_$colorId.png';

  Duration durationFor(int framesPlayed) =>
      Duration(milliseconds: (frameMs ?? kDefaultKeyFrameMs) * framesPlayed);
}

const _gold = KeyColorOption(
  id: 'gold',
  displayName: 'Gold',
  swatchColor: 0xFFD4A437,
);
const _silver = KeyColorOption(
  id: 'silver',
  displayName: 'Silver',
  swatchColor: 0xFFBFC1C2,
);
const _bronze = KeyColorOption(
  id: 'bronze',
  displayName: 'Bronze',
  swatchColor: 0xFFB07849,
);
const _grey = KeyColorOption(
  id: 'grey',
  displayName: 'Grey',
  swatchColor: 0xFF888888,
);
const _curse = KeyColorOption(
  id: 'curse',
  displayName: 'Curse',
  swatchColor: 0xFF6A1B9A,
);

const _standardColors = <KeyColorOption>[_gold, _silver, _bronze, _grey];
const _key8Colors = <KeyColorOption>[_gold, _silver, _grey, _curse];

const kKeyCatalog = <KeyStyle>[
  KeyStyle(
    id: 'key_4',
    displayName: 'Key 4',
    animated: true,
    frameCount: 5,
    frameWidth: 14,
    frameHeight: 27,
    colors: _standardColors,
    frameMs: 150,
  ),
  KeyStyle(
    id: 'key_1',
    displayName: 'Key 1',
    animated: false,
    frameCount: 1,
    frameWidth: 10,
    frameHeight: 28,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_2',
    displayName: 'Key 2',
    animated: true,
    frameCount: 12,
    frameWidth: 10,
    frameHeight: 28,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_3',
    displayName: 'Key 3',
    animated: false,
    frameCount: 1,
    frameWidth: 19,
    frameHeight: 32,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_5',
    displayName: 'Key 5',
    animated: true,
    frameCount: 18,
    frameWidth: 13,
    frameHeight: 29,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_6',
    displayName: 'Key 6',
    animated: true,
    frameCount: 12,
    frameWidth: 16,
    frameHeight: 35,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_7',
    displayName: 'Key 7',
    animated: true,
    frameCount: 28,
    frameWidth: 17,
    frameHeight: 29,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_8',
    displayName: 'Key 8',
    animated: true,
    frameCount: 27,
    frameWidth: 21,
    frameHeight: 47,
    colors: _key8Colors,
    displayScale: 1.7,
    centerOffsetY: -0.2,
  ),
  KeyStyle(
    id: 'key_9',
    displayName: 'Key 9',
    animated: false,
    frameCount: 1,
    frameWidth: 9,
    frameHeight: 30,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_10',
    displayName: 'Key 10',
    animated: false,
    frameCount: 1,
    frameWidth: 9,
    frameHeight: 27,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_11',
    displayName: 'Key 11',
    animated: true,
    frameCount: 12,
    frameWidth: 11,
    frameHeight: 27,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_12',
    displayName: 'Key 12',
    animated: true,
    frameCount: 21,
    frameWidth: 10,
    frameHeight: 32,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_13',
    displayName: 'Key 13',
    animated: true,
    frameCount: 25,
    frameWidth: 10,
    frameMs: 80,
    frameHeight: 27,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_14',
    displayName: 'Key 14',
    animated: false,
    frameCount: 1,
    frameWidth: 10,
    frameHeight: 27,
    colors: _standardColors,
  ),
  KeyStyle(
    id: 'key_15',
    displayName: 'Key 15',
    animated: true,
    frameCount: 48,
    frameWidth: 15,
    frameHeight: 29,
    frameMs: 100,
    colors: _standardColors,
  ),
];

const kDefaultKeyStyleId = 'key_1';
const kDefaultKeyColorId = 'grey';

KeyStyle keyStyleById(String id) =>
    kKeyCatalog.firstWhere((s) => s.id == id, orElse: () => kKeyCatalog.first);

KeyColorOption keyColorById(KeyStyle style, String colorId) => style.colors
    .firstWhere((c) => c.id == colorId, orElse: () => style.colors.first);

String renderColorIdFor(KeyStyle style, String savedColorId) {
  if (style.colors.any((c) => c.id == savedColorId)) return savedColorId;
  if (style.colors.any((c) => c.id == 'grey')) return 'grey';
  return style.colors.first.id;
}

int colorCenterIndex(KeyStyle style, String savedColorId) {
  final i = style.colors.indexWhere((c) => c.id == savedColorId);
  if (i != -1) return i;
  final greyI = style.colors.indexWhere((c) => c.id == 'grey');
  return greyI != -1 ? greyI : 0;
}

KeyColorOption keyColorForRender(KeyStyle style, String savedColorId) =>
    keyColorById(style, renderColorIdFor(style, savedColorId));
