# Phase 1: Runtime Bug Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two runtime bugs in `LockdownVpnService.kt` — a thread safety race condition on `blockedWebsites` and hardcoded DNS with no failover.

**Architecture:** Both fixes are contained to a single file (`LockdownVpnService.kt`). Fix 1 adds `@Volatile` to the companion object field. Fix 2 refactors `forwardDnsQuery()` to iterate a list of DNS servers with timeout-based failover.

**Tech Stack:** Kotlin, Android VPN API, Java NIO/DatagramSocket

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:34` | Add `@Volatile` to `blockedWebsites` |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:22-35` | Add `DNS_SERVERS` list constant |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:212-235` | Refactor `forwardDnsQuery()` for failover |

---

### Task 1: Fix Thread Safety on `blockedWebsites`

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:34`

- [ ] **Step 1: Add `@Volatile` annotation**

In `LockdownVpnService.kt`, change line 34 in the companion object from:

```kotlin
        var blockedWebsites: Set<String> = emptySet()
```

to:

```kotlin
        @Volatile var blockedWebsites: Set<String> = emptySet()
```

This ensures the VPN packet-processing thread always sees the latest set reference written by the main thread.

- [ ] **Step 2: Verify the project builds**

Run:
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt
git commit -m "fix: add @Volatile to blockedWebsites for thread safety

The blockedWebsites set is written by the main thread (via MainActivity)
and read by the VPN packet-processing thread. Without @Volatile, the
processing thread may never see updates due to CPU caching."
```

---

### Task 2: DNS Failover in `forwardDnsQuery()`

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:22-35` (companion object constants)
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:212-235` (forwardDnsQuery method)

- [ ] **Step 1: Add DNS_SERVERS list to companion object**

In the companion object (after the existing `DNS_SERVER_SECONDARY` constant on line 29), add a list constant. Replace the two individual DNS server constants with a single list:

Replace:
```kotlin
        private const val DNS_SERVER = "8.8.8.8"
        private const val DNS_SERVER_SECONDARY = "8.8.4.4"
```

With:
```kotlin
        private const val DNS_SERVER = "8.8.8.8"
        private const val DNS_SERVER_SECONDARY = "8.8.4.4"
        private val DNS_SERVERS = listOf("8.8.8.8", "8.8.4.4", "1.1.1.1")
        private const val DNS_TIMEOUT_MS = 3000
```

The original `DNS_SERVER` and `DNS_SERVER_SECONDARY` constants are kept because they are still referenced by the VPN builder in `startVpn()` (lines 80-83).

- [ ] **Step 2: Refactor `forwardDnsQuery()` to iterate DNS servers**

Replace the entire `forwardDnsQuery` method (lines 209-235) with:

```kotlin
    /**
     * Forwards a DNS query to real DNS servers with failover.
     * Tries each server in DNS_SERVERS sequentially; moves to the next on timeout or error.
     */
    private fun forwardDnsQuery(dnsPayload: ByteArray): ByteArray? {
        for (server in DNS_SERVERS) {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket)

                val dnsServer = InetAddress.getByName(server)
                val sendPacket = DatagramPacket(dnsPayload, dnsPayload.size, dnsServer, DNS_PORT)
                socket.soTimeout = DNS_TIMEOUT_MS
                socket.send(sendPacket)

                val responseBuffer = ByteArray(MAX_PACKET_SIZE)
                val receivePacket = DatagramPacket(responseBuffer, responseBuffer.size)
                socket.receive(receivePacket)

                return responseBuffer.copyOf(receivePacket.length)
            } catch (e: Exception) {
                Log.w(TAG, "DNS forwarding to $server failed: ${e.message}")
            } finally {
                socket?.close()
            }
        }
        Log.e(TAG, "All DNS servers failed")
        return null
    }
```

Key changes from the original:
- Iterates `DNS_SERVERS` instead of hitting only `8.8.8.8`
- Timeout reduced from 5000ms to 3000ms (3 retries provides more total resilience)
- On exception, logs a warning and tries the next server
- Only returns `null` if all servers fail
- Each iteration gets a fresh socket (old socket is closed in `finally`)

- [ ] **Step 3: Verify the project builds**

Run:
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt
git commit -m "fix: add DNS failover with multiple servers

forwardDnsQuery() now tries 8.8.8.8, 8.8.4.4, and 1.1.1.1 in sequence.
On timeout or IOException, it falls through to the next server. Timeout
reduced from 5s to 3s per server since retries provide resilience."
```

---

### Task 3: Deploy and Verify

- [ ] **Step 1: Build and install on connected device**

Run:
```bash
cd android && ./gradlew installDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL` and `Installed on 1 device`

- [ ] **Step 2: Push to GitHub**

Run:
```bash
git push
```
