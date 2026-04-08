# Items to Fix

## Priority Fixes

### ~~1. SharedPreferences State Corruption~~ FIXED
**Risk:** Could brick the user's phone in a blocking state they can't exit.

`BlockingStateManager.kt` writes 4 separate SharedPreferences keys (`isBlocking`, `blockedPackages`, `blockedWebsites`, `activeProfileBlocks`) with a single `apply()`. If the process dies mid-write, you get a half-updated state — e.g. `isBlocking = true` but empty blocked lists, or stale failsafe alarms with no matching profile.

**Fix:** ~~Write a single JSON blob atomically instead of 4 separate keys, or use `commit()` instead of `apply()` for the critical path.~~ Changed `apply()` to `commit()` in `BlockingStateManager.updateBlockingState()` and `FailsafeAlarmReceiver.deactivateProfile()` so writes are synchronous and atomic.

---

### ~~2. Silent Blocking Failures~~ FIXED
**Risk:** User thinks they're locked down but they're not.

If the accessibility service isn't enabled or the VPN fails to start, `activateProfile()` returns `false` and the UI does nothing. No error message, no feedback. The `debugPrint` only shows in debug builds.

**Fix:** ~~Surface an error message or snackbar when blocking can't activate. Tell the user what went wrong and what to do about it.~~ Changed `activateProfile()` to return `String?` (null = success, non-null = descriptive error). Added VPN readiness check for profiles with blocked websites. UI now shows specific error messages in an alert dialog.

---

### ~~3. Timer-State Desync Between Flutter and Android~~ FIXED
**Risk:** Orphaned locks that never expire.

If the app crashes between setting the Flutter-side timer (line 96 in `app_blocker_service.dart`) and syncing to Android (line 99), you get a lock registered on one side but not the other. `reconcileWithAndroid` on startup tries to fix this, but if Android also has stale data, a lock could persist with no expiration.

**Fix:** ~~Make Android the single source of truth for active locks. On startup, always read lock state from Android rather than restoring from Flutter-side storage.~~ Reordered `activateProfile()`: Android alarm is now scheduled first, then blocking state synced, then Flutter state persisted, then Flutter timer started last. If the app crashes at any point, Android's alarm will still fire and auto-deactivate.

---

### ~~4. Stale Timer Refs on Profile Deletion~~ FIXED
**Risk:** Lock that can't be removed from the UI.

If a user deletes a profile while a lock is active, `_activeLocks` holds a reference to a profile that no longer exists. When the failsafe timer fires, it tries to look up the profile, gets null, and the lock lingers in `_activeLocks`. Android-side enforcement may also persist.

**Fix:** ~~Clean up `_activeLocks` and cancel Android-side enforcement when a profile is deleted.~~ Added `onProfileDeleted()` to `AppBlockerService` which deactivates the lock and cancels Android-side enforcement. Called from profile deletion UI before the profile is removed from `ProfileManager`.

---

### ~~5. Async Fire-and-Forget in Failsafe Callback~~ FIXED
**Risk:** Apps/sites stay blocked with no way to unlock from UI.

In `_startFailsafeTimer`, the `_recomputeAndApply()` call is async inside a `Timer` callback but isn't awaited. If it throws, the lock is removed from `_activeLocks` (Flutter thinks it's unlocked) but Android still enforces blocking. The UI shows no active lock, but the user's apps/sites remain blocked.

**Fix:** ~~Handle errors in the timer callback — if `_recomputeAndApply()` fails, retry or at minimum keep `_activeLocks` consistent with what Android is actually enforcing.~~ Wrapped timer callback in try/catch. On failure, the lock is restored to `_activeLocks` so Flutter stays consistent with Android's enforcement state. Also reordered to call `_recomputeAndApply()` before `_saveActiveLocks()` so Flutter state isn't persisted until Android is updated.

---

## Nice to Have

### Test Coverage on Enforcement Paths
The VPN service and accessibility service have no tests. Not a brick risk today, but makes future changes to the blocking logic risky. Priority targets: `LockdownVpnService` packet handling, `LockdownAccessibilityService` blocking behavior, `FailsafeAlarmReceiver` deactivation.

### Packet Buffer Optimization
`LockdownVpnService.kt` calls `packet.copyOf(length)` on every packet, allocating a new buffer each time. Under heavy network load this creates GC pressure. Use `copyOfRange(0, length)` or a buffer pool.

### Centralized Error Logging
`debugPrint` on the Dart side and mixed `Log.e`/`Log.w` on the Kotlin side means zero visibility into what's failing for real users. A lightweight logging/crash reporting solution would help diagnose issues in the wild.
