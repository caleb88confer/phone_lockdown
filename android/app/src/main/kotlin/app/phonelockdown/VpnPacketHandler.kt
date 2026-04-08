package app.phonelockdown

import java.io.OutputStream

interface DnsResolver {
    fun forward(dnsPayload: ByteArray): ByteArray?
}

class VpnPacketHandler(
    private val blockedWebsites: () -> Set<String>,
    private val dnsCache: DnsCache,
    private val dnsResolver: DnsResolver
) {
    companion object {
        private const val DNS_PORT = 53
    }

    fun handlePacket(packet: ByteArray, length: Int, outputStream: OutputStream) {
        if (length < 20) return
        val version = (packet[0].toInt() shr 4) and 0xF
        if (version != 4) return
        val ipHeaderLength = (packet[0].toInt() and 0xF) * 4
        val protocol = packet[9].toInt() and 0xFF
        if (protocol != 17) return
        if (length < ipHeaderLength + 8) return
        val destPort = ((packet[ipHeaderLength + 2].toInt() and 0xFF) shl 8) or
                (packet[ipHeaderLength + 3].toInt() and 0xFF)
        if (destPort != DNS_PORT) return
        val udpHeaderLength = 8
        val dnsOffset = ipHeaderLength + udpHeaderLength
        if (dnsOffset >= length) return
        val dnsPayload = packet.copyOfRange(dnsOffset, length)
        if (!DnsPacketParser.isQuery(dnsPayload)) return

        val domain = DnsPacketParser.extractDomainFromQuery(dnsPayload)
        if (domain != null && DomainMatcher.matches(domain, blockedWebsites())) {
            AppLogger.d("VPN", "Blocking DNS query for: $domain")
            val nxdomainDns = DnsPacketParser.buildNxdomainResponse(dnsPayload)
            val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, nxdomainDns)
            outputStream.write(responsePacket)
            outputStream.flush()
            return
        }

        if (domain != null) {
            val cachedResponse = dnsCache.get(domain)
            if (cachedResponse != null) {
                cachedResponse[0] = dnsPayload[0]
                cachedResponse[1] = dnsPayload[1]
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, cachedResponse)
                outputStream.write(responsePacket)
                outputStream.flush()
                return
            }
        }

        try {
            val responseDns = dnsResolver.forward(dnsPayload)
            if (responseDns != null) {
                if (domain != null) {
                    val ttl = DnsPacketParser.extractTtl(responseDns)
                    dnsCache.put(domain, responseDns, ttl)
                }
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, responseDns)
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
