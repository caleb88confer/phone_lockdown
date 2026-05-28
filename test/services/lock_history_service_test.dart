import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/services/lock_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controllable clock so streak/bucket logic is deterministic in tests.
class _Clock {
  DateTime value;
  _Clock(this.value);
  DateTime call() => value;
}

Future<LockHistoryService> _freshService(
  _Clock clock, [
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final svc = LockHistoryService(prefs: prefs, now: clock.call);
  await svc.init();
  return svc;
}

Duration _h(num hours) => Duration(milliseconds: (hours * 3600 * 1000).round());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('daily buckets', () {
    test('records time into today\'s bucket and totals it', () async {
      final clock = _Clock(DateTime(2026, 5, 28, 9));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(2));
      await svc.recordLockedTime(_h(1));
      expect(svc.recordedTotalMs, _h(3).inMilliseconds);
      expect(svc.last7Days.last.ms, _h(3).inMilliseconds);
    });

    test('time on different days lands in separate buckets', () async {
      final clock = _Clock(DateTime(2026, 5, 27, 12));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(2));
      clock.value = DateTime(2026, 5, 28, 12);
      await svc.recordLockedTime(_h(5));
      final week = svc.last7Days;
      expect(week.last.ms, _h(5).inMilliseconds); // today
      expect(week[week.length - 2].ms, _h(2).inMilliseconds); // yesterday
    });

    test('ignores zero / negative deltas', () async {
      final clock = _Clock(DateTime(2026, 5, 28, 9));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(Duration.zero);
      await svc.recordLockedTime(const Duration(milliseconds: -5));
      expect(svc.recordedTotalMs, 0);
    });
  });

  group('last7Days', () {
    test('always returns 7 entries, oldest first, ending today', () async {
      final clock = _Clock(DateTime(2026, 5, 28, 9));
      final svc = await _freshService(clock);
      final week = svc.last7Days;
      expect(week, hasLength(7));
      expect(week.first.date, DateTime(2026, 5, 22));
      expect(week.last.date, DateTime(2026, 5, 28));
      expect(week.every((d) => d.ms == 0), isTrue);
    });

    test('time older than 7 days is excluded from the window', () async {
      final clock = _Clock(DateTime(2026, 5, 20));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(4)); // 8 days before the 28th
      clock.value = DateTime(2026, 5, 28);
      expect(svc.last7Days.every((d) => d.ms == 0), isTrue);
      expect(svc.recordedTotalMs, _h(4).inMilliseconds); // still in total
    });
  });

  group('best day', () {
    test('reports the highest single day all-time', () async {
      final clock = _Clock(DateTime(2026, 5, 26));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(3));
      clock.value = DateTime(2026, 5, 27);
      await svc.recordLockedTime(_h(7));
      clock.value = DateTime(2026, 5, 28);
      await svc.recordLockedTime(_h(2));
      expect(svc.bestDayMs, _h(7).inMilliseconds);
    });

    test('is zero with no recorded time', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      expect(svc.bestDayMs, 0);
    });
  });

  group('current streak', () {
    test('counts consecutive days ending today', () async {
      final clock = _Clock(DateTime(2026, 5, 26));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(1));
      clock.value = DateTime(2026, 5, 27);
      await svc.recordLockedTime(_h(1));
      clock.value = DateTime(2026, 5, 28);
      await svc.recordLockedTime(_h(1));
      expect(svc.currentStreak, 3);
    });

    test('same-day grace: yesterday locked, today not yet, still counts', () async {
      final clock = _Clock(DateTime(2026, 5, 27, 23));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(2));
      // Roll into the next morning with nothing recorded yet.
      clock.value = DateTime(2026, 5, 28, 7);
      expect(svc.currentStreak, 1);
    });

    test('breaks when neither today nor yesterday has time', () async {
      final clock = _Clock(DateTime(2026, 5, 25));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(2));
      clock.value = DateTime(2026, 5, 28); // two clear days later
      expect(svc.currentStreak, 0);
    });

    test('a gap resets the run to the most recent unbroken span', () async {
      final clock = _Clock(DateTime(2026, 5, 24));
      final svc = await _freshService(clock);
      await svc.recordLockedTime(_h(1)); // 24th
      clock.value = DateTime(2026, 5, 26);
      await svc.recordLockedTime(_h(1)); // 26th (gap on the 25th)
      clock.value = DateTime(2026, 5, 27);
      await svc.recordLockedTime(_h(1)); // 27th
      clock.value = DateTime(2026, 5, 28);
      await svc.recordLockedTime(_h(1)); // 28th
      expect(svc.currentStreak, 3); // 26→27→28
    });
  });

  group('longest streak', () {
    test('finds the longest run across the whole record', () async {
      final clock = _Clock(DateTime(2026, 5, 1));
      final svc = await _freshService(clock);
      // A 4-day run: May 1–4.
      for (final d in [1, 2, 3, 4]) {
        clock.value = DateTime(2026, 5, d);
        await svc.recordLockedTime(_h(1));
      }
      // A separate 2-day run: May 10–11.
      for (final d in [10, 11]) {
        clock.value = DateTime(2026, 5, d);
        await svc.recordLockedTime(_h(1));
      }
      expect(svc.longestStreak, 4);
    });

    test('is zero with no recorded time and one for a single day', () async {
      final clock = _Clock(DateTime(2026, 5, 28));
      final svc = await _freshService(clock);
      expect(svc.longestStreak, 0);
      await svc.recordLockedTime(_h(1));
      expect(svc.longestStreak, 1);
    });
  });

  group('sessions', () {
    test('onSessionStarted increments the count and resets the accumulator', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      await svc.onSessionStarted();
      await svc.onSessionStarted();
      expect(svc.sessionCount, 2);
    });

    test('longest session captures the biggest finished session', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(2));
      await svc.onSessionEnded();
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(5));
      await svc.onSessionEnded();
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(1));
      await svc.onSessionEnded();
      expect(svc.longestSession, _h(5));
    });

    test('longest session includes an in-progress session', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(6)); // not yet ended
      expect(svc.longestSession, _h(6));
    });

    test('average session divides total time by session count', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(2));
      await svc.onSessionEnded();
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(4));
      await svc.onSessionEnded();
      expect(svc.averageSession, _h(3)); // (2h + 4h) / 2
    });

    test('average session is zero with no sessions', () async {
      final svc = await _freshService(_Clock(DateTime(2026, 5, 28)));
      expect(svc.averageSession, Duration.zero);
    });
  });

  group('persistence', () {
    test('buckets and session aggregates survive a fresh instance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final clock = _Clock(DateTime(2026, 5, 27));

      final svc1 = LockHistoryService(prefs: prefs, now: clock.call);
      await svc1.init();
      await svc1.onSessionStarted();
      await svc1.recordLockedTime(_h(3));
      await svc1.onSessionEnded();
      clock.value = DateTime(2026, 5, 28);
      await svc1.onSessionStarted();
      await svc1.recordLockedTime(_h(2));

      final svc2 = LockHistoryService(prefs: prefs, now: clock.call);
      await svc2.init();
      expect(svc2.recordedTotalMs, _h(5).inMilliseconds);
      expect(svc2.sessionCount, 2);
      expect(svc2.longestSession, _h(3));
      expect(svc2.currentStreak, 2);
    });
  });

  group('debugReset', () {
    test('wipes all buckets and counters', () async {
      final clock = _Clock(DateTime(2026, 5, 28));
      final svc = await _freshService(clock);
      await svc.onSessionStarted();
      await svc.recordLockedTime(_h(4));
      await svc.onSessionEnded();
      await svc.debugReset();
      expect(svc.recordedTotalMs, 0);
      expect(svc.sessionCount, 0);
      expect(svc.longestSession, Duration.zero);
      expect(svc.bestDayMs, 0);
      expect(svc.currentStreak, 0);
    });
  });
}
