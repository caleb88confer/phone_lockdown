# DNS Performance Optimization Design

## Problem

When the phone lockdown VPN is active, DNS resolution is so slow that websites fail to load, showing `DNS_PROBE_FINISHED_NXDOMAIN` errors. Pages eventually load on retry, but the experience is unusable.

## Root Cause

The current DNS pipeline is single-threaded and fully synchronous. Every DNS query from every app on the phone flows through one thread that reads from the TUN device, parses the packet, checks the block list, checks the cache, and — on a cache miss — forwards to a real DNS server and waits for the response before processing the next query.

Key bottlenecks:
1. **Head-of-line blocking** — one slow DNS query stalls all others.
2. **Sequential server failover** — tries 8.8.8.8, then 8.8.4.4, then 1.1.1.1, each with a 3s timeout. Worst case: 9 seconds for a single query while everything else waits.
3. **Socket-per-query** — creates and destroys a `DatagramSocket` for every DNS forward.
4. **Silent query drops** — if all servers fail, the query is dropped with no response. The client app sees this as NXDOMAIN.
5. **Unnecessary 10ms sleep** — on empty TUN reads, despite blocking I/O mode.

## Solution: Concurrent DNS Forwarding with Parallel Server Racing

### Architecture Overview

Split the single-threaded pipeline into a reader + worker pool:

```
TUN device
    |
    v
Reader thread (VPN-PacketProcessor)
    |-- parse IPv4/UDP/DNS
    |-- check block list → NXDOMAIN response (fast, inline)
    |-- check DNS cache → cached response (fast, inline)
    |-- cache miss → dispatch to thread pool
    |
    v
Thread pool (4-6 fixed threads)
    |-- race query to all 3 DNS servers simultaneously
    |-- use first valid response, cancel rest
    |-- cache response
    |-- write response to TUN (synchronized)
```

### Component Changes

#### 1. LockdownVpnService — Thread Pool & Parallel DNS Racing

**Thread pool:**
- `ExecutorService` with 4 fixed threads (DNS queries are I/O-bound; 4 threads comfortably handle burst traffic from page loads generating 5-15 simultaneous queries).
- Created in `startVpn()`, shut down with 2-second timeout in `stopVpn()`.

**Parallel DNS forwarding (`forwardDnsQuery`):**
- Send the same query to all 3 DNS servers (8.8.8.8, 8.8.4.4, 1.1.1.1) simultaneously using `ExecutorCompletionService` or coroutine racing.
- Return the first successful response.
- Cancel remaining in-flight requests.
- Total timeout: 1.5 seconds (since we're racing, we get the latency of the fastest server, not the sum).
- Each server query uses its own `DatagramSocket`, protected via `VpnService.protect()`.

**Constants changed:**
- `DNS_TIMEOUT_MS`: 3000 → 1500
- Remove `DNS_SERVERS` sequential iteration pattern.

#### 2. VpnPacketHandler — Async Dispatch

**Current:** `handlePacket()` calls `dnsResolver.forward()` synchronously and writes the response inline.

**New:** On cache miss, `handlePacket()` returns without writing a response. Instead, the caller (reader thread) submits a task to the thread pool that:
1. Calls `dnsResolver.forward(dnsPayload)`
2. Caches the response via `dnsCache.put(domain, response)`
3. Builds the IP/UDP response packet
4. Writes to the output stream under a synchronized lock

The `DnsResolver` interface stays the same. The change is in how/where it's called.

**Output stream synchronization:** Worker threads share the TUN output stream. Writes are guarded by `synchronized(outputStream) { write(); flush() }`.

#### 3. DnsCache — Thread Safety & Tuning

**Thread safety:** Add `synchronized` blocks around `get()` and `put()`. The cache is a `LinkedHashMap` which is not thread-safe. Access pattern: reader thread calls `get()`, worker threads call `put()`. Simple synchronization is sufficient — DNS cache operations are microsecond-fast and won't cause contention.

**Tuning:**
- Max size: 256 → 512 entries. Each entry is ~200-500 bytes; 512 entries is well under 1MB.
- TTL floor: 30s → 60s. Reduces cache miss rate for popular domains without serving overly stale records.
- TTL cap: 300s (unchanged).

#### 4. DnsPacketParser — SERVFAIL Response

Add `buildServfailResponse(originalQuery: ByteArray): ByteArray` method:
- Copies the original query's transaction ID and question section.
- Sets QR=1 (response), RA=1 (recursion available), RCODE=2 (SERVFAIL).
- This tells the client "temporary failure, please retry" instead of silent drop or NXDOMAIN.

Structure mirrors the existing `buildNxdomainResponse()` — same pattern, different RCODE byte.

#### 5. Packet Processing Loop — Remove Sleep

In `processPackets()`, remove the `Thread.sleep(10)` on `length <= 0`. The TUN file descriptor is in blocking mode (`setBlocking(true)`), so `read()` already blocks until data arrives. The sleep adds 10ms latency to every idle cycle for no benefit.

#### 6. Lifecycle — Graceful Shutdown

In `stopVpn()`:
1. Set `isRunning = false`
2. Shut down thread pool with `executor.shutdown()` + `executor.awaitTermination(2, TimeUnit.SECONDS)` + `executor.shutdownNow()` if still running
3. Clear DNS cache
4. Interrupt reader thread
5. Close TUN file descriptor

### Files Modified

| File | Changes |
|------|---------|
| `LockdownVpnService.kt` | Add `ExecutorService`, rewrite `forwardDnsQuery` for parallel racing, update `startVpn`/`stopVpn` lifecycle, remove sleep |
| `VpnPacketHandler.kt` | Accept executor + output lock, dispatch cache-miss queries to thread pool instead of blocking inline |
| `DnsCache.kt` | Add `synchronized` to `get`/`put`, increase max size to 512, increase TTL floor to 60s |
| `DnsPacketParser.kt` | Add `buildServfailResponse()` method |

### What Doesn't Change

- Packet parsing logic (IPv4 header, UDP extraction, DNS question parsing)
- Block list checking (`DomainMatcher.matches()`)
- NXDOMAIN response for blocked domains
- VPN builder configuration (routes, addresses, disallowed apps)
- IP/UDP response packet construction (`buildIpUdpResponse`)
- App blocking via `LockdownAccessibilityService`
- `DnsResolver` interface contract

### Expected Impact

| Metric | Before | After |
|--------|--------|-------|
| DNS latency (happy path) | ~50ms + head-of-line wait | ~50ms (no waiting) |
| DNS latency (one server slow) | 3s + remaining servers | ~50ms (fastest server wins) |
| DNS latency (all servers slow) | up to 9s, then silent drop | 1.5s, then SERVFAIL + client retry |
| Concurrent query handling | 1 at a time | Up to 4 simultaneously |
| Cache effectiveness | 256 entries, 30s floor | 512 entries, 60s floor |

### Risks & Mitigations

- **Thread safety bugs:** Mitigated by keeping shared mutable state minimal (cache with synchronized, output stream with synchronized). Block list is read-only. Packet parsing is stateless.
- **Battery/memory:** Thread pool is small (4 threads) and threads are idle when no DNS queries are pending. Memory overhead is negligible.
- **Socket exhaustion:** Each parallel race opens 3 sockets briefly. At 4 concurrent queries max, that's 12 sockets — well within Android limits.
