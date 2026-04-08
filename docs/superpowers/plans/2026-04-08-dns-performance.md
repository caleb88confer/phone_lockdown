# DNS Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate DNS resolution bottlenecks that cause NXDOMAIN errors and multi-second page load times when the VPN is active.

**Architecture:** Replace the single-threaded synchronous DNS forwarding pipeline with a reader thread + worker thread pool. DNS queries are dispatched to workers for concurrent processing. Each forwarding attempt races all 3 DNS servers in parallel and uses the first response. Failed queries return SERVFAIL instead of being silently dropped.

**Tech Stack:** Kotlin, Android VpnService, java.util.concurrent (ExecutorService, ExecutorCompletionService, CountDownLatch), JUnit 5

**Test command:** `cd android && ./gradlew testDebugUnitTest`

**Source root:** `android/app/src/main/kotlin/app/phonelockdown/`

**Test root:** `android/app/src/test/kotlin/app/phonelockdown/`

---

### Task 1: Add `buildServfailResponse` to DnsPacketParser

**Files:**
- Modify: `android/app/src/main/kotlin/app/phonelockdown/DnsPacketParser.kt:101`
- Test: `android/app/src/test/kotlin/app/phonelockdown/DnsPacketParserTest.kt`

- [ ] **Step 1: Write failing tests for `buildServfailResponse`**

Add these tests at the end of `DnsPacketParserTest.kt`:

```kotlin
@Test
fun `buildServfailResponse sets QR bit and SERVFAIL rcode`() {
    val query = buildDnsQuery("example.com")
    val response = DnsPacketParser.buildServfailResponse(query)
    assertEquals(0x81.toByte(), response[2])
    assertEquals(0x82.toByte(), response[3]) // RA=1, RCODE=2 (SERVFAIL)
}

@Test
fun `buildServfailResponse preserves transaction ID`() {
    val query = buildDnsQuery("example.com", transactionId = 0x5678)
    val response = DnsPacketParser.buildServfailResponse(query)
    assertEquals(0x56.toByte(), response[0])
    assertEquals(0x78.toByte(), response[1])
}

@Test
fun `buildServfailResponse sets QDCOUNT to 1 and answer counts to 0`() {
    val query = buildDnsQuery("example.com")
    val response = DnsPacketParser.buildServfailResponse(query)
    assertEquals(0x00.toByte(), response[4])
    assertEquals(0x01.toByte(), response[5])
    assertEquals(0x00.toByte(), response[6])
    assertEquals(0x00.toByte(), response[7])
    assertEquals(0x00.toByte(), response[8])
    assertEquals(0x00.toByte(), response[9])
    assertEquals(0x00.toByte(), response[10])
    assertEquals(0x00.toByte(), response[11])
}

@Test
fun `buildServfailResponse returns original packet if too short`() {
    val tooShort = ByteArray(6) { 0x42 }
    val response = DnsPacketParser.buildServfailResponse(tooShort)
    assertArrayEquals(tooShort, response)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.DnsPacketParserTest"`
Expected: Compilation failure — `buildServfailResponse` does not exist yet.

- [ ] **Step 3: Implement `buildServfailResponse`**

Add this method to `DnsPacketParser` in `DnsPacketParser.kt`, right after the `buildNxdomainResponse` method (after line 99):

```kotlin
/**
 * Builds a SERVFAIL response for the given DNS query packet.
 * Copies the transaction ID and question section, sets response flags with SERVFAIL rcode.
 * Tells the client "temporary failure, please retry" instead of a silent drop.
 */
fun buildServfailResponse(originalQuery: ByteArray): ByteArray {
    if (originalQuery.size < DNS_HEADER_SIZE) {
        return originalQuery
    }

    var offset = DNS_HEADER_SIZE
    while (offset < originalQuery.size) {
        val labelLen = originalQuery[offset].toInt() and 0xFF
        offset++
        if (labelLen == 0) break
        offset += labelLen
    }
    offset += 4 // QTYPE + QCLASS

    val responseSize = offset.coerceAtMost(originalQuery.size)
    val response = originalQuery.copyOf(responseSize)

    response[2] = 0x81.toByte()  // QR=1, Opcode=0, AA=0, TC=0, RD=1
    response[3] = 0x82.toByte()  // RA=1, Z=0, RCODE=2 (SERVFAIL)

    response[4] = 0; response[5] = 1   // QDCOUNT = 1
    response[6] = 0; response[7] = 0   // ANCOUNT = 0
    response[8] = 0; response[9] = 0   // NSCOUNT = 0
    response[10] = 0; response[11] = 0 // ARCOUNT = 0

    return response
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.DnsPacketParserTest"`
Expected: All tests pass, including the 4 new SERVFAIL tests.

