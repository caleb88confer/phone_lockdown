package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class DnsCacheTest {

    private lateinit var cache: DnsCache

    @BeforeEach
    fun setUp() {
        cache = DnsCache(maxSize = 4)
    }

    @Test
    fun `get returns null for uncached domain`() {
        assertNull(cache.get("example.com"))
    }

    @Test
    fun `put and get returns cached response bytes`() {
        val response = byteArrayOf(0x12, 0x34, 0x01, 0x00)
        cache.put("example.com", response, ttlSeconds = 60)

        val cached = cache.get("example.com")
        assertNotNull(cached)
        assertArrayEquals(response, cached)
    }

    @Test
    fun `get returns independent copy of cached bytes`() {
        val response = byteArrayOf(0x12, 0x34, 0x01, 0x00)
        cache.put("example.com", response, ttlSeconds = 60)

        val cached1 = cache.get("example.com")!!
        cached1[0] = 0xFF.toByte()

        val cached2 = cache.get("example.com")!!
        assertEquals(0x12.toByte(), cached2[0])
    }

    @Test
    fun `get returns null for expired entry`() {
        val response = byteArrayOf(0x12, 0x34)
        cache.put("example.com", response, ttlSeconds = 0)

        // TTL of 0 means already expired
        Thread.sleep(50)
        assertNull(cache.get("example.com"))
    }

    @Test
    fun `evicts oldest entry when max size exceeded`() {
        cache.put("a.com", byteArrayOf(1), ttlSeconds = 60)
        cache.put("b.com", byteArrayOf(2), ttlSeconds = 60)
        cache.put("c.com", byteArrayOf(3), ttlSeconds = 60)
        cache.put("d.com", byteArrayOf(4), ttlSeconds = 60)

        // Cache is full (maxSize=4). Adding one more should evict "a.com"
        cache.put("e.com", byteArrayOf(5), ttlSeconds = 60)

        assertNull(cache.get("a.com"))
        assertNotNull(cache.get("b.com"))
        assertNotNull(cache.get("e.com"))
    }

    @Test
    fun `get refreshes LRU order so accessed entry is not evicted`() {
        cache.put("a.com", byteArrayOf(1), ttlSeconds = 60)
        cache.put("b.com", byteArrayOf(2), ttlSeconds = 60)
        cache.put("c.com", byteArrayOf(3), ttlSeconds = 60)
        cache.put("d.com", byteArrayOf(4), ttlSeconds = 60)

        // Access "a.com" to move it to most-recently-used
        cache.get("a.com")

        // Adding a new entry should now evict "b.com" (oldest non-accessed)
        cache.put("e.com", byteArrayOf(5), ttlSeconds = 60)

        assertNotNull(cache.get("a.com"))
        assertNull(cache.get("b.com"))
    }

    @Test
    fun `put overwrites existing entry for same domain`() {
        cache.put("example.com", byteArrayOf(1), ttlSeconds = 60)
        cache.put("example.com", byteArrayOf(2), ttlSeconds = 60)

        val cached = cache.get("example.com")
        assertNotNull(cached)
        assertArrayEquals(byteArrayOf(2), cached)
    }

    @Test
    fun `clear removes all entries`() {
        cache.put("a.com", byteArrayOf(1), ttlSeconds = 60)
        cache.put("b.com", byteArrayOf(2), ttlSeconds = 60)

        cache.clear()

        assertNull(cache.get("a.com"))
        assertNull(cache.get("b.com"))
    }
}
