package com.example.phone_lockdown

import java.nio.ByteBuffer

/**
 * Parses and constructs DNS packets per RFC 1035.
 * Used by LockdownVpnService to inspect DNS queries and build NXDOMAIN responses.
 */
object DnsPacketParser {

    private const val DNS_HEADER_SIZE = 12
    private const val QR_MASK = 0x80.toByte()  // bit 7 of flags byte
    private const val RCODE_NXDOMAIN = 3

    /**
     * Returns true if the packet is a DNS query (QR bit = 0).
     */
    fun isQuery(packet: ByteArray): Boolean {
        if (packet.size < DNS_HEADER_SIZE) return false
        // QR is bit 7 of byte 2 (flags1)
        return (packet[2].toInt() and 0x80) == 0
    }

    /**
     * Extracts the queried domain name from a DNS query packet.
     * Returns null if the packet is malformed or not a query.
     */
    fun extractDomainFromQuery(packet: ByteArray): String? {
        if (packet.size < DNS_HEADER_SIZE + 1) return false as? String
        if (!isQuery(packet)) return null

        // QDCOUNT is bytes 4-5
        val qdCount = ((packet[4].toInt() and 0xFF) shl 8) or (packet[5].toInt() and 0xFF)
        if (qdCount < 1) return null

        // Question section starts after the 12-byte header
        var offset = DNS_HEADER_SIZE
        val labels = mutableListOf<String>()

        while (offset < packet.size) {
            val labelLen = packet[offset].toInt() and 0xFF
            if (labelLen == 0) break  // root label = end of name
            offset++
            if (offset + labelLen > packet.size) return null  // malformed
            labels.add(String(packet, offset, labelLen, Charsets.US_ASCII))
            offset += labelLen
        }

        if (labels.isEmpty()) return null
        return labels.joinToString(".").lowercase()
    }

    /**
     * Builds an NXDOMAIN response for the given DNS query packet.
     * Copies the transaction ID and question section, sets response flags with NXDOMAIN rcode.
     */
    fun buildNxdomainResponse(originalQuery: ByteArray): ByteArray {
        // We need at least the header
        if (originalQuery.size < DNS_HEADER_SIZE) {
            return originalQuery
        }

        // Find the end of the question section
        var offset = DNS_HEADER_SIZE
        // Skip QNAME
        while (offset < originalQuery.size) {
            val labelLen = originalQuery[offset].toInt() and 0xFF
            offset++
            if (labelLen == 0) break
            offset += labelLen
        }
        // Skip QTYPE (2 bytes) + QCLASS (2 bytes)
        offset += 4

        val responseSize = offset.coerceAtMost(originalQuery.size)
        val response = originalQuery.copyOf(responseSize)

        // Set flags: QR=1 (response), Opcode=0 (standard), AA=1, TC=0, RD=1, RA=1, RCODE=NXDOMAIN(3)
        response[2] = 0x81.toByte()  // QR=1, Opcode=0, AA=0, TC=0, RD=1
        response[3] = 0x83.toByte()  // RA=1, Z=0, RCODE=3 (NXDOMAIN)

        // QDCOUNT = 1
        response[4] = 0
        response[5] = 1

        // ANCOUNT = 0
        response[6] = 0
        response[7] = 0

        // NSCOUNT = 0
        response[8] = 0
        response[9] = 0

        // ARCOUNT = 0
        response[10] = 0
        response[11] = 0

        return response
    }
}
