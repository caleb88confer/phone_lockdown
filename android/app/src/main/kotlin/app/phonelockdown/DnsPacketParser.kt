package app.phonelockdown

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

    private const val TTL_FLOOR = 60
    private const val TTL_CAP = 300
    private const val TTL_DEFAULT = 60

    /**
     * Extracts the TTL from the first answer record in a DNS response.
     * Returns the TTL clamped between TTL_FLOOR and TTL_CAP.
     * Returns TTL_DEFAULT if there are no answer records.
     */
    fun extractTtl(packet: ByteArray): Int {
        if (packet.size < DNS_HEADER_SIZE) return TTL_DEFAULT

        // ANCOUNT is bytes 6-7
        val anCount = ((packet[6].toInt() and 0xFF) shl 8) or (packet[7].toInt() and 0xFF)
        if (anCount < 1) return TTL_DEFAULT

        // Skip past the question section to reach the answer section
        var offset = DNS_HEADER_SIZE

        // QDCOUNT is bytes 4-5
        val qdCount = ((packet[4].toInt() and 0xFF) shl 8) or (packet[5].toInt() and 0xFF)

        // Skip each question: QNAME + QTYPE(2) + QCLASS(2)
        for (i in 0 until qdCount) {
            while (offset < packet.size) {
                val labelLen = packet[offset].toInt() and 0xFF
                if (labelLen == 0) {
                    offset++ // skip the zero-length label
                    break
                }
                if ((labelLen and 0xC0) == 0xC0) {
                    offset += 2 // pointer is 2 bytes
                    break
                }
                offset += 1 + labelLen
            }
            offset += 4 // QTYPE + QCLASS
        }

        // Now at the first answer RR
        // Skip NAME (could be a pointer or labels)
        if (offset >= packet.size) return TTL_DEFAULT
        val firstByte = packet[offset].toInt() and 0xFF
        if ((firstByte and 0xC0) == 0xC0) {
            offset += 2 // name pointer
        } else {
            while (offset < packet.size) {
                val labelLen = packet[offset].toInt() and 0xFF
                if (labelLen == 0) {
                    offset++
                    break
                }
                offset += 1 + labelLen
            }
        }

        // TYPE(2) + CLASS(2) = 4 bytes, then TTL(4)
        offset += 4
        if (offset + 4 > packet.size) return TTL_DEFAULT

        val ttl = ((packet[offset].toInt() and 0xFF) shl 24) or
                  ((packet[offset + 1].toInt() and 0xFF) shl 16) or
                  ((packet[offset + 2].toInt() and 0xFF) shl 8) or
                  (packet[offset + 3].toInt() and 0xFF)

        return ttl.coerceIn(TTL_FLOOR, TTL_CAP)
    }
}
