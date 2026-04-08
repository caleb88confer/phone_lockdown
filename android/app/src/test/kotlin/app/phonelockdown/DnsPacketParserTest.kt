package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class DnsPacketParserTest {

    private fun buildDnsQuery(domain: String, transactionId: Int = 0x1234): ByteArray {
        val labels = domain.split(".")
        val qnameSize = labels.sumOf { 1 + it.length } + 1
        val packet = ByteArray(12 + qnameSize + 4)

        packet[0] = (transactionId.toInt() shr 8).toByte()
        packet[1] = (transactionId.toInt() and 0xFF).toByte()
        packet[2] = 0x01
        packet[3] = 0x00
        packet[4] = 0x00
        packet[5] = 0x01

        var offset = 12
        for (label in labels) {
            packet[offset++] = label.length.toByte()
            for (ch in label) {
                packet[offset++] = ch.code.toByte()
            }
        }
        packet[offset++] = 0x00
        packet[offset++] = 0x00
        packet[offset++] = 0x01
        packet[offset++] = 0x00
        packet[offset] = 0x01

        return packet
    }

    @Test
    fun `isQuery returns true for standard query`() {
        val query = buildDnsQuery("example.com")
        assertTrue(DnsPacketParser.isQuery(query))
    }

    @Test
    fun `isQuery returns false for response`() {
        val query = buildDnsQuery("example.com")
        query[2] = (query[2].toInt() or 0x80).toByte()
        assertFalse(DnsPacketParser.isQuery(query))
    }

    @Test
    fun `isQuery returns false for packet shorter than header`() {
        val tooShort = ByteArray(6)
        assertFalse(DnsPacketParser.isQuery(tooShort))
    }

    @Test
    fun `extractDomainFromQuery parses single-level domain`() {
        val query = buildDnsQuery("localhost")
        assertEquals("localhost", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery parses multi-level domain`() {
        val query = buildDnsQuery("www.example.com")
        assertEquals("www.example.com", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns lowercase`() {
        val query = buildDnsQuery("WWW.Example.COM")
        assertEquals("www.example.com", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns null for response packet`() {
        val query = buildDnsQuery("example.com")
        query[2] = (query[2].toInt() or 0x80).toByte()
        assertNull(DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns null for packet too short`() {
        val tooShort = ByteArray(12)
        assertNull(DnsPacketParser.extractDomainFromQuery(tooShort))
    }

    @Test
    fun `extractDomainFromQuery returns null when qdcount is zero`() {
        val query = buildDnsQuery("example.com")
        query[4] = 0x00
        query[5] = 0x00
        assertNull(DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `buildNxdomainResponse sets QR bit and NXDOMAIN rcode`() {
        val query = buildDnsQuery("blocked.com")
        val response = DnsPacketParser.buildNxdomainResponse(query)
        assertEquals(0x81.toByte(), response[2])
        assertEquals(0x83.toByte(), response[3])
    }

    @Test
    fun `buildNxdomainResponse preserves transaction ID`() {
        val query = buildDnsQuery("blocked.com", transactionId = 0x5678)
        val response = DnsPacketParser.buildNxdomainResponse(query)
        assertEquals(0x56.toByte(), response[0])
        assertEquals(0x78.toByte(), response[1])
    }

    @Test
    fun `buildNxdomainResponse sets QDCOUNT to 1 and answer counts to 0`() {
        val query = buildDnsQuery("blocked.com")
        val response = DnsPacketParser.buildNxdomainResponse(query)
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
    fun `buildNxdomainResponse returns original packet if too short`() {
        val tooShort = ByteArray(6) { 0x42 }
        val response = DnsPacketParser.buildNxdomainResponse(tooShort)
        assertArrayEquals(tooShort, response)
    }

    // --- TTL extraction tests ---

    /**
     * Builds a minimal DNS response with one A record answer.
     * The answer section has: name pointer (2 bytes), type (2), class (2), TTL (4), rdlength (2), rdata (4).
     */
    private fun buildDnsResponseWithTtl(domain: String, ttlSeconds: Int): ByteArray {
        val query = buildDnsQuery(domain)
        // Make it a response
        query[2] = (query[2].toInt() or 0x80).toByte()
        // Set ANCOUNT = 1
        query[6] = 0x00
        query[7] = 0x01

        // Answer section: name pointer + type A + class IN + TTL + rdlength + rdata
        val answer = ByteArray(16)
        // Name pointer to offset 12 (start of question QNAME)
        answer[0] = 0xC0.toByte()
        answer[1] = 0x0C
        // Type A = 1
        answer[2] = 0x00
        answer[3] = 0x01
        // Class IN = 1
        answer[4] = 0x00
        answer[5] = 0x01
        // TTL (4 bytes, big-endian)
        answer[6] = ((ttlSeconds shr 24) and 0xFF).toByte()
        answer[7] = ((ttlSeconds shr 16) and 0xFF).toByte()
        answer[8] = ((ttlSeconds shr 8) and 0xFF).toByte()
        answer[9] = (ttlSeconds and 0xFF).toByte()
        // RDLENGTH = 4 (IPv4 address)
        answer[10] = 0x00
        answer[11] = 0x04
        // RDATA = 1.2.3.4
        answer[12] = 1
        answer[13] = 2
        answer[14] = 3
        answer[15] = 4

        return query + answer
    }

    @Test
    fun `extractTtl returns TTL from answer record`() {
        val response = buildDnsResponseWithTtl("example.com", 120)
        assertEquals(120, DnsPacketParser.extractTtl(response))
    }

    @Test
    fun `extractTtl clamps low TTL to floor of 60`() {
        val response = buildDnsResponseWithTtl("example.com", 5)
        assertEquals(60, DnsPacketParser.extractTtl(response))
    }

    @Test
    fun `extractTtl clamps high TTL to cap of 300`() {
        val response = buildDnsResponseWithTtl("example.com", 86400)
        assertEquals(300, DnsPacketParser.extractTtl(response))
    }

    @Test
    fun `extractTtl returns default 60 when no answer records`() {
        // Build a response with ANCOUNT=0
        val query = buildDnsQuery("example.com")
        query[2] = (query[2].toInt() or 0x80).toByte() // make it a response
        // ANCOUNT is already 0 from buildDnsQuery
        assertEquals(60, DnsPacketParser.extractTtl(query))
    }

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
}
