# Nice-to-Have Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add test coverage for enforcement paths, eliminate per-packet buffer allocation, and centralize logging across Kotlin and Dart.

**Architecture:** Extract testable logic from Android services into pure Kotlin classes, replace scattered `Log`/`debugPrint` with unified loggers, and optimize the VPN packet loop to avoid per-read allocation. All three workstreams are independent; each task produces a working, testable commit.

**Tech Stack:** Kotlin + JUnit 5, Dart + Flutter, Android VPN/Accessibility services

---

## File Map

**New files:**
- `android/app/src/main/kotlin/app/phonelockdown/AppLogger.kt` — Kotlin logging singleton
- `android/app/src/main/kotlin/app/phonelockdown/AppBlockingDecider.kt` — extracted accessibility blocking logic
- `android/app/src/main/kotlin/app/phonelockdown/ProfileDeactivator.kt` — extracted failsafe deactivation logic
- `android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt` — extracted VPN packet handling + `DnsResolver` interface
- `android/app/src/test/kotlin/app/phonelockdown/AppBlockingDeciderTest.kt` — unit tests
- `android/app/src/test/kotlin/app/phonelockdown/ProfileDeactivatorTest.kt` — unit tests
- `android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt` — unit tests
- `lib/utils/app_logger.dart` — Dart logging utility

**Modified files:**
- `android/app/src/main/kotlin/app/phonelockdown/LockdownAccessibilityService.kt` — delegate to `AppBlockingDecider`
- `android/app/src/main/kotlin/app/phonelockdown/FailsafeAlarmReceiver.kt` — delegate to `ProfileDeactivator`
- `android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt` — delegate to `VpnPacketHandler`, remove `copyOf`, implement `DnsResolver`
- `android/app/src/main/kotlin/app/phonelockdown/BlockingStateManager.kt` — use `AppLogger`
- `android/app/src/main/kotlin/app/phonelockdown/VpnController.kt` — use `AppLogger`
- `android/app/src/main/kotlin/app/phonelockdown/ServiceMonitorWorker.kt` — use `AppLogger`
- `android/app/src/main/kotlin/app/phonelockdown/PrefsHelper.kt` — use `AppLogger`
- `lib/services/app_blocker_service.dart` — use `AppLogger`

---

### Task 1: Create Kotlin `AppLogger` singleton

**Files:**
- Create: `android/app/src/main/kotlin/app/phonelockdown/AppLogger.kt`

- [ ] **Step 1: Create `AppLogger.kt`**

```kotlin
package app.phonelockdown

import android.util.Log

object AppLogger {
    private const val PREFIX = "PhoneLockdown"

    fun d(tag: String, msg: String) = Log.d("$PREFIX/$tag", msg)
    fun i(tag: String, msg: String) = Log.i("$PREFIX/$tag", msg)
    fun w(tag: String, msg: String) = Log.w("$PREFIX/$tag", msg)
    fun w(tag: String, msg: String, t: Throwable) = Log.w("$PREFIX/$tag", msg, t)
    fun e(tag: String, msg: String) = Log.e("$PREFIX/$tag", msg)
    fun e(tag: String, msg: String, t: Throwable) = Log.e("$PREFIX/$tag", msg, t)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd android && ./gradlew compileDebugKotlin 2>&1 | tail -5`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/AppLogger.kt