- [ ] **Step 5: Also update the TTL floor constant**

In `DnsPacketParser.kt`, change line 101:

```kotlin
// Before:
private const val TTL_FLOOR = 30
// After:
private const val TTL_FLOOR = 60
```

- [ ] **Step 6: Update the TTL floor test**

In `DnsPacketParserTest.kt`, update the existing test:

```kotlin
// Before:
@Test
fun `extractTtl clamps low TTL to floor of 30`() {
    val response = buildDnsResponseWithTtl("example.com", 5)
    assertEquals(30, DnsPacketParser.extractTtl(response))
}

// After:
@Test
fun `extractTtl clamps low TTL to floor of 60`() {
    val response = buildDnsResponseWithTtl("example.com", 5)
    assertEquals(60, DnsPacketParser.extractTtl(response))
}
```

- [ ] **Step 7: Run all DnsPacketParser tests**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.DnsPacketParserTest"`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/DnsPacketParser.kt android/app/src/test/kotlin/app/phonelockdown/DnsPacketParserTest.kt
git commit -m "feat: add buildServfailResponse to DnsPacketParser, raise TTL floor to 60s"
```

---

### Task 2: Make DnsCache thread-safe and increase size

**Files:**
- Modify: `android/app/src/main/kotlin/app/phonelockdown/DnsCache.kt`
- Test: `android/app/src/test/kotlin/app/phonelockdown/DnsCacheTest.kt`

- [ ] **Step 1: Write a concurrency test**

Add this test to `DnsCacheTest.kt`:

```kotlin
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors

@Test
fun `concurrent get and put do not throw`() {
    val cache = DnsCache(maxSize = 64)
    val executor = Executors.newFixedThreadPool(8)
    val latch = CountDownLatch(800)

    for (i in 0 until 400) {
        executor.submit {
            try {
                cache.put("domain$i.com", byteArrayOf(i.toByte()), 60)
            } finally {
                latch.countDown()
            }
        }
        executor.submit {
            try {
                cache.get("domain$i.com")
            } finally {
                latch.countDown()
            }
        }
    }

    latch.await(5, java.util.concurrent.TimeUnit.SECONDS)
    executor.shutdown()
    // If we get here without ConcurrentModificationException, the test passes
}
```

- [ ] **Step 2: Run the test to see if it fails (it may or may not — concurrency bugs are non-deterministic)**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.DnsCacheTest"`
Expected: May pass or may throw `ConcurrentModificationException`. Either way, we need the synchronization.

- [ ] **Step 3: Add synchronization to DnsCache**

Replace the entire contents of `DnsCache.kt`:

```kotlin
package app.phonelockdown

/**
 * In-memory LRU cache for DNS responses.
 * Thread-safe: accessed from reader thread (get) and worker threads (put).
 */
class DnsCache(private val maxSize: Int = 512) {

    private data class CacheEntry(
        val responseBytes: ByteArray,
        val expiresAtMillis: Long
    )

    private val cache = object : LinkedHashMap<String, CacheEntry>(maxSize, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry>?): Boolean {
            return size > maxSize
        }
    }

    fun get(domain: String): ByteArray? {
        synchronized(cache) {
            val entry = cache[domain] ?: return null
            if (System.currentTimeMillis() >= entry.expiresAtMillis) {
                cache.remove(domain)
                return null
            }
            return entry.responseBytes.copyOf()
        }
    }

    fun put(domain: String, responseBytes: ByteArray, ttlSeconds: Int) {
        val expiresAt = System.currentTimeMillis() + (ttlSeconds * 1000L)
        synchronized(cache) {
            cache[domain] = CacheEntry(responseBytes.copyOf(), expiresAt)
        }
    }

    fun clear() {
        synchronized(cache) {
            cache.clear()
        }
    }
}
```

Key changes: default maxSize 256 → 512, `synchronized(cache)` on all methods.

