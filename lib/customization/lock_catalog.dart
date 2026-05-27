import 'sprite_defaults.dart';

class LockColorOption {
  final String id;
  final String displayName;
  final int swatchColor;

  const LockColorOption({
    required this.id,
    required this.displayName,
    required this.swatchColor,
  });
}

class LockStyle {
  final String id;
  final String displayName;
  final int frameCount;
  final int frameWidth;
  final int frameHeight;
  final int unlockedFrame;
  final int lockedFrame;
  final List<LockColorOption> colors;
  // Multiplier applied to render size to compensate for sprites whose frame
  // canvas includes padding around the visible glyph.
  final double displayScale;
  // Per-frame duration in ms. Null falls back to kDefaultLockFrameMs.
  final int? frameMs;
  // Vertical paint offset as a fraction of rendered height. Negative shifts
  // the sprite up, positive shifts it down. Layout footprint is unaffected.
  final double centerOffsetY;

  const LockStyle({
    required this.id,
    required this.displayName,
    required this.frameCount,
    required this.frameWidth,
    required this.frameHeight,
    required this.unlockedFrame,
    required this.lockedFrame,
    required this.colors,
    this.displayScale = 1.0,
    this.frameMs,
    this.centerOffsetY = 0.0,
  });

  String spritesheetPath(String colorId) =>
      'assets/sprites/locks/${id}_$colorId.png';

  bool get hasDistinctStates => unlockedFrame != lockedFrame;

  /// Every lock sheet animates closed -> open -> closed, so the most-open
  /// pose sits at the middle frame. Used to render the resting "unlocked"
  /// look regardless of how many frames a given lock has.
  int get openFrame => frameCount ~/ 2;

  /// Frame 0 is the fully-closed shackle on every sheet (the final frame is an
  /// identical closed pose), so it doubles as the resting closed frame and the
  /// anchor for the two transition animations below.
  int get closedFrame => 0;

  /// Frames for the "unlocking" transition: closed shackle easing open.
  /// The first half of the sheet, ending on the fully-open [openFrame].
  (int, int) get openingRange => (closedFrame, openFrame);

  /// Frames for the "locking" transition: open shackle easing closed.
  /// The second half of the sheet, from [openFrame] back to the closed pose.
  /// The midpoint provably lands inside every lock's fully-open hold, so this
  /// always begins on a genuinely open frame.
  (int, int) get closingRange => (openFrame, frameCount - 1);

  Duration durationFor(int framesPlayed) =>
      Duration(milliseconds: (frameMs ?? kDefaultLockFrameMs) * framesPlayed);
}

const _grey = LockColorOption(
  id: 'grey',
  displayName: 'Grey',
  swatchColor: 0xFF888888,
);
const _gold = LockColorOption(
  id: 'gold',
  displayName: 'Gold',
  swatchColor: 0xFFD4A437,
);
const _bronze = LockColorOption(
  id: 'bronze',
  displayName: 'Bronze',
  swatchColor: 0xFFB07849,
);
const _black = LockColorOption(
  id: 'black',
  displayName: 'Black',
  swatchColor: 0xFF1F1F1F,
);
const _red = LockColorOption(
  id: 'red',
  displayName: 'Red',
  swatchColor: 0xFFB02D28,
);
const _beige = LockColorOption(
  id: 'beige',
  displayName: 'Beige',
  swatchColor: 0xFFD9C9A8,
);
const _copper = LockColorOption(
  id: 'copper',
  displayName: 'Copper',
  swatchColor: 0xFFB87333,
);
const _mossy = LockColorOption(
  id: 'mossy',
  displayName: 'Mossy',
  swatchColor: 0xFF6B7A3A,
);

const kLockCatalog = <LockStyle>[
  LockStyle(
    id: 'small_sturdy',
    displayName: 'Small Sturdy',
    frameCount: 10,
    frameWidth: 16,
    frameHeight: 22,
    unlockedFrame: 0,
    lockedFrame: 9,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'small_round',
    displayName: 'Small Round',
    frameCount: 13,
    frameWidth: 16,
    frameHeight: 23,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'small_oval',
    displayName: 'Small Oval',
    frameCount: 11,
    frameWidth: 16,
    frameHeight: 23,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'small_square',
    displayName: 'Small Square',
    frameCount: 12,
    frameWidth: 14,
    frameHeight: 20,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'shield_like',
    displayName: 'Shield',
    frameCount: 13,
    frameWidth: 14,
    frameHeight: 27,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'sturdy',
    displayName: 'Sturdy',
    frameCount: 17,
    frameWidth: 20,
    frameHeight: 30,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black, _red],
  ),
  LockStyle(
    id: 'robust',
    displayName: 'Robust',
    frameCount: 17,
    frameWidth: 20,
    frameHeight: 31,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _black, _red],
  ),
  LockStyle(
    id: 'round',
    displayName: 'Round',
    frameCount: 17,
    frameWidth: 20,
    frameHeight: 36,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _beige],
  ),
  LockStyle(
    id: 'triangle',
    displayName: 'Triangle',
    frameCount: 16,
    frameWidth: 20,
    frameHeight: 33,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _beige],
  ),
  LockStyle(
    id: 'old',
    displayName: 'Old',
    frameCount: 17,
    frameWidth: 24,
    frameHeight: 32,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black],
  ),
  LockStyle(
    id: 'hefty',
    displayName: 'Hefty',
    frameCount: 18,
    frameWidth: 24,
    frameHeight: 33,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _black, _red],
  ),
  LockStyle(
    id: 'extending',
    displayName: 'Extending',
    frameCount: 31,
    frameWidth: 33,
    frameHeight: 25,
    unlockedFrame: 0,
    lockedFrame: 0,
    colors: [_grey, _gold, _bronze, _copper, _mossy],
  ),
];

const kDefaultLockStyleId = 'small_square';
const kDefaultLockColorId = 'grey';

LockStyle lockStyleById(String id) => kLockCatalog.firstWhere(
  (s) => s.id == id,
  orElse: () => kLockCatalog.first,
);

LockColorOption lockColorById(LockStyle style, String colorId) => style.colors
    .firstWhere((c) => c.id == colorId, orElse: () => style.colors.first);

String renderLockColorIdFor(LockStyle style, String savedColorId) {
  if (style.colors.any((c) => c.id == savedColorId)) return savedColorId;
  if (style.colors.any((c) => c.id == 'grey')) return 'grey';
  return style.colors.first.id;
}

LockColorOption lockColorForRender(LockStyle style, String savedColorId) =>
    lockColorById(style, renderLockColorIdFor(style, savedColorId));
