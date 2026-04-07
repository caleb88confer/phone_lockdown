package app.phonelockdown

/**
 * In-memory LRU cache for DNS responses.
 * Thread safety: only accessed from the VPN-PacketProcessor thread.
 */
class DnsCache(private val maxSize: Int = 256) {

    private data class CacheEntry(
        val responseBytes: ByteArray,
        val expiresAtMillis: Long
    )

    // LinkedHashMap with accessOrder=true gives LRU eviction behavior
    private val cache = object : LinkedHashMap<String, CacheEntry>(maxSize, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry>?): Boolean {
            return size > maxSize
        }
    }

    /**
     * Returns a copy of the cached DNS response bytes, or null if not cached or expired.
     */
    fun get(domain: String): ByteArray? {
        val entry = cache[domain] ?: return null
        if (System.currentTimeMillis() >= entry.expiresAtMillis) {
            cache.remove(domain)
            return null
        }
        return entry.responseBytes.copyOf()
    }

    /**
     * Caches a DNS response for the given domain.
     */
    fun put(domain: String, responseBytes: ByteArray, ttlSeconds: Int) {
        val expiresAt = System.currentTimeMillis() + (ttlSeconds * 1000L)
        cache[domain] = CacheEntry(responseBytes.copyOf(), expiresAt)
    }

    /**
     * Removes all cached entries.
     */
    fun clear() {
        cache.clear()
    }
}