- [ ] **Step 4: Run all DnsCache tests**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.DnsCacheTest"`
Expected: All tests pass, including the new concurrency test.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/DnsCache.kt android/app/src/test/kotlin/app/phonelockdown/DnsCacheTest.kt
git commit -m "feat: make DnsCache thread-safe and increase max size to 512"
```

---

### Task 3: Refactor VpnPacketHandler for async dispatch

**Files:**
- Modify: `android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt`
- Test: `android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt`

This is the core architectural change. `handlePacket` will no longer call `dnsResolver.forward()` inline. Instead, it returns a `PendingDnsQuery` data class when forwarding is needed, so the caller can dispatch it to a thread pool.

- [ ] **Step 1: Write tests for the new async dispatch behavior**

Replace the `allowed domain forwards via resolver` and `allowed domain with null resolver response writes nothing` tests in `VpnPacketHandlerTest.kt`, and add new tests:

```kotlin
@Test
fun `allowed domain returns PendingDnsQuery for async dispatch`() {
    val packet = buildDnsQueryPacket("allowed.com")
    val result = handler.handlePacket(packet, packet.size, output)
    assertNotNull(result, "Expected PendingDnsQuery for uncached allowed domain")
    assertEquals("allowed.com", result!!.domain)
    assertFalse(resolverCalled, "Resolver should NOT be called inline")
    assertEquals(0, output.size(), "No response should be written inline")
}

@Test
fun `blocked domain returns null (handled inline)`() {
    val packet = buildDnsQueryPacket("blocked.com")
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result, "Blocked domains are handled inline, no PendingDnsQuery")
    assertTrue(output.size() > 0, "NXDOMAIN response should be written inline")
}

@Test
fun `cached domain returns null (handled inline)`() {
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
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result, "Cached domains are handled inline, no PendingDnsQuery")
    assertTrue(output.size() > 0, "Cached response should be written inline")
}

@Test
fun `completePendingQuery writes response and caches it`() {
    val fakeDnsResponse = buildDnsPayload("example.com")
    fakeDnsResponse[2] = (fakeDnsResponse[2].toInt() or 0x80).toByte()
    resolverResponse = fakeDnsResponse

    val packet = buildDnsQueryPacket("example.com")
    val pending = handler.handlePacket(packet, packet.size, output)
    assertNotNull(pending)

    handler.completePendingQuery(pending!!, output)
    assertTrue(resolverCalled, "Resolver should be called during completePendingQuery")
    assertTrue(output.size() > 0, "Response should be written after completion")
}

