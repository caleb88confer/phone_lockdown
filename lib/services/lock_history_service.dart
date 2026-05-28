import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// A single day's locked-time total, oldest-first when returned in a window.
typedef DayBucket = ({DateTime date, int ms});

/// Records locked-phone time into per-day buckets plus session aggregates so
/// the stats dashboard can derive streaks, averages, and a 7-day chart.
///
/// Fed from the same commit path as [MasterKeyService] / [UnlockStateService]
/// (single source of timing truth). All derived stats — streaks, best day,
/// average — are computed on read; only the raw buckets and session counters
/// are stored. The clock is injectable so streak/bucket logic is testable.
class LockHistoryService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  final Map<String, int> _daily = {};
  int _sessionCount = 0;
  int _longestSessionMs = 0;
  int _currentSessionMs = 0;
  bool _initialized = false;

  LockHistoryService({
    required SharedPreferences prefs,
    DateTime Function() now = DateTime.now,
  }) : _prefs = prefs,
       _now = now;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final dailyJson = _prefs.getString(kPrefLockHistoryDaily);
    if (dailyJson != null) {
      try {
        final decoded = jsonDecode(dailyJson) as Map<String, dynamic>;
        decoded.forEach((k, v) => _daily[k] = (v as num).toInt());
      } catch (_) {
        // Corrupt payload — start clean rather than crash the launch path.
      }
    }
    _sessionCount = _prefs.getInt(kPrefLockHistorySessionCount) ?? 0;
    _longestSessionMs = _prefs.getInt(kPrefLockHistoryLongestSessionMs) ?? 0;
    _currentSessionMs = _prefs.getInt(kPrefLockHistoryCurrentSessionMs) ?? 0;
  }

  /// Adds [delta] of locked time to today's bucket and the running session.
  /// A delta straddling midnight lands entirely in today's bucket — commits
  /// fire every ~30s so the error is negligible.
  Future<void> recordLockedTime(Duration delta) async {
    final ms = delta.inMilliseconds;
    if (ms <= 0) return;
    final key = _dateKey(_dateOnly(_now()));
    _daily[key] = (_daily[key] ?? 0) + ms;
    _currentSessionMs += ms;
    await _persist();
    notifyListeners();
  }

  /// A lock session began: count it and start a fresh session accumulator.
  Future<void> onSessionStarted() async {
    _sessionCount += 1;
    _currentSessionMs = 0;
    await _persist();
    notifyListeners();
  }

  /// A lock session ended: fold its length into the longest-session record.
  Future<void> onSessionEnded() async {
    _longestSessionMs = math.max(_longestSessionMs, _currentSessionMs);
    _currentSessionMs = 0;
    await _persist();
    notifyListeners();
  }

  // ── Derived stats ──────────────────────────────────────────────────────

  /// The seven days ending today, oldest first. Days with no recorded time
  /// report `ms: 0` so the chart always has a full week of bars.
  List<DayBucket> get last7Days {
    final today = _dateOnly(_now());
    return [
      for (var i = 6; i >= 0; i--)
        (
          date: DateTime(today.year, today.month, today.day - i),
          ms: _daily[_dateKey(DateTime(today.year, today.month, today.day - i))] ?? 0,
        ),
    ];
  }

  /// The single highest day on record, all-time. Zero if nothing is recorded.
  int get bestDayMs =>
      _daily.values.isEmpty ? 0 : _daily.values.reduce(math.max);

  /// Consecutive days with locked time ending at today. If today has no lock
  /// yet but yesterday did, the streak still counts (same-day grace) — a
  /// low-pressure framing that doesn't punish a not-yet-locked morning.
  int get currentStreak {
    final today = _dateOnly(_now());
    var cursor = today;
    if ((_daily[_dateKey(today)] ?? 0) == 0) {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      if ((_daily[_dateKey(yesterday)] ?? 0) == 0) return 0;
      cursor = yesterday;
    }
    var streak = 0;
    while ((_daily[_dateKey(cursor)] ?? 0) > 0) {
      streak += 1;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// Longest consecutive run of locked days anywhere in the record.
  int get longestStreak {
    final days =
        (_daily.entries.where((e) => e.value > 0).map((e) => _parseKey(e.key)).toList())
          ..sort();
    if (days.isEmpty) return 0;
    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final prev = days[i - 1];
      final expected = DateTime(prev.year, prev.month, prev.day + 1);
      run = days[i] == expected ? run + 1 : 1;
      longest = math.max(longest, run);
    }
    return longest;
  }

  int get sessionCount => _sessionCount;

  /// Longest session on record, including any session currently in progress.
  Duration get longestSession =>
      Duration(milliseconds: math.max(_longestSessionMs, _currentSessionMs));

  /// Mean locked time per session across all recorded time.
  Duration get averageSession => _sessionCount == 0
      ? Duration.zero
      : Duration(milliseconds: recordedTotalMs ~/ _sessionCount);

  /// Sum of every daily bucket — the total locked time this recorder has seen.
  int get recordedTotalMs =>
      _daily.values.fold(0, (sum, ms) => sum + ms);

  Future<void> debugReset() async {
    _daily.clear();
    _sessionCount = 0;
    _longestSessionMs = 0;
    _currentSessionMs = 0;
    await _persist();
    notifyListeners();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<void> _persist() async {
    await _prefs.setString(kPrefLockHistoryDaily, jsonEncode(_daily));
    await _prefs.setInt(kPrefLockHistorySessionCount, _sessionCount);
    await _prefs.setInt(kPrefLockHistoryLongestSessionMs, _longestSessionMs);
    await _prefs.setInt(kPrefLockHistoryCurrentSessionMs, _currentSessionMs);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
