import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../utils/app_logger.dart';
import 'app_blocker_service.dart';
import 'lock_history_service.dart';
import 'unlock_state_service.dart';

/// Tracks cumulative phone-locked-down time and awards passive "master keys"
/// the user can spend to unlock all active profiles without scanning.
///
/// Time accounting is wall-clock with respect to "any lock active" — concurrent
/// locks do not double-count. Progress toward the next key is frozen at the
/// max-count cap, resuming after the user spends one.
class MasterKeyService extends ChangeNotifier with WidgetsBindingObserver {
  final SharedPreferences _prefs;
  final AppBlockerService _appBlocker;
  final UnlockStateService _unlockState;
  final LockHistoryService _lockHistory;

  int _count = 0;
  int _totalLockdownMs = 0;
  int _progressMs = 0;
  int? _sessionStartMs;
  Timer? _tickTimer;
  bool _initialized = false;

  MasterKeyService({
    required SharedPreferences prefs,
    required AppBlockerService appBlocker,
    required UnlockStateService unlockState,
    required LockHistoryService lockHistory,
  }) : _prefs = prefs,
       _appBlocker = appBlocker,
       _unlockState = unlockState,
       _lockHistory = lockHistory;

  int get count => _count;
  int get totalLockdownMs => _totalLockdownMs;
  Duration get totalLockdown => Duration(milliseconds: _totalLockdownMs);
  int get progressMs => _progressMs;
  Duration get progressTowardNext =>
      Duration(milliseconds: math.max(0, kMasterKeyAwardMs - _progressMs));
  bool get isMaxed => _count >= kMasterKeyMaxCount;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _appBlocker.ready;

    _count = _prefs.getInt(kPrefMasterKeyCount) ?? 0;
    _totalLockdownMs = _prefs.getInt(kPrefMasterKeyTotalMs) ?? 0;
    _progressMs = _prefs.getInt(kPrefMasterKeyProgressMs) ?? 0;
    _sessionStartMs = _prefs.getInt(kPrefMasterKeySessionStartMs);

    final hasInitialized =
        _prefs.getBool(kPrefMasterKeyHasInitialized) ?? false;
    if (!hasInitialized) {
      // TODO(testing): seeds 3 master keys on first run; remove before ship
      _count = kMasterKeyMaxCount;
      _totalLockdownMs = 0;
      _progressMs = 0;
      _sessionStartMs = null;
      await _persist();
      await _prefs.setBool(kPrefMasterKeyHasInitialized, true);
      AppLogger.d('MasterKey', 'First-run seed: $_count master keys');
    }

    final nowActive = _appBlocker.isBlocking;
    if (nowActive && _sessionStartMs == null) {
      // App was killed mid-session. Recover by anchoring to earliest lock.
      final earliest = _appBlocker.earliestActiveLockStartTime;
      _sessionStartMs = (earliest ?? DateTime.now()).millisecondsSinceEpoch;
      await _persist();
      AppLogger.d(
        'MasterKey',
        'Recovered mid-session start from active lock: $_sessionStartMs',
      );
    } else if (!nowActive && _sessionStartMs != null) {
      // Session ended while app was dead (native failsafe likely fired).
      // Best-effort commit; slight overcount acceptable for MVP.
      await commitElapsed();
      await _lockHistory.onSessionEnded();
      AppLogger.d('MasterKey', 'Committed orphaned session on startup');
    }

    _appBlocker.addListener(_handleAppBlockerChanged);
    WidgetsBinding.instance.addObserver(this);

    if (_appBlocker.isBlocking && _sessionStartMs != null) {
      _startTickTimer();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _appBlocker.removeListener(_handleAppBlockerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Persist any time accumulated since last tick before backgrounding.
      commitElapsed();
    }
  }

  void _handleAppBlockerChanged() {
    final wasActive = _sessionStartMs != null;
    final nowActive = _appBlocker.isBlocking;

    if (!wasActive && nowActive) {
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
      _persist();
      _lockHistory.onSessionStarted();
      _startTickTimer();
      notifyListeners();
    } else if (wasActive && !nowActive) {
      _endSession();
    }
  }

  /// Commits the final slice of locked time, then closes the session so its
  /// length folds into the longest-session record. Ordered so the closing
  /// commit lands before [LockHistoryService.onSessionEnded] reads it.
  Future<void> _endSession() async {
    await commitElapsed();
    await _lockHistory.onSessionEnded();
    _stopTickTimer();
  }

  /// Commits time elapsed since the current session started (or since the last
  /// commit). Idempotent — safe to call repeatedly while a session is active.
  /// Awards master keys when [_progressMs] crosses the threshold.
  Future<void> commitElapsed() async {
    final start = _sessionStartMs;
    if (start == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = math.max(0, now - start);
    if (delta == 0) return;

    _totalLockdownMs += delta;
    // Feed the same delta into unlock progression — single source of timing
    // truth (architecture doc chunk 6, option (a)).
    await _unlockState.addLockedTime(Duration(milliseconds: delta));
    // Parallel feed into the stats recorder (same single source of truth).
    await _lockHistory.recordLockedTime(Duration(milliseconds: delta));

    if (_count < kMasterKeyMaxCount) {
      _progressMs += delta;
      while (_progressMs >= kMasterKeyAwardMs && _count < kMasterKeyMaxCount) {
        _progressMs -= kMasterKeyAwardMs;
        _count++;
        AppLogger.d(
          'MasterKey',
          'Awarded master key — count=$_count, total=${_totalLockdownMs}ms',
        );
      }
      if (_count >= kMasterKeyMaxCount) _progressMs = 0; // freeze at cap
    }

    _sessionStartMs = _appBlocker.isBlocking ? now : null;
    await _persist();
    notifyListeners();
  }

  /// Spends one master key. Returns false if none are available.
  Future<bool> consume() async {
    if (_count == 0) return false;
    _count--;
    await _persist();
    notifyListeners();
    AppLogger.d('MasterKey', 'Consumed — count=$_count');
    return true;
  }

  /// Wipes all master key state and re-applies the first-run seed.
  Future<void> resetForTesting() async {
    _stopTickTimer();
    _count = kMasterKeyMaxCount;
    _totalLockdownMs = 0;
    _progressMs = 0;
    _sessionStartMs = _appBlocker.isBlocking
        ? DateTime.now().millisecondsSinceEpoch
        : null;
    await _persist();
    await _prefs.setBool(kPrefMasterKeyHasInitialized, true);
    if (_appBlocker.isBlocking) _startTickTimer();
    notifyListeners();
    AppLogger.d('MasterKey', 'Reset for testing — count=$_count');
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(seconds: kMasterKeyTickSeconds),
      (_) => commitElapsed(),
    );
  }

  void _stopTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> _persist() async {
    await _prefs.setInt(kPrefMasterKeyCount, _count);
    await _prefs.setInt(kPrefMasterKeyTotalMs, _totalLockdownMs);
    await _prefs.setInt(kPrefMasterKeyProgressMs, _progressMs);
    final start = _sessionStartMs;
    if (start == null) {
      await _prefs.remove(kPrefMasterKeySessionStartMs);
    } else {
      await _prefs.setInt(kPrefMasterKeySessionStartMs, start);
    }
  }
}
