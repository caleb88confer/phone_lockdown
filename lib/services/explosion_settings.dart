import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// A selectable shard colour for the lock-landing pixel burst.
class ExplosionColorOption {
  final String label;
  final Color color;
  const ExplosionColorOption(this.label, this.color);
}

/// Fixed palette the burst picks shard colours from. Stored by index, so the
/// order here is part of the persistence contract — append, don't reorder.
const kExplosionPalette = <ExplosionColorOption>[
  ExplosionColorOption('White', Color(0xFFFFFFFF)),
  ExplosionColorOption('Gold', Color(0xFFFFB800)),
  ExplosionColorOption('Red', Color(0xFFB02D28)),
  ExplosionColorOption('Blue', Color(0xFF005BBE)),
  ExplosionColorOption('Bronze', Color(0xFFB07849)),
  ExplosionColorOption('Grey', Color(0xFF888888)),
  ExplosionColorOption('Black', Color(0xFF1F1F1F)),
];

/// Tunable parameters for the lock-landing pixel burst, plus the debug
/// "setup mode" flag. Persisted so tuning sticks, and read by the live app —
/// the defaults reproduce the original hardcoded burst exactly.
class ExplosionSettings extends ChangeNotifier {
  final SharedPreferences _prefs;

  bool _setupMode;
  int _count;
  double _sizeScale;
  double _spread;
  double _spinTurns;
  int _durationMs;
  Set<int> _colorIndices;

  static const _defaultCount = 16;
  static const _defaultSizeScale = 1.0;
  static const _defaultSpread = 1.0;
  static const _defaultSpinTurns = 2.0;
  static const _defaultDurationMs = 720;
  static const _defaultColors = {0, 1}; // white, gold

  ExplosionSettings({required SharedPreferences prefs})
    : _prefs = prefs,
      _setupMode = prefs.getBool(kPrefExplosionSetupMode) ?? false,
      _count = prefs.getInt(kPrefExplosionCount) ?? _defaultCount,
      _sizeScale = prefs.getDouble(kPrefExplosionSizeScale) ?? _defaultSizeScale,
      _spread = prefs.getDouble(kPrefExplosionSpread) ?? _defaultSpread,
      _spinTurns =
          prefs.getDouble(kPrefExplosionSpinTurns) ?? _defaultSpinTurns,
      _durationMs = prefs.getInt(kPrefExplosionDurationMs) ?? _defaultDurationMs,
      _colorIndices = _decodeColors(prefs.getString(kPrefExplosionColors));

  static Set<int> _decodeColors(String? raw) {
    if (raw == null || raw.isEmpty) return {..._defaultColors};
    final out = <int>{};
    for (final part in raw.split(',')) {
      final i = int.tryParse(part.trim());
      if (i != null && i >= 0 && i < kExplosionPalette.length) out.add(i);
    }
    return out.isEmpty ? {..._defaultColors} : out;
  }

  bool get setupMode => _setupMode;
  int get count => _count;
  double get sizeScale => _sizeScale;
  double get spread => _spread;
  double get spinTurns => _spinTurns;
  int get durationMs => _durationMs;
  Duration get duration => Duration(milliseconds: _durationMs);
  Set<int> get colorIndices => {..._colorIndices};

  /// Concrete shard colours for the enabled palette entries. Never empty.
  List<Color> get colors {
    final list = _colorIndices.map((i) => kExplosionPalette[i].color).toList();
    return list.isEmpty ? const [Color(0xFFFFFFFF)] : list;
  }

  set setupMode(bool v) {
    if (_setupMode == v) return;
    _setupMode = v;
    _prefs.setBool(kPrefExplosionSetupMode, v);
    notifyListeners();
  }

  set count(int v) {
    final c = v.clamp(2, 60).round();
    if (_count == c) return;
    _count = c;
    _prefs.setInt(kPrefExplosionCount, c);
    notifyListeners();
  }

  set sizeScale(double v) {
    final c = v.clamp(0.3, 3.0).toDouble();
    if (_sizeScale == c) return;
    _sizeScale = c;
    _prefs.setDouble(kPrefExplosionSizeScale, c);
    notifyListeners();
  }

  set spread(double v) {
    final c = v.clamp(0.3, 3.0).toDouble();
    if (_spread == c) return;
    _spread = c;
    _prefs.setDouble(kPrefExplosionSpread, c);
    notifyListeners();
  }

  set spinTurns(double v) {
    final c = v.clamp(0.0, 6.0).toDouble();
    if (_spinTurns == c) return;
    _spinTurns = c;
    _prefs.setDouble(kPrefExplosionSpinTurns, c);
    notifyListeners();
  }

  set durationMs(int v) {
    final c = v.clamp(150, 2000).round();
    if (_durationMs == c) return;
    _durationMs = c;
    _prefs.setInt(kPrefExplosionDurationMs, c);
    notifyListeners();
  }

  /// Toggles a palette colour on/off. Keeps at least one colour enabled.
  void toggleColor(int index) {
    if (index < 0 || index >= kExplosionPalette.length) return;
    if (_colorIndices.contains(index)) {
      if (_colorIndices.length == 1) return;
      _colorIndices.remove(index);
    } else {
      _colorIndices.add(index);
    }
    _prefs.setString(kPrefExplosionColors, _colorIndices.join(','));
    notifyListeners();
  }

  void resetToDefaults() {
    _count = _defaultCount;
    _sizeScale = _defaultSizeScale;
    _spread = _defaultSpread;
    _spinTurns = _defaultSpinTurns;
    _durationMs = _defaultDurationMs;
    _colorIndices = {..._defaultColors};
    _prefs.setInt(kPrefExplosionCount, _count);
    _prefs.setDouble(kPrefExplosionSizeScale, _sizeScale);
    _prefs.setDouble(kPrefExplosionSpread, _spread);
    _prefs.setDouble(kPrefExplosionSpinTurns, _spinTurns);
    _prefs.setInt(kPrefExplosionDurationMs, _durationMs);
    _prefs.setString(kPrefExplosionColors, _colorIndices.join(','));
    notifyListeners();
  }
}