git commit -m "feat: add AppLogger singleton for centralized Kotlin logging"
```

---

### Task 2: Replace all Kotlin `Log` calls with `AppLogger`

**Files:**
- Modify: `android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/FailsafeAlarmReceiver.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/BlockingStateManager.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/VpnController.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/ServiceMonitorWorker.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/PrefsHelper.kt`

- [ ] **Step 1: Replace `Log` calls in `LockdownVpnService.kt`**

Replace every `Log.x(TAG, ...)` call with `AppLogger.x("VPN", ...)`. Remove the `TAG` companion constant. Remove the `import android.util.Log` line.

Specific replacements (10 calls):
- Line 71: `Log.w(TAG, "VPN revoked by system (another VPN may have taken over)")` → `AppLogger.w("VPN", "VPN revoked by system (another VPN may have taken over)")`
- Line 95: `Log.e(TAG, "Failed to establish VPN interface")` → `AppLogger.e("VPN", "Failed to establish VPN interface")`
- Line 102: `Log.i(TAG, "VPN started, blocking ${blockedWebsites.size} websites")` → `AppLogger.i("VPN", "VPN started, blocking ${blockedWebsites.size} websites")`
- Line 104: `Log.e(TAG, "Failed to start VPN", e)` → `AppLogger.e("VPN", "Failed to start VPN", e)`
- Line 118: `Log.e(TAG, "Error closing VPN interface", e)` → `AppLogger.e("VPN", "Error closing VPN interface", e)`
- Line 146: `Log.e(TAG, "Error processing packet", e)` → `AppLogger.e("VPN", "Error processing packet", e)`
- Line 192: `Log.d(TAG, "Blocking DNS query for: $domain")` → `AppLogger.d("VPN", "Blocking DNS query for: $domain")`
- Line 228: `Log.e(TAG, "Error forwarding DNS query", e)` → `AppLogger.e("VPN", "Error forwarding DNS query", e)`
- Line 254: `Log.w(TAG, "DNS forwarding to $server failed: ${e.message}")` → `AppLogger.w("VPN", "DNS forwarding to $server failed: ${e.message}")`
- Line 259: `Log.e(TAG, "All DNS servers failed")` → `AppLogger.e("VPN", "All DNS servers failed")`

- [ ] **Step 2: Replace `Log` calls in `FailsafeAlarmReceiver.kt`**

Replace `Log.x(TAG, ...)` with `AppLogger.x("Failsafe", ...)`. Remove the `TAG` companion constant. Remove the `import android.util.Log` line.

Specific replacements (2 calls):
- Line 84: `Log.e(TAG, "Failed to stop VPN service", e)` → `AppLogger.e("Failsafe", "Failed to stop VPN service", e)`
- Line 96: `Log.d(TAG, "Failsafe alarm fired for profile: $profileId")` → `AppLogger.d("Failsafe", "Failsafe alarm fired for profile: $profileId")`

- [ ] **Step 3: Replace `Log` calls in `BlockingStateManager.kt`**

Replace the single `Log.w(TAG, ...)` call. Remove the `TAG` companion constant. Remove the `import android.util.Log` line.

- Line 119: `Log.w(TAG, "Exact alarm not allowed, using inexact alarm", e)` → `AppLogger.w("BlockingState", "Exact alarm not allowed, using inexact alarm", e)`

- [ ] **Step 4: Replace `Log` calls in `VpnController.kt`**

Replace `Log.e(TAG, ...)` calls. Remove the `TAG` companion constant. Remove the `import android.util.Log` line.

- Line 49: `Log.e(TAG, "Failed to start VPN service", e)` → `AppLogger.e("VpnCtrl", "Failed to start VPN service", e)`
- Line 60: `Log.e(TAG, "Failed to stop VPN service", e)` → `AppLogger.e("VpnCtrl", "Failed to stop VPN service", e)`

- [ ] **Step 5: Replace `Log` calls in `ServiceMonitorWorker.kt`**

Replace bare `Log.x("ServiceMonitorWorker", ...)` calls with `AppLogger`. Remove the `import android.util.Log` line.

- Line 77: `Log.d("ServiceMonitorWorker", "Failsafe expired (backup) for profile: $profileId")` → `AppLogger.d("Monitor", "Failsafe expired (backup) for profile: $profileId")`
- Line 82: `Log.e("ServiceMonitorWorker", "Error checking failsafe alarms", e)` → `AppLogger.e("Monitor", "Error checking failsafe alarms", e)`

- [ ] **Step 6: Replace `Log` calls in `PrefsHelper.kt`**

Replace the `Log.i(TAG, ...)` calls. Remove the `TAG` constant and `import android.util.Log` if present.

- Line 60: `Log.i(TAG, "Migrating ${allEntries.size} entries from plain to encrypted prefs")` → `AppLogger.i("Prefs", "Migrating ${allEntries.size} entries from plain to encrypted prefs")`
- Line 81: `Log.i(TAG, "Migration complete, plain prefs cleared")` → `AppLogger.i("Prefs", "Migration complete, plain prefs cleared")`

- [ ] **Step 7: Verify it compiles and tests pass**

Run: `cd android && ./gradlew compileDebugKotlin test 2>&1 | tail -10`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 8: Commit**

```bash
git add -A android/app/src/main/kotlin/app/phonelockdown/
git commit -m "refactor: replace all Log calls with AppLogger across Kotlin files"
```

---

### Task 3: Create Dart `AppLogger` and replace `debugPrint` calls

**Files:**
- Create: `lib/utils/app_logger.dart`
- Modify: `lib/services/app_blocker_service.dart`

- [ ] **Step 1: Create `lib/utils/app_logger.dart`**

```dart
import 'package:flutter/foundation.dart';

class AppLogger {
  static const _prefix = 'PhoneLockdown';