@Test
fun `completePendingQuery sends SERVFAIL when resolver returns null`() {
    resolverResponse = null
    val packet = buildDnsQueryPacket("example.com")
    val pending = handler.handlePacket(packet, packet.size, output)
    assertNotNull(pending)

    handler.completePendingQuery(pending!!, output)
    assertTrue(resolverCalled)
    assertTrue(output.size() > 0, "SERVFAIL response should be written")
    val response = output.toByteArray()
    val dnsOffset = 28
    assertEquals(0x82.toByte(), response[dnsOffset + 3], "Expected SERVFAIL rcode")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.VpnPacketHandlerTest"`
Expected: Compilation failure — `PendingDnsQuery` and `completePendingQuery` don't exist, `handlePacket` return type is wrong.

- [ ] **Step 3: Implement the refactored VpnPacketHandler**

Replace the contents of `VpnPacketHandler.kt`:

```kotlin
package app.phonelockdown

import java.io.OutputStream

interface DnsResolver {
    fun forward(dnsPayload: ByteArray): ByteArray?
}

data class PendingDnsQuery(
    val domain: String?,
    val dnsPayload: ByteArray,
    val originalPacket: ByteArray,
    val ipHeaderLength: Int
)

class VpnPacketHandler(
    private val blockedWebsites: () -> Set<String>,
    private val dnsCache: DnsCache,
    private val dnsResolver: DnsResolver
) {
    companion object {
        private const val DNS_PORT = 53
    }

    /**
     * Processes a packet. Returns a PendingDnsQuery if the packet needs async DNS forwarding,
     * or null if it was handled inline (blocked, cached, or not a DNS query).
     */
    fun handlePacket(packet: ByteArray, length: Int, outputStream: OutputStream): PendingDnsQuery? {
        if (length < 20) return null
        val version = (packet[0].toInt() shr 4) and 0xF
        if (version != 4) return null
        val ipHeaderLength = (packet[0].toInt() and 0xF) * 4
        val protocol = packet[9].toInt() and 0xFF
        if (protocol != 17) return null
        if (length < ipHeaderLength + 8) return null
        val destPort = ((packet[ipHeaderLength + 2].toInt() and 0xFF) shl 8) or
                (packet[ipHeaderLength + 3].toInt() and 0xFF)
        if (destPort != DNS_PORT) return null
        val udpHeaderLength = 8
        val dnsOffset = ipHeaderLength + udpHeaderLength
        if (dnsOffset >= length) return null
        val dnsPayload = packet.copyOfRange(dnsOffset, length)
        if (!DnsPacketParser.isQuery(dnsPayload)) return null

        val domain = DnsPacketParser.extractDomainFromQuery(dnsPayload)

        // Blocked domains — handle inline with NXDOMAIN
        if (domain != null && DomainMatcher.matches(domain, blockedWebsites())) {
            AppLogger.d("VPN", "Blocking DNS query for: $domain")
            val nxdomainDns = DnsPacketParser.buildNxdomainResponse(dnsPayload)
            val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, nxdomainDns)
            outputStream.write(responsePacket)
            outputStream.flush()
            return null
        }

        // Cached domains — handle inline with cached response
        if (domain != null) {
            val cachedResponse = dnsCache.get(domain)
            if (cachedResponse != null) {
                cachedResponse[0] = dnsPayload[0]
                cachedResponse[1] = dnsPayload[1]
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, cachedResponse)
                outputStream.write(responsePacket)
                outputStream.flush()
                return null
            }
        }

        // Cache miss — return PendingDnsQuery for async dispatch
        return PendingDnsQuery(
            domain = domain,
            dnsPayload = dnsPayload,
            originalPacket = packet.copyOf(length),
            ipHeaderLength = ipHeaderLength
        )
    }

    /**
     * Completes a pending DNS query by forwarding to upstream servers,
     * caching the result, and writing the response. Called from worker threads.
     * The caller must synchronize on outputStream.
     */
    fun completePendingQuery(pending: PendingDnsQuery, outputStream: OutputStream) {
        try {
            val responseDns = dnsResolver.forward(pending.dnsPayload)
            if (responseDns != null) {
                if (pending.domain != null) {
                    val ttl = DnsPacketParser.extractTtl(responseDns)
                    dnsCache.put(pending.domain, responseDns, ttl)
                }
                val responsePacket = buildIpUdpResponse(pending.originalPacket, pending.ipHeaderLength, responseDns)
                outputStream.write(responsePacket)
                outputStream.flush()
            } else {
                // All servers failed — send SERVFAIL so client retries
                val servfailDns = DnsPacketParser.buildServfailResponse(pending.dnsPayload)
                val responsePacket = buildIpUdpResponse(pending.originalPacket, pending.ipHeaderLength, servfailDns)
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

- [ ] **Step 4: Update existing tests for new return type**

In `VpnPacketHandlerTest.kt`, remove these old tests (they're replaced by the new ones from Step 1):
- `allowed domain forwards via resolver`
- `allowed domain with null resolver response writes nothing`
- `cached domain returns cached response without calling resolver`

Update `blocked domain returns NXDOMAIN response` to also check the return value:

```kotlin
@Test
fun `blocked domain returns NXDOMAIN response`() {
    val packet = buildDnsQueryPacket("blocked.com")
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result, "Blocked domain should be handled inline")
    assertTrue(output.size() > 0, "Expected NXDOMAIN response to be written")
    assertFalse(resolverCalled, "Resolver should not be called for blocked domains")
    val response = output.toByteArray()
    val dnsOffset = 28
    assertEquals(0x83.toByte(), response[dnsOffset + 3], "Expected NXDOMAIN rcode")
}
```

Update tests that don't check return values to ignore the nullable return:

```kotlin
@Test
fun `packet shorter than 20 bytes is ignored`() {
    val short = ByteArray(10)
    val result = handler.handlePacket(short, short.size, output)
    assertNull(result)
    assertEquals(0, output.size())
}

@Test
fun `non-IPv4 packet is ignored`() {
    val packet = buildDnsQueryPacket("example.com")
    packet[0] = 0x65.toByte()
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result)
    assertEquals(0, output.size())
}

@Test
fun `non-UDP packet is ignored`() {
    val packet = buildDnsQueryPacket("example.com")
    packet[9] = 6.toByte()
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result)
    assertEquals(0, output.size())
}

@Test
fun `non-DNS port is ignored`() {
    val packet = buildDnsQueryPacket("example.com", dstPort = 80)
    val result = handler.handlePacket(packet, packet.size, output)
    assertNull(result)
    assertEquals(0, output.size())
}

