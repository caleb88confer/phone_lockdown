package com.example.phone_lockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class DnsPacketParserTest {

    private fun buildDnsQuery(domain: String, transactionId: Short = 0x1234): ByteArray {
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
}
