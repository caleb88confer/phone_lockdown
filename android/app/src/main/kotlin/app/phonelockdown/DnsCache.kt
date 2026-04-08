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
