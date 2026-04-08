# Nice-to-Have Improvements Design Spec

**Date:** 2026-04-08
**Scope:** Test coverage on enforcement paths, packet buffer optimization, centralized logging

---

## 1. Test Coverage on Enforcement Paths

### Goal

Extract testable logic from three Android services into pure Kotlin classes and write JUnit 5 unit tests. Services become thin wrappers that delegate to extracted logic.

### Extractions

#### 1a. `VpnPacketHandler` (from `LockdownVpnService`)

Extracted methods:
- `handlePacket(packet: ByteArray, length: Int, outputStream: OutputStream)` — main packet routing logic
- `buildIpUdpResponse(originalPacket, ipHeaderLength, dnsResponse): ByteArray` — IP+UDP response construction
- `calculateChecksum(data, offset, length): Int` — IP header checksum

Constructor params:
- `blockedWebsites: () -> Set<String>` — lambda to read current blocked set
- `dnsCache: DnsCache` — existing cache instance
- `dnsResolver: DnsResolver` — interface for DNS forwarding (allows test injection)

`DnsResolver` interface:
```kotlin
interface DnsResolver {
    fun forward(dnsPayload: ByteArray): ByteArray?
}
```

`LockdownVpnService` implements `DnsResolver` using the existing `forwardDnsQuery` method and `protect(socket)` call. In tests, a fake resolver returns canned responses.

#### 1b. `AppBlockingDecider` (from `LockdownAccessibilityService`)

Extracted pure functions:
- `shouldBlock(packageName: String, isBlockingActive: Boolean, blockedPackages: Set<String>): Boolean`
- `isSystemPackage(packageName: String, ownPackageName: String): Boolean`

No constructor params — stateless utility. `LockdownAccessibilityService.handleAppBlocking()` and `isSystemPackage()` delegate to these.

#### 1c. `ProfileDeactivator` (from `FailsafeAlarmReceiver.deactivateProfile`)

Extracted data class for results:
```kotlin
data class DeactivationResult(
    val updatedAlarmsJson: String,
    val updatedBlocksJson: String,
    val mergedPackages: Set<String>,
    val mergedWebsites: Set<String>,
    val hasRemainingProfiles: Boolean
)
```

Extracted function:
- `computeDeactivation(alarmsJson: String, blocksJson: String, profileId: String): DeactivationResult`

Pure JSON-in, data-out transformation. `FailsafeAlarmReceiver.deactivateProfile()` calls this, then applies the result to SharedPreferences and services.

### Test Targets

**VpnPacketHandler tests:**
- Blocked domain query → NXDOMAIN response written to output
- Allowed domain query → `DnsResolver.forward()` called, response written
- Cached domain → cache hit returned, resolver not called
- Packet too short (< 20 bytes) → ignored
- Non-IPv4 packet → ignored
- Non-UDP packet → ignored
- Non-DNS port → ignored
- `buildIpUdpResponse` → source/dest IP swapped, source/dest port swapped, checksum valid, DNS payload placed correctly
- `calculateChecksum` → known-good vectors (even-length, odd-length)

**AppBlockingDecider tests:**
- Blocked package + active → `true`
- Unblocked package + active → `false`
- Blocked package + inactive → `false`
- System packages (systemui, launcher, launcher3, nexuslauncher, own package) → `false` regardless
- Non-system, non-blocked package → `false`

**ProfileDeactivator tests:**
- Single active profile removed → empty merged sets, `hasRemainingProfiles = false`
- One of two profiles removed → remaining profile's packages/websites in merged sets
- Three profiles, middle removed → other two profiles' packages/websites merged correctly
- Profile ID not found → no-op, original data unchanged
- Empty alarms/blocks JSON → no-op

### File Locations

- `android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt`
- `android/app/src/main/kotlin/app/phonelockdown/AppBlockingDecider.kt`
- `android/app/src/main/kotlin/app/phonelockdown/ProfileDeactivator.kt`
- `android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt`
- `android/app/src/test/kotlin/app/phonelockdown/AppBlockingDeciderTest.kt`
- `android/app/src/test/kotlin/app/phonelockdown/ProfileDeactivatorTest.kt`

---

## 2. Packet Buffer Optimization

### Goal

Eliminate per-packet `copyOf(length)` allocation in `LockdownVpnService.processPackets()`.

### Change

Since `handlePacket` is moving to `VpnPacketHandler`, the new signature takes the raw buffer and a length parameter:

```kotlin
fun handlePacket(packet: ByteArray, length: Int, outputStream: OutputStream)
```

Internal reads use `length` as the bound instead of `packet.size`. The 32KB read buffer in `processPackets()` is reused across iterations — no per-packet allocation.

Sub-slices (DNS payload extraction) continue to use `copyOfRange` since they need independent arrays for forwarding and caching.

### What doesn't change

- The 32KB `MAX_PACKET_SIZE` read buffer allocation (once per thread lifetime)
- `forwardDnsQuery` response buffer allocation (one per DNS forward, necessary for `DatagramPacket`)
- DNS cache storage (needs independent copies)

---

## 3. Centralized Local Logging

### Goal

Replace scattered `debugPrint` (Dart) and `Log.e/w/d/i` (Kotlin) with consistent, tagged loggers on each side.

### Kotlin: `AppLogger` singleton

```kotlin
object AppLogger {
    private const val PREFIX = "PhoneLockdown"

    fun d(tag: String, msg: String) = Log.d("$PREFIX/$tag", msg)
    fun i(tag: String, msg: String) = Log.i("$PREFIX/$tag", msg)
    fun w(tag: String, msg: String) = Log.w("$PREFIX/$tag", msg)
    fun e(tag: String, msg: String, t: Throwable? = null) = Log.e("$PREFIX/$tag", msg, t)
}
```

Output example: `PhoneLockdown/VPN: Blocking DNS query for example.com`

Location: `android/app/src/main/kotlin/app/phonelockdown/AppLogger.kt`

Replacement scope (~15 calls):
- `LockdownVpnService.kt` — all `Log.x(TAG, ...)` calls
- `FailsafeAlarmReceiver.kt` — `Log.d`, `Log.e` calls
- `BlockingStateManager.kt` — any `Log` calls
- `VpnController.kt` — any `Log` calls
- New extracted classes (`VpnPacketHandler`, `ProfileDeactivator`) use `AppLogger` from the start

### Dart: `AppLogger` class

```dart
class AppLogger {
  static const _prefix = 'PhoneLockdown';

  static void d(String tag, String msg) => debugPrint('[$_prefix/$tag] $msg');
  static void w(String tag, String msg) => debugPrint('[$_prefix/$tag] WARNING: $msg');
  static void e(String tag, String msg, [Object? error]) {
    debugPrint('[$_prefix/$tag] ERROR: $msg${error != null ? ' ($error)' : ''}');
  }
}
```

Location: `lib/utils/app_logger.dart`

Replacement scope (~12 calls):
- `app_blocker_service.dart` — all `debugPrint` calls
- `platform_channel_service.dart` — any `debugPrint` calls
- `profile_manager.dart` — any `debugPrint` calls

### What this doesn't include

- No log persistence to disk
- No remote crash reporting
- No runtime log level filtering
- No log rotation or size management