@Test
fun `handlePacket respects length parameter and ignores trailing buffer data`() {
    val packet = buildDnsQueryPacket("blocked.com")
    val bigBuffer = ByteArray(32767)
    System.arraycopy(packet, 0, bigBuffer, 0, packet.size)
    val result = handler.handlePacket(bigBuffer, packet.size, output)
    assertNull(result, "Blocked domain handled inline")
    assertTrue(output.size() > 0, "Should handle packet using length param, not buffer size")
}
```

- [ ] **Step 5: Run all VpnPacketHandler tests**

Run: `cd android && ./gradlew testDebugUnitTest --tests "app.phonelockdown.VpnPacketHandlerTest"`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/VpnPacketHandler.kt android/app/src/test/kotlin/app/phonelockdown/VpnPacketHandlerTest.kt
git commit -m "feat: refactor VpnPacketHandler for async DNS dispatch with PendingDnsQuery"
```

---

### Task 4: Rewrite LockdownVpnService with thread pool and parallel DNS racing

**Files:**
- Modify: `android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt`

This task has no unit tests because `LockdownVpnService` depends on Android framework APIs (`VpnService`, `ParcelFileDescriptor`) that can't run in a JVM test. The logic we can test (packet handling, DNS parsing, caching) is already covered by Tasks 1-3.

- [ ] **Step 1: Replace LockdownVpnService with thread pool + parallel DNS racing**

Replace the contents of `LockdownVpnService.kt`:

```kotlin
package app.phonelockdown

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ExecutorCompletionService
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class LockdownVpnService : VpnService() {

    companion object {
        private const val CHANNEL_ID = "lockdown_vpn"
        private const val NOTIFICATION_ID = 1002
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val DNS_SERVER = "8.8.8.8"
        private const val DNS_SERVER_SECONDARY = "8.8.4.4"
        private val DNS_SERVERS = listOf("8.8.8.8", "8.8.4.4", "1.1.1.1")
        private const val DNS_TIMEOUT_MS = 1500
        private const val DNS_PORT = 53
        private const val MAX_PACKET_SIZE = 32767

        var instance: LockdownVpnService? = null
        @Volatile var blockedWebsites: Set<String> = emptySet()
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile
    private var isRunning = false
    private var processingThread: Thread? = null
    private var dnsExecutor: ExecutorService? = null
    private val dnsCache = DnsCache()
    private val packetHandler = VpnPacketHandler(
        blockedWebsites = { blockedWebsites },
        dnsCache = dnsCache,
        dnsResolver = object : DnsResolver {
            override fun forward(dnsPayload: ByteArray): ByteArray? = forwardDnsQuery(dnsPayload)
        }
    )

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        loadStateFromPrefs()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startVpn()

        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        stopVpn()
        instance = null
        super.onDestroy()
    }

    override fun onRevoke() {
        AppLogger.w("VPN", "VPN revoked by system (another VPN may have taken over)")
        stopVpn()
        super.onRevoke()
    }

    private fun startVpn() {
        if (isRunning) return

        try {
            val builder = Builder()
                .setSession("Phone Lockdown")
                .addAddress(VPN_ADDRESS, 32)
                .addRoute(DNS_SERVER, 32)
                .addRoute(DNS_SERVER_SECONDARY, 32)
                .addDnsServer(DNS_SERVER)
                .addDnsServer(DNS_SERVER_SECONDARY)
                .setBlocking(true)

            builder.addDisallowedApplication(packageName)

            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                AppLogger.e("VPN", "Failed to establish VPN interface")
                stopSelf()
                return
            }

            isRunning = true
            dnsExecutor = Executors.newFixedThreadPool(4) { r ->
                Thread(r, "VPN-DnsWorker").also { it.isDaemon = true }
            }
            processingThread = Thread(::processPackets, "VPN-PacketProcessor").also { it.start() }
            AppLogger.i("VPN", "VPN started, blocking ${blockedWebsites.size} websites")
        } catch (e: Exception) {
            AppLogger.e("VPN", "Failed to start VPN", e)
            stopSelf()
        }
    }

    private fun stopVpn() {
        isRunning = false

        dnsExecutor?.let { executor ->
            executor.shutdown()
            try {
                if (!executor.awaitTermination(2, TimeUnit.SECONDS)) {
                    executor.shutdownNow()
                }
            } catch (_: InterruptedException) {
                executor.shutdownNow()
            }
        }
        dnsExecutor = null

        dnsCache.clear()
        processingThread?.interrupt()
        processingThread = null

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            AppLogger.e("VPN", "Error closing VPN interface", e)
        }
        vpnInterface = null

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun processPackets() {
        val vpnFd = vpnInterface ?: return
        val inputStream = FileInputStream(vpnFd.fileDescriptor)
        val outputStream = FileOutputStream(vpnFd.fileDescriptor)
        val packet = ByteArray(MAX_PACKET_SIZE)
        val executor = dnsExecutor ?: return

        while (isRunning) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) continue

                val pending: PendingDnsQuery?
                synchronized(outputStream) {
                    pending = packetHandler.handlePacket(packet, length, outputStream)
                }
                if (pending != null) {
                    executor.submit {
                        synchronized(outputStream) {
                            packetHandler.completePendingQuery(pending, outputStream)
                        }
                    }
                }
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

    /**
     * Forwards a DNS query to all DNS servers in parallel, returning the first successful response.
     */
    private fun forwardDnsQuery(dnsPayload: ByteArray): ByteArray? {
        val raceExecutor = Executors.newFixedThreadPool(DNS_SERVERS.size)
        val completionService = ExecutorCompletionService<ByteArray?>(raceExecutor)

        try {
            for (server in DNS_SERVERS) {
                completionService.submit {
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

                        responseBuffer.copyOf(receivePacket.length)
                    } catch (e: Exception) {
                        AppLogger.w("VPN", "DNS racing to $server failed: ${e.message}")
                        null
                    } finally {
                        socket?.close()
                    }
                }
            }

            // Take results as they complete, return the first non-null
            for (i in DNS_SERVERS.indices) {
                try {
                    val future = completionService.poll(DNS_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)
                        ?: break // Timed out waiting for any result
                    val result = future.get()
                    if (result != null) return result
                } catch (e: Exception) {
                    // This server's result failed, try next
                }
            }

            AppLogger.e("VPN", "All DNS servers failed (parallel race)")
            return null
        } finally {
            raceExecutor.shutdownNow()
        }
    }

    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Website Blocking VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active when website blocking is enabled"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Phone Lockdown")
            .setContentText("Website blocking active — ${blockedWebsites.size} sites blocked")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
```

