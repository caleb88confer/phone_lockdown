# Critical Bugfixes: Thread Safety & DNS Failover

**Date**: 2026-04-07
**Status**: Approved
**Scope**: Phase 1 (runtime bugs), Phase 2 (hardening)

---

## Problem Statement

Four critical issues were identified in the phone lockdown app:

1. **Thread safety race condition** — `blockedWebsites` in `LockdownVpnService.kt` is a mutable `Set<String>` written by the main thread and read by the VPN packet-processing thread with no synchronization.
2. **Hardcoded DNS with no failover** — DNS queries are forwarded exclusively to `8.8.8.8`. If unreachable, all DNS resolution breaks while the VPN is active.
3. **Zero test coverage** — Only a single boilerplate Flutter widget test exists. No tests for blocking logic, DNS parsing, profile management, or failsafe timers.
4. **No data encryption** — Unlock codes, blocked app lists, and profile data are stored as plain text in SharedPreferences.

Issues are prioritized by risk: #1 and #2 are runtime bugs that can actively break the app. #3 and #4 are hardening improvements.

---

## Phase 1: Runtime Bug Fixes

### Fix 1: Thread Safety in VPN Service

**File**: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt`

**Change**: Add `@Volatile` annotation to `blockedWebsites` in the companion object.

```kotlin
// Before
var blockedWebsites: Set<String> = emptySet()

// After
@Volatile var blockedWebsites: Set<String> = emptySet()
```

**Rationale**: `MainActivity.updateBlockingState()` already replaces the entire set reference (never mutates in place). The VPN processing thread only reads the reference. `@Volatile` guarantees the processing thread sees the latest assignment. Kotlin's `emptySet()`/`setOf()` return immutable sets, so the reader always gets a consistent snapshot.

No other changes are needed — the existing read/write pattern is already copy-on-write, it was just missing the visibility guarantee.

### Fix 2: DNS Failover

**File**: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt`

**Change**: Modify `forwardDnsQuery()` to try multiple DNS servers in sequence.

**DNS server list** (companion object constant, priority order):
1. `8.8.8.8` (Google primary)
2. `8.8.4.4` (Google secondary)
3. `1.1.1.1` (Cloudflare)

**Behavior**:
- Try each server with a 3-second socket timeout (reduced from current 5s since retries provide additional resilience).
- On `SocketTimeoutException` or `IOException`, move to the next server.
- If all servers fail, return `null` (same as current failure behavior — the query is silently dropped, the client will retry).
- No state tracking between calls — each invocation starts from the top of the list. This keeps the implementation stateless and simple.

**Scope**: Only the `forwardDnsQuery()` method changes. The DNS server list is a companion object constant. No new classes, no UI changes, no new dependencies.

---

## Phase 2: Hardening (Follow-up)

### Test Coverage

Target the critical paths that could lock users out of their phone.

**Kotlin unit tests**:
- `DnsPacketParser`: query detection, domain extraction from valid/malformed packets, NXDOMAIN response building
- `DomainMatcher`: exact match, subdomain match, non-match, edge cases (empty input, trailing dots)
- `forwardDnsQuery` failover logic: verify fallback behavior when primary DNS fails

**Dart unit tests**:
- `AppBlockerService`: activate/deactivate profiles, merged block list computation (union of multiple profiles), failsafe timer expiry and auto-deactivation, state persistence and restoration from SharedPreferences
- `ProfileManager`: CRUD operations, legacy unlock code migration, JSON encoding/decoding round-trip

**Out of scope for this phase**: Integration tests, UI tests, and Android service tests that require device/emulator context. Unit tests on pure logic provide the most coverage for the least effort.

### Data Encryption

Encrypt sensitive SharedPreferences values using Android's `EncryptedSharedPreferences` (from `androidx.security.crypto`).

**What changes**:
- Replace `getSharedPreferences("lockdown_prefs", ...)` with `EncryptedSharedPreferences.create(...)` using AES-256-SIV for keys and AES-256-GCM for values.
- One-time migration: on first launch after update, read existing plain-text prefs, write to new encrypted prefs, delete the plain-text file.
- A `prefsMigrated` flag in the encrypted prefs prevents re-running the migration.
- On the Flutter side, profile data (including unlock codes) is stored through the same encrypted prefs via the platform channel.

**What doesn't change**: The SharedPreferences API surface remains identical — all reads/writes use the same keys and types. Only the underlying storage is encrypted.

---

## Files Modified

| Phase | File | Change |
|-------|------|--------|
| 1 | `LockdownVpnService.kt` | Add `@Volatile` to `blockedWebsites` |
| 1 | `LockdownVpnService.kt` | Refactor `forwardDnsQuery()` for DNS failover |
| 2 | `android/app/src/test/` (new) | Kotlin unit tests for DNS parser, domain matcher |
| 2 | `test/` (new files) | Dart unit tests for AppBlockerService, ProfileManager |
| 2 | `MainActivity.kt` | Switch to EncryptedSharedPreferences + migration |
| 2 | `LockdownVpnService.kt` | Use encrypted prefs in `loadStateFromPrefs()` |
| 2 | `LockdownAccessibilityService.kt` | Use encrypted prefs |
| 2 | `FailsafeAlarmReceiver.kt` | Use encrypted prefs |
| 2 | `ServiceMonitorWorker.kt` | Use encrypted prefs |
| 2 | `build.gradle` | Add `androidx.security:security-crypto` dependency |