  static void d(String tag, String msg) => debugPrint('[$_prefix/$tag] $msg');
  static void w(String tag, String msg) =>
      debugPrint('[$_prefix/$tag] WARNING: $msg');
  static void e(String tag, String msg, [Object? error]) {
    debugPrint(
        '[$_prefix/$tag] ERROR: $msg${error != null ? ' ($error)' : ''}');
  }
}
```

- [ ] **Step 2: Replace `debugPrint` calls in `app_blocker_service.dart`**

Add import: `import '../utils/app_logger.dart';`

Remove import if no longer needed elsewhere: `package:flutter/foundation.dart` — but `app_blocker_service.dart` extends `ChangeNotifier` which requires `foundation.dart`, so keep it.

Replace all 8 `debugPrint(...)` calls with `AppLogger.e(...)`:
- Line 79: `debugPrint('Failed to check permissions: $e')` → `AppLogger.e('Blocker', 'Failed to check permissions', e)`
- Line 114: `debugPrint('Failed to schedule failsafe alarm: $e')` → `AppLogger.e('Blocker', 'Failed to schedule failsafe alarm', e)`
- Line 149: `debugPrint('Failed to cancel failsafe alarm: $e')` → `AppLogger.e('Blocker', 'Failed to cancel failsafe alarm', e)`
- Line 170: `debugPrint('Failsafe timer deactivation failed, lock restored: $e')` → `AppLogger.e('Blocker', 'Failsafe timer deactivation failed, lock restored', e)`
- Line 186: `debugPrint('Failed to update blocking state: $e')` → `AppLogger.e('Blocker', 'Failed to update blocking state', e)`
- Line 219: `debugPrint('Failed to update blocking state: $e')` → `AppLogger.e('Blocker', 'Failed to update blocking state', e)`
- Line 236: `debugPrint('Failed to load active locks: $e')` → `AppLogger.e('Blocker', 'Failed to load active locks', e)`
- Line 320: `debugPrint('Failed to prepare VPN: $e')` → `AppLogger.e('Blocker', 'Failed to prepare VPN', e)`

- [ ] **Step 3: Verify Flutter analysis passes**

Run: `flutter analyze lib/utils/app_logger.dart lib/services/app_blocker_service.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/utils/app_logger.dart lib/services/app_blocker_service.dart
git commit -m "refactor: replace debugPrint with AppLogger across Dart files"
```

---

### Task 4: Extract `AppBlockingDecider` and write tests

**Files:**
- Create: `android/app/src/main/kotlin/app/phonelockdown/AppBlockingDecider.kt`
- Create: `android/app/src/test/kotlin/app/phonelockdown/AppBlockingDeciderTest.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/LockdownAccessibilityService.kt`

- [ ] **Step 1: Write the test file `AppBlockingDeciderTest.kt`**

```kotlin
package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class AppBlockingDeciderTest {

    private val ownPackage = "app.phonelockdown"

    @Test
    fun `shouldBlock returns true for blocked package when active`() {
        assertTrue(
            AppBlockingDecider.shouldBlock("com.blocked.app", true, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for unblocked package when active`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.allowed.app", true, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for blocked package when inactive`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.blocked.app", false, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for own package`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("app.phonelockdown", true, setOf("app.phonelockdown"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for systemui`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.systemui", true, setOf("com.android.systemui"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for launcher`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.launcher", true, setOf("com.android.launcher"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for launcher3`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.launcher3", true, setOf("com.android.launcher3"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for nexuslauncher`() {
        assertFalse(
            AppBlockingDecider.shouldBlock(
                "com.google.android.apps.nexuslauncher", true,
                setOf("com.google.android.apps.nexuslauncher"), ownPackage
            )
        )
    }

    @Test
    fun `shouldBlock returns false for empty blocked set`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.some.app", true, emptySet(), ownPackage)
        )
    }

    @Test
    fun `isSystemPackage returns true for all system packages`() {
        val systemPkgs = listOf(
            "app.phonelockdown",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher"
        )
        for (pkg in systemPkgs) {
            assertTrue(AppBlockingDecider.isSystemPackage(pkg, ownPackage), "Expected $pkg to be system package")
        }
    }

    @Test
    fun `isSystemPackage returns false for regular apps`() {
        assertFalse(AppBlockingDecider.isSystemPackage("com.instagram.android", ownPackage))
        assertFalse(AppBlockingDecider.isSystemPackage("com.twitter.android", ownPackage))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.AppBlockingDeciderTest" 2>&1 | tail -10`
Expected: compilation error — `AppBlockingDecider` does not exist

- [ ] **Step 3: Create `AppBlockingDecider.kt`**

```kotlin
package app.phonelockdown

object AppBlockingDecider {

    private val SYSTEM_PACKAGES = setOf(
        "com.android.systemui",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher"
    )

    fun isSystemPackage(packageName: String, ownPackageName: String): Boolean {
        return packageName == ownPackageName || packageName in SYSTEM_PACKAGES
    }

    fun shouldBlock(
        packageName: String,
        isBlockingActive: Boolean,
        blockedPackages: Set<String>,
        ownPackageName: String
    ): Boolean {
        if (!isBlockingActive) return false
        if (isSystemPackage(packageName, ownPackageName)) return false
        return packageName in blockedPackages
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.AppBlockingDeciderTest" 2>&1 | tail -10`
Expected: all tests pass

- [ ] **Step 5: Wire `LockdownAccessibilityService` to delegate**

In `LockdownAccessibilityService.kt`, replace the `isSystemPackage` and `handleAppBlocking` methods:

Replace the `isSystemPackage` method (lines 59-65):
```kotlin
    private fun isSystemPackage(packageName: String): Boolean {
        return AppBlockingDecider.isSystemPackage(packageName, this.packageName)
    }
```

Replace the `handleAppBlocking` method (lines 67-75):
```kotlin
    private fun handleAppBlocking(packageName: String) {
        if (AppBlockingDecider.shouldBlock(packageName, isBlockingActive, blockedPackages, this.packageName)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(
                this,
                "This app is blocked by Phone Lockdown",
                Toast.LENGTH_SHORT
            ).show()
        }
    }
```

And update `onAccessibilityEvent` to remove the redundant `isBlockingActive` and `isSystemPackage` checks since `shouldBlock` handles both:

Replace lines 44-57:
```kotlin
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleAppBlocking(packageName)
            }
        }
    }
```

- [ ] **Step 6: Verify compilation and all tests pass**

Run: `cd android && ./gradlew compileDebugKotlin test 2>&1 | tail -10`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/AppBlockingDecider.kt \
       android/app/src/test/kotlin/app/phonelockdown/AppBlockingDeciderTest.kt \
       android/app/src/main/kotlin/app/phonelockdown/LockdownAccessibilityService.kt
git commit -m "feat: extract AppBlockingDecider with tests, wire into accessibility service"
```

---

### Task 5: Extract `ProfileDeactivator` and write tests

**Files:**
- Create: `android/app/src/main/kotlin/app/phonelockdown/ProfileDeactivator.kt`
- Create: `android/app/src/test/kotlin/app/phonelockdown/ProfileDeactivatorTest.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/FailsafeAlarmReceiver.kt`

- [ ] **Step 1: Write the test file `ProfileDeactivatorTest.kt`**

```kotlin
package app.phonelockdown

import org.json.JSONArray
import org.json.JSONObject
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class ProfileDeactivatorTest {

    private fun buildBlocksJson(vararg profiles: Triple<String, List<String>, List<String>>): String {
        val arr = JSONArray()
        for ((id, pkgs, webs) in profiles) {
            val obj = JSONObject()
            obj.put("profileId", id)
            obj.put("blockedPackages", JSONArray(pkgs))
            obj.put("blockedWebsites", JSONArray(webs))
            arr.put(obj)
        }
        return arr.toString()
    }

    private fun buildAlarmsJson(vararg profileIds: String): String {
        val arr = JSONArray()
        for (id in profileIds) {
            val obj = JSONObject()
            obj.put("profileId", id)
            obj.put("alarmTimeMillis", System.currentTimeMillis() + 60000)
            arr.put(obj)
        }
        return arr.toString()
    }

    @Test
    fun `single profile removed clears everything`() {
        val blocks = buildBlocksJson(Triple("p1", listOf("com.app.a"), listOf("example.com")))
        val alarms = buildAlarmsJson("p1")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p1")

        assertFalse(result.hasRemainingProfiles)
        assertTrue(result.mergedPackages.isEmpty())
        assertTrue(result.mergedWebsites.isEmpty())
        assertEquals(0, JSONArray(result.updatedBlocksJson).length())
        assertEquals(0, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `one of two profiles removed keeps remaining profile data`() {
        val blocks = buildBlocksJson(
            Triple("p1", listOf("com.app.a"), listOf("a.com")),
            Triple("p2", listOf("com.app.b"), listOf("b.com"))
        )
        val alarms = buildAlarmsJson("p1", "p2")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p1")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.b"), result.mergedPackages)
        assertEquals(setOf("b.com"), result.mergedWebsites)
        assertEquals(1, JSONArray(result.updatedBlocksJson).length())
        assertEquals(1, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `three profiles middle removed merges remaining two`() {
        val blocks = buildBlocksJson(
            Triple("p1", listOf("com.app.a"), listOf("a.com")),
            Triple("p2", listOf("com.app.b"), listOf("b.com")),
            Triple("p3", listOf("com.app.c"), listOf("c.com"))
        )
        val alarms = buildAlarmsJson("p1", "p2", "p3")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p2")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.a", "com.app.c"), result.mergedPackages)
        assertEquals(setOf("a.com", "c.com"), result.mergedWebsites)
        assertEquals(2, JSONArray(result.updatedBlocksJson).length())
        assertEquals(2, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `unknown profile id is a no-op`() {
        val blocks = buildBlocksJson(Triple("p1", listOf("com.app.a"), listOf("a.com")))
        val alarms = buildAlarmsJson("p1")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "unknown")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.a"), result.mergedPackages)
        assertEquals(setOf("a.com"), result.mergedWebsites)
    }

    @Test
    fun `empty alarms and blocks json is a no-op`() {
        val result = ProfileDeactivator.computeDeactivation("[]", "[]", "p1")

        assertFalse(result.hasRemainingProfiles)
        assertTrue(result.mergedPackages.isEmpty())
        assertTrue(result.mergedWebsites.isEmpty())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.ProfileDeactivatorTest" 2>&1 | tail -10`
Expected: compilation error — `ProfileDeactivator` does not exist

- [ ] **Step 3: Create `ProfileDeactivator.kt`**

```kotlin
package app.phonelockdown

import org.json.JSONArray

data class DeactivationResult(
    val updatedAlarmsJson: String,
    val updatedBlocksJson: String,
    val mergedPackages: Set<String>,
    val mergedWebsites: Set<String>,
    val hasRemainingProfiles: Boolean
)

object ProfileDeactivator {

    fun computeDeactivation(
        alarmsJson: String,
        blocksJson: String,
        profileId: String
    ): DeactivationResult {
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }

        val blocks = JSONArray(blocksJson)
        val updatedBlocks = JSONArray()
        val mergedPackages = mutableSetOf<String>()
        val mergedWebsites = mutableSetOf<String>()

        for (i in 0 until blocks.length()) {
            val obj = blocks.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedBlocks.put(obj)
                val pkgs = obj.getJSONArray("blockedPackages")
                for (j in 0 until pkgs.length()) {
                    mergedPackages.add(pkgs.getString(j))
                }
                val webs = obj.getJSONArray("blockedWebsites")
                for (j in 0 until webs.length()) {
                    mergedWebsites.add(webs.getString(j))
                }
            }
        }

        return DeactivationResult(
            updatedAlarmsJson = updatedAlarms.toString(),
            updatedBlocksJson = updatedBlocks.toString(),
            mergedPackages = mergedPackages,
            mergedWebsites = mergedWebsites,
            hasRemainingProfiles = updatedBlocks.length() > 0
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.ProfileDeactivatorTest" 2>&1 | tail -10`
Expected: all tests pass

- [ ] **Step 5: Wire `FailsafeAlarmReceiver.deactivateProfile` to delegate**

In `FailsafeAlarmReceiver.kt`, replace the body of `deactivateProfile()` (lines 25-91) with a call to `ProfileDeactivator.computeDeactivation()`:

```kotlin
        fun deactivateProfile(context: Context, profileId: String): Boolean {
            val prefs = PrefsHelper.getPrefs(context)

            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]") ?: "[]"
            val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]") ?: "[]"

            val result = ProfileDeactivator.computeDeactivation(alarmsJson, blocksJson, profileId)

            prefs.edit()
                .putBoolean(Constants.PREF_IS_BLOCKING, result.hasRemainingProfiles)
                .putStringSet(Constants.PREF_BLOCKED_PACKAGES, if (result.hasRemainingProfiles) result.mergedPackages else emptySet())
                .putStringSet(Constants.PREF_BLOCKED_WEBSITES, if (result.hasRemainingProfiles) result.mergedWebsites else emptySet())
                .putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, result.updatedBlocksJson)
                .putString(Constants.PREF_FAILSAFE_ALARMS, result.updatedAlarmsJson)
                .commit()

            LockdownAccessibilityService.isBlockingActive = result.hasRemainingProfiles
            LockdownAccessibilityService.blockedPackages = if (result.hasRemainingProfiles) result.mergedPackages else emptySet()
            LockdownAccessibilityService.blockedWebsites = if (result.hasRemainingProfiles) result.mergedWebsites else emptySet()

            if (!result.hasRemainingProfiles || result.mergedWebsites.isEmpty()) {
                try {
                    val vpnIntent = Intent(context, LockdownVpnService::class.java).apply {
                        action = "STOP"
                    }
                    context.startService(vpnIntent)
                } catch (e: Exception) {
                    AppLogger.e("Failsafe", "Failed to stop VPN service", e)
                }
            } else {
                LockdownVpnService.blockedWebsites = result.mergedWebsites
            }

            return result.hasRemainingProfiles
        }
```

Remove the `import org.json.JSONArray` line from `FailsafeAlarmReceiver.kt` since it's no longer needed there.

- [ ] **Step 6: Verify compilation and all tests pass**

Run: `cd android && ./gradlew compileDebugKotlin test 2>&1 | tail -10`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/ProfileDeactivator.kt \
       android/app/src/test/kotlin/app/phonelockdown/ProfileDeactivatorTest.kt \
       android/app/src/main/kotlin/app/phonelockdown/FailsafeAlarmReceiver.kt
git commit -m "feat: extract ProfileDeactivator with tests, wire into FailsafeAlarmReceiver"
```

---

### Task 6: Extract `VpnPacketHandler` with `DnsResolver` interface and write tests

**Files:**
- Create: `android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt`
- Create: `android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt`
- Modify: `android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt`

- [ ] **Step 1: Write the test file `VpnPacketHandlerTest.kt`**

```kotlin
package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream

class VpnPacketHandlerTest {

    private lateinit var output: ByteArrayOutputStream
    private lateinit var handler: VpnPacketHandler
    private var resolverCalled = false
    private var resolverResponse: ByteArray? = null

    private val fakeResolver = object : DnsResolver {
        override fun forward(dnsPayload: ByteArray): ByteArray? {
            resolverCalled = true
            return resolverResponse
        }
    }

    @BeforeEach
    fun setUp() {
        output = ByteArrayOutputStream()
        resolverCalled = false
        resolverResponse = null
        handler = VpnPacketHandler(
            blockedWebsites = { setOf("blocked.com") },
            dnsCache = DnsCache(),
            dnsResolver = fakeResolver
        )
    }

    /**
     * Builds a minimal IPv4/UDP/DNS query packet.
     * IP header (20 bytes) + UDP header (8 bytes) + DNS payload.
     */
    private fun buildDnsQueryPacket(domain: String, srcIp: ByteArray = byteArrayOf(10, 0, 0, 2),
                                     dstIp: ByteArray = byteArrayOf(8, 8, 8, 8),
                                     srcPort: Int = 12345, dstPort: Int = 53): ByteArray {
        val dnsPayload = buildDnsPayload(domain)
        val udpLength = 8 + dnsPayload.size
        val totalLength = 20 + udpLength

        val packet = ByteArray(totalLength)

        // IP header
        packet[0] = 0x45.toByte() // version=4, IHL=5 (20 bytes)
        packet[2] = ((totalLength shr 8) and 0xFF).toByte()
        packet[3] = (totalLength and 0xFF).toByte()
        packet[9] = 17.toByte() // UDP protocol
        // Source IP
        System.arraycopy(srcIp, 0, packet, 12, 4)
        // Dest IP
        System.arraycopy(dstIp, 0, packet, 16, 4)

        // UDP header
        val udpOffset = 20
        packet[udpOffset] = ((srcPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 1] = (srcPort and 0xFF).toByte()
        packet[udpOffset + 2] = ((dstPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 3] = (dstPort and 0xFF).toByte()
        packet[udpOffset + 4] = ((udpLength shr 8) and 0xFF).toByte()
        packet[udpOffset + 5] = (udpLength and 0xFF).toByte()

        // DNS payload
        System.arraycopy(dnsPayload, 0, packet, 28, dnsPayload.size)

        return packet
    }

    private fun buildDnsPayload(domain: String): ByteArray {
        val labels = domain.split(".")
        val qnameSize = labels.sumOf { 1 + it.length } + 1
        val payload = ByteArray(12 + qnameSize + 4) // header + qname + qtype + qclass

        // Transaction ID
        payload[0] = 0x12
        payload[1] = 0x34
        // Flags: standard query
        payload[2] = 0x01
        payload[3] = 0x00
        // QDCOUNT = 1
        payload[4] = 0x00
        payload[5] = 0x01

        var offset = 12
        for (label in labels) {
            payload[offset++] = label.length.toByte()
            for (ch in label) {
                payload[offset++] = ch.code.toByte()
            }
        }
        payload[offset++] = 0x00 // root label
        payload[offset++] = 0x00
        payload[offset++] = 0x01 // QTYPE = A
        payload[offset++] = 0x00
        payload[offset] = 0x01   // QCLASS = IN

        return payload
    }

    // --- Packet filtering tests ---

    @Test
    fun `packet shorter than 20 bytes is ignored`() {
        val short = ByteArray(10)
        handler.handlePacket(short, short.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-IPv4 packet is ignored`() {
        val packet = buildDnsQueryPacket("example.com")
        packet[0] = 0x65.toByte() // version=6
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-UDP packet is ignored`() {
        val packet = buildDnsQueryPacket("example.com")
        packet[9] = 6.toByte() // TCP
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-DNS port is ignored`() {
        val packet = buildDnsQueryPacket("example.com", dstPort = 80)
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    // --- Blocking tests ---

    @Test
    fun `blocked domain returns NXDOMAIN response`() {
        val packet = buildDnsQueryPacket("blocked.com")
        handler.handlePacket(packet, packet.size, output)

        assertTrue(output.size() > 0, "Expected NXDOMAIN response to be written")
        assertFalse(resolverCalled, "Resolver should not be called for blocked domains")

        // Verify DNS response has NXDOMAIN rcode
        val response = output.toByteArray()
        val dnsOffset = 28 // 20 IP + 8 UDP
        assertEquals(0x83.toByte(), response[dnsOffset + 3], "Expected NXDOMAIN rcode")
    }

    @Test
    fun `allowed domain forwards via resolver`() {
        val fakeDnsResponse = buildDnsPayload("allowed.com")
        fakeDnsResponse[2] = (fakeDnsResponse[2].toInt() or 0x80).toByte() // make it a response
        resolverResponse = fakeDnsResponse

        val packet = buildDnsQueryPacket("allowed.com")
        handler.handlePacket(packet, packet.size, output)

        assertTrue(resolverCalled, "Resolver should be called for allowed domains")
        assertTrue(output.size() > 0, "Expected forwarded response to be written")
    }

    @Test
    fun `allowed domain with null resolver response writes nothing`() {
        resolverResponse = null
        val packet = buildDnsQueryPacket("allowed.com")
        handler.handlePacket(packet, packet.size, output)

        assertTrue(resolverCalled)
        assertEquals(0, output.size(), "No response should be written when resolver returns null")
    }

    // --- Cache tests ---

    @Test
    fun `cached domain returns cached response without calling resolver`() {
        // Prime the cache
        val fakeDnsResponse = buildDnsPayload("cached.com")
        fakeDnsResponse[2] = (fakeDnsResponse[2].toInt() or 0x80).toByte()
        val cache = DnsCache()
        cache.put("cached.com", fakeDnsResponse, 300)

        handler = VpnPacketHandler(
            blockedWebsites = { emptySet() },
            dnsCache = cache,
            dnsResolver = fakeResolver
        )

        val packet = buildDnsQueryPacket("cached.com")
        handler.handlePacket(packet, packet.size, output)

        assertFalse(resolverCalled, "Resolver should not be called for cached domains")
        assertTrue(output.size() > 0, "Expected cached response to be written")
    }

    // --- buildIpUdpResponse tests ---

    @Test
    fun `buildIpUdpResponse swaps source and dest IP`() {
        val packet = buildDnsQueryPacket("example.com")
        val dnsResponse = ByteArray(4) { 0x42 }

        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)

        // Original: src=10.0.0.2, dst=8.8.8.8
        // Response: src=8.8.8.8, dst=10.0.0.2
        assertEquals(8, response[12].toInt() and 0xFF)
        assertEquals(8, response[13].toInt() and 0xFF)
        assertEquals(8, response[14].toInt() and 0xFF)
        assertEquals(8, response[15].toInt() and 0xFF)
        assertEquals(10, response[16].toInt() and 0xFF)
        assertEquals(0, response[17].toInt() and 0xFF)
        assertEquals(0, response[18].toInt() and 0xFF)
        assertEquals(2, response[19].toInt() and 0xFF)
    }

    @Test
    fun `buildIpUdpResponse swaps source and dest ports`() {
        val packet = buildDnsQueryPacket("example.com", srcPort = 12345, dstPort = 53)
        val dnsResponse = ByteArray(4) { 0x42 }

        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)

        // Source port should be 53 (original dest), dest should be 12345 (original src)
        val srcPort = ((response[20].toInt() and 0xFF) shl 8) or (response[21].toInt() and 0xFF)
        val dstPort = ((response[22].toInt() and 0xFF) shl 8) or (response[23].toInt() and 0xFF)
        assertEquals(53, srcPort)
        assertEquals(12345, dstPort)
    }

    @Test
    fun `buildIpUdpResponse has correct total length`() {
        val packet = buildDnsQueryPacket("example.com")
        val dnsResponse = ByteArray(20)

        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)

        assertEquals(20 + 8 + 20, response.size)
        val ipTotalLen = ((response[2].toInt() and 0xFF) shl 8) or (response[3].toInt() and 0xFF)
        assertEquals(response.size, ipTotalLen)
    }

    // --- calculateChecksum tests ---

    @Test
    fun `calculateChecksum produces valid checksum for even-length data`() {
        val data = byteArrayOf(0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
            0x40, 0x06, 0x00, 0x00, 0xac.toByte(), 0x10, 0x0a, 0x63,
            0xac.toByte(), 0x10, 0x0a, 0x0c)
        val checksum = handler.calculateChecksum(data, 0, data.size)
        // Apply checksum back and verify the whole header checksums to 0
        data[10] = ((checksum shr 8) and 0xFF).toByte()
        data[11] = (checksum and 0xFF).toByte()
        assertEquals(0, handler.calculateChecksum(data, 0, data.size))
    }

    @Test
    fun `calculateChecksum handles odd-length data`() {
        val data = byteArrayOf(0x01, 0x02, 0x03)
        // Should not throw, should produce a valid 16-bit result
        val checksum = handler.calculateChecksum(data, 0, data.size)
        assertTrue(checksum in 0..0xFFFF)
    }

    // --- Buffer optimization test ---

    @Test
    fun `handlePacket respects length parameter and ignores trailing buffer data`() {
        val packet = buildDnsQueryPacket("blocked.com")
        // Put the real packet at the start of a larger buffer (simulates reused 32KB buffer)
        val bigBuffer = ByteArray(32767)
        System.arraycopy(packet, 0, bigBuffer, 0, packet.size)

        handler.handlePacket(bigBuffer, packet.size, output)

        assertTrue(output.size() > 0, "Should handle packet using length param, not buffer size")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.VpnPacketHandlerTest" 2>&1 | tail -10`
Expected: compilation error — `VpnPacketHandler` and `DnsResolver` do not exist

- [ ] **Step 3: Create `VpnPacketHandler.kt`**

```kotlin
package app.phonelockdown

import java.io.OutputStream

interface DnsResolver {
    fun forward(dnsPayload: ByteArray): ByteArray?
}

class VpnPacketHandler(
    private val blockedWebsites: () -> Set<String>,
    private val dnsCache: DnsCache,
    private val dnsResolver: DnsResolver
) {
    companion object {
        private const val DNS_PORT = 53
    }

    fun handlePacket(packet: ByteArray, length: Int, outputStream: OutputStream) {
        // Minimum IP header is 20 bytes
        if (length < 20) return

        // Check IP version (should be 4)
        val version = (packet[0].toInt() shr 4) and 0xF
        if (version != 4) return

        val ipHeaderLength = (packet[0].toInt() and 0xF) * 4
        val protocol = packet[9].toInt() and 0xFF

        // Only handle UDP (protocol 17)
        if (protocol != 17) return

        // Check we have enough data for UDP header (8 bytes)
        if (length < ipHeaderLength + 8) return

        // Extract destination port from UDP header
        val destPort = ((packet[ipHeaderLength + 2].toInt() and 0xFF) shl 8) or
                (packet[ipHeaderLength + 3].toInt() and 0xFF)

        // Only handle DNS (port 53)
        if (destPort != DNS_PORT) return

        // Extract DNS payload
        val udpHeaderLength = 8
        val dnsOffset = ipHeaderLength + udpHeaderLength
        if (dnsOffset >= length) return

        val dnsPayload = packet.copyOfRange(dnsOffset, length)

        if (!DnsPacketParser.isQuery(dnsPayload)) return

        val domain = DnsPacketParser.extractDomainFromQuery(dnsPayload)
        if (domain != null && DomainMatcher.matches(domain, blockedWebsites())) {
            AppLogger.d("VPN", "Blocking DNS query for: $domain")
            val nxdomainDns = DnsPacketParser.buildNxdomainResponse(dnsPayload)
            val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, nxdomainDns)
            outputStream.write(responsePacket)
            outputStream.flush()
            return
        }

        // Check DNS cache before forwarding
        if (domain != null) {
            val cachedResponse = dnsCache.get(domain)
            if (cachedResponse != null) {
                cachedResponse[0] = dnsPayload[0]
                cachedResponse[1] = dnsPayload[1]
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, cachedResponse)
                outputStream.write(responsePacket)
                outputStream.flush()
                return
            }
        }

        // Forward non-blocked DNS queries to real DNS server
        try {
            val responseDns = dnsResolver.forward(dnsPayload)
            if (responseDns != null) {
                if (domain != null) {
                    val ttl = DnsPacketParser.extractTtl(responseDns)
                    dnsCache.put(domain, responseDns, ttl)
                }
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, responseDns)
                outputStream.write(responsePacket)
                outputStream.flush()
            }
        } catch (e: Exception) {
            AppLogger.e("VPN", "Error forwarding DNS query", e)
        }
    }

    fun buildIpUdpResponse(
        originalPacket: ByteArray,
        ipHeaderLength: Int,
        dnsResponse: ByteArray
    ): ByteArray {
        val udpHeaderLength = 8
        val totalLength = ipHeaderLength + udpHeaderLength + dnsResponse.size
        val response = ByteArray(totalLength)

        System.arraycopy(originalPacket, 0, response, 0, ipHeaderLength)

        response[2] = ((totalLength shr 8) and 0xFF).toByte()
        response[3] = (totalLength and 0xFF).toByte()

        for (i in 0 until 4) {
            val temp = response[12 + i]
            response[12 + i] = response[16 + i]
            response[16 + i] = temp
        }

        response[10] = 0
        response[11] = 0
        val ipChecksum = calculateChecksum(response, 0, ipHeaderLength)
        response[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        response[11] = (ipChecksum and 0xFF).toByte()

        val udpOffset = ipHeaderLength
        response[udpOffset] = originalPacket[udpOffset + 2]
        response[udpOffset + 1] = originalPacket[udpOffset + 3]
        response[udpOffset + 2] = originalPacket[udpOffset]
        response[udpOffset + 3] = originalPacket[udpOffset + 1]

        val udpLength = udpHeaderLength + dnsResponse.size
        response[udpOffset + 4] = ((udpLength shr 8) and 0xFF).toByte()
        response[udpOffset + 5] = (udpLength and 0xFF).toByte()

        response[udpOffset + 6] = 0
        response[udpOffset + 7] = 0

        System.arraycopy(dnsResponse, 0, response, udpOffset + udpHeaderLength, dnsResponse.size)

        return response
    }

    fun calculateChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        val end = offset + length

        while (i < end - 1) {
            sum += ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            i += 2
        }

        if (i < end) {
            sum += (data[i].toInt() and 0xFF) shl 8
        }

        while (sum shr 16 != 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }

        return sum.inv() and 0xFFFF
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd android && ./gradlew test --tests "app.phonelockdown.VpnPacketHandlerTest" 2>&1 | tail -10`
Expected: all tests pass

- [ ] **Step 5: Wire `LockdownVpnService` to delegate to `VpnPacketHandler`**

In `LockdownVpnService.kt`, make these changes:

1. Add `DnsResolver` implementation and `VpnPacketHandler` field. After the `dnsCache` field (line 43), add:

```kotlin
    private val packetHandler = VpnPacketHandler(
        blockedWebsites = { blockedWebsites },
        dnsCache = dnsCache,
        dnsResolver = object : DnsResolver {
            override fun forward(dnsPayload: ByteArray): ByteArray? = forwardDnsQuery(dnsPayload)
        }
    )
```

2. Replace `processPackets()` (lines 126-155) to remove `copyOf` and delegate:

```kotlin
    private fun processPackets() {
        val vpnFd = vpnInterface ?: return
        val inputStream = FileInputStream(vpnFd.fileDescriptor)
        val outputStream = FileOutputStream(vpnFd.fileDescriptor)
        val packet = ByteArray(MAX_PACKET_SIZE)

        while (isRunning) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) {
                    Thread.sleep(10)
                    continue
                }

                packetHandler.handlePacket(packet, length, outputStream)
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                if (isRunning) {
                    AppLogger.e("VPN", "Error processing packet", e)
                }
            }
        }

        try {
            inputStream.close()
            outputStream.close()
        } catch (_: Exception) {}
    }
```

3. Remove the old `handlePacket`, `buildIpUdpResponse`, and `calculateChecksum` methods (lines 157-342) from `LockdownVpnService`. These are now in `VpnPacketHandler`.

4. Remove unused imports: `java.nio.ByteBuffer` (line 18).

- [ ] **Step 6: Verify compilation and all tests pass**

Run: `cd android && ./gradlew compileDebugKotlin test 2>&1 | tail -10`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt \
       android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt \
       android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt
git commit -m "feat: extract VpnPacketHandler with DnsResolver interface, eliminate per-packet buffer copy"
```

---

### Task 7: Final verification — build, test, and deploy

**Files:** none (verification only)

- [ ] **Step 1: Run full Kotlin test suite**

Run: `cd android && ./gradlew test 2>&1 | tail -20`
Expected: all tests pass

- [ ] **Step 2: Run Flutter analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Build debug APK**

Run: `cd android && ./gradlew assembleDebug 2>&1 | tail -5`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Deploy to connected device (if available)**

Run: `adb devices` to check for connected devices. If a device is listed:
Run: `cd android && ./gradlew installDebug`
Expected: app installs successfully

- [ ] **Step 5: Push to GitHub**

```bash
git push origin main
```
