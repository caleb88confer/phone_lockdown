import 'package:flutter/foundation.dart';

/// Tracks how many customization/achievement items the user has unlocked.
///
/// Stub implementation — returns hardcoded dummy values until a real unlock
/// system (per-lock-style, per-key-style, achievements) is wired in.
class UnlockedItemsService extends ChangeNotifier {
  int get unlockedCount => 4;
  int get totalCount => 40;
}