Key changes:
- `DNS_TIMEOUT_MS`: 3000 → 1500
- Added `dnsExecutor` (4-thread pool for dispatching `completePendingQuery`)
- `processPackets()`: removed 10ms sleep, dispatches `PendingDnsQuery` to thread pool with `synchronized(outputStream)`
- `forwardDnsQuery()`: races all 3 servers via `ExecutorCompletionService`, returns first non-null response
- `stopVpn()`: gracefully shuts down executor with 2s timeout

- [ ] **Step 2: Synchronize inline writes in processPackets**

Note: The `handlePacket` call for blocked/cached domains writes to `outputStream` from the reader thread, while `completePendingQuery` writes from worker threads. We need to synchronize the inline writes too. Update `processPackets`:

In the `processPackets` method, wrap the `handlePacket` call with the same lock:

```kotlin
val pending: PendingDnsQuery?
synchronized(outputStream) {
    pending = packetHandler.handlePacket(packet, length, outputStream)
}
if (pending != null) {
    executor.submit {
        synchronized(outputStream) {
            packetHandler.completePendingQuery(pending, outputStream)
        }
    }
}
```

(This is already incorporated in the full replacement above — just calling it out for clarity. If you used the full replacement in Step 1, update the `processPackets` method to wrap the `handlePacket` call in `synchronized(outputStream)` as shown.)

- [ ] **Step 3: Run all unit tests to verify nothing is broken**

Run: `cd android && ./gradlew testDebugUnitTest`
Expected: All tests pass. (LockdownVpnService has no unit tests — it'll be verified on-device.)

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/app/phonelockdown/LockdownVpnService.kt
git commit -m "feat: add thread pool with parallel DNS racing to LockdownVpnService"
```

---

### Task 5: Run full test suite and build

- [ ] **Step 1: Run the full test suite**

Run: `cd android && ./gradlew testDebugUnitTest`
Expected: All tests pass.

- [ ] **Step 2: Build the app**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: If an Android device is connected, install**

Run: `adb devices` to check, then: `cd android && ./gradlew installDebug`

- [ ] **Step 4: Push to GitHub**

```bash
git push
```

- [ ] **Step 5: Final commit (if any fixups were needed)**

If any test or build issues required fixes, commit them:

```bash
git add -A
git commit -m "fix: address test/build issues from DNS performance optimization"
git push
```
