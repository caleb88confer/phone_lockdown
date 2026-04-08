package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream

class VpnPacketHandlerTest {

    private lateinit var output: ByteArrayOutputStream
    private lateinit var handler: VpnPacketHandler
    private var resolverCalled = false
    private var resolverResponse: ByteArray? = null

    private val fakeResolver = object : DnsResolver {
        override fun forward(dnsPayload: ByteArray): ByteArray? {
            resolverCalled = true
            return resolverResponse
        }
    }

    @BeforeEach
    fun setUp() {
        output = ByteArrayOutputStream()
        resolverCalled = false
        resolverResponse = null
        handler = VpnPacketHandler(
            blockedWebsites = { setOf("blocked.com") },
            dnsCache = DnsCache(),
            dnsResolver = fakeResolver
        )
    }

    private fun buildDnsQueryPacket(domain: String, srcIp: ByteArray = byteArrayOf(10, 0, 0, 2),
                                     dstIp: ByteArray = byteArrayOf(8, 8, 8, 8),
                                     srcPort: Int = 12345, dstPort: Int = 53): ByteArray {
        val dnsPayload = buildDnsPayload(domain)
        val udpLength = 8 + dnsPayload.size
        val totalLength = 20 + udpLength
        val packet = ByteArray(totalLength)

        packet[0] = 0x45.toByte()
        packet[2] = ((totalLength shr 8) and 0xFF).toByte()
        packet[3] = (totalLength and 0xFF).toByte()
        packet[9] = 17.toByte()
        System.arraycopy(srcIp, 0, packet, 12, 4)
        System.arraycopy(dstIp, 0, packet, 16, 4)

        val udpOffset = 20
        packet[udpOffset] = ((srcPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 1] = (srcPort and 0xFF).toByte()
        packet[udpOffset + 2] = ((dstPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 3] = (dstPort and 0xFF).toByte()
        packet[udpOffset + 4] = ((udpLength shr 8) and 0xFF).toByte()
        packet[udpOffset + 5] = (udpLength and 0xFF).toByte()

        System.arraycopy(dnsPayload, 0, packet, 28, dnsPayload.size)
        return packet
    }

    private fun buildDnsPayload(domain: String): ByteArray {
        val labels = domain.split(".")
        val qnameSize = labels.sumOf { 1 + it.length } + 1
        val payload = ByteArray(12 + qnameSize + 4)

        payload[0] = 0x12
        payload[1] = 0x34
        payload[2] = 0x01
        payload[3] = 0x00
        payload[4] = 0x00
        payload[5] = 0x01

        var offset = 12
        for (label in labels) {
            payload[offset++] = label.length.toByte()
            for (ch in label) { payload[offset++] = ch.code.toByte() }
        }
        payload[offset++] = 0x00
        payload[offset++] = 0x00
        payload[offset++] = 0x01
        payload[offset++] = 0x00
        payload[offset] = 0x01
        return payload
    }

    @Test
    fun `packet shorter than 20 bytes is ignored`() {
        val short = ByteArray(10)
        handler.handlePacket(short, short.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-IPv4 packet is ignored`() {
        val packet = buildDnsQueryPacket("example.com")
        packet[0] = 0x65.toByte()
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-UDP packet is ignored`() {
        val packet = buildDnsQueryPacket("example.com")
        packet[9] = 6.toByte()
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `non-DNS port is ignored`() {
        val packet = buildDnsQueryPacket("example.com", dstPort = 80)
        handler.handlePacket(packet, packet.size, output)
        assertEquals(0, output.size())
    }

    @Test
    fun `blocked domain returns NXDOMAIN response`() {
        val packet = buildDnsQueryPacket("blocked.com")
        handler.handlePacket(packet, packet.size, output)
        assertTrue(output.size() > 0, "Expected NXDOMAIN response to be written")
        assertFalse(resolverCalled, "Resolver should not be called for blocked domains")
        val response = output.toByteArray()
        val dnsOffset = 28
        assertEquals(0x83.toByte(), response[dnsOffset + 3], "Expected NXDOMAIN rcode")
    }

    @Test
    fun `allowed domain forwards via resolver`() {
        val fakeDnsResponse = buildDnsPayload("allowed.com")
        fakeDnsResponse[2] = (fakeDnsResponse[2].toInt() or 0x80).toByte()
        resolverResponse = fakeDnsResponse
        val packet = buildDnsQueryPacket("allowed.com")
        handler.handlePacket(packet, packet.size, output)
        assertTrue(resolverCalled, "Resolver should be called for allowed domains")
        assertTrue(output.size() > 0, "Expected forwarded response to be written")
    }

    @Test
    fun `allowed domain with null resolver response writes nothing`() {
        resolverResponse = null
        val packet = buildDnsQueryPacket("allowed.com")
        handler.handlePacket(packet, packet.size, output)
        assertTrue(resolverCalled)
        assertEquals(0, output.size(), "No response should be written when resolver returns null")
    }

    @Test
    fun `cached domain returns cached response without calling resolver`() {
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
        handler.handlePacket(packet, packet.size, output)
        assertFalse(resolverCalled, "Resolver should not be called for cached domains")
        assertTrue(output.size() > 0, "Expected cached response to be written")
    }

    @Test
    fun `buildIpUdpResponse swaps source and dest IP`() {
        val packet = buildDnsQueryPacket("example.com")
        val dnsResponse = ByteArray(4) { 0x42 }
        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)
        assertEquals(8, response[12].toInt() and 0xFF)
        assertEquals(8, response[13].toInt() and 0xFF)
        assertEquals(8, response[14].toInt() and 0xFF)
        assertEquals(8, response[15].toInt() and 0xFF)
        assertEquals(10, response[16].toInt() and 0xFF)
        assertEquals(0, response[17].toInt() and 0xFF)
        assertEquals(0, response[18].toInt() and 0xFF)
        assertEquals(2, response[19].toInt() and 0xFF)
    }

    @Test
    fun `buildIpUdpResponse swaps source and dest ports`() {
        val packet = buildDnsQueryPacket("example.com", srcPort = 12345, dstPort = 53)
        val dnsResponse = ByteArray(4) { 0x42 }
        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)
        val srcPort = ((response[20].toInt() and 0xFF) shl 8) or (response[21].toInt() and 0xFF)
        val dstPort = ((response[22].toInt() and 0xFF) shl 8) or (response[23].toInt() and 0xFF)
        assertEquals(53, srcPort)
        assertEquals(12345, dstPort)
    }

    @Test
    fun `buildIpUdpResponse has correct total length`() {
        val packet = buildDnsQueryPacket("example.com")
        val dnsResponse = ByteArray(20)
        val response = handler.buildIpUdpResponse(packet, 20, dnsResponse)
        assertEquals(20 + 8 + 20, response.size)
        val ipTotalLen = ((response[2].toInt() and 0xFF) shl 8) or (response[3].toInt() and 0xFF)
        assertEquals(response.size, ipTotalLen)
    }

    @Test
    fun `calculateChecksum produces valid checksum for even-length data`() {
        val data = byteArrayOf(0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
            0x40, 0x06, 0x00, 0x00, 0xac.toByte(), 0x10, 0x0a, 0x63,
            0xac.toByte(), 0x10, 0x0a, 0x0c)
        val checksum = handler.calculateChecksum(data, 0, data.size)
        data[10] = ((checksum shr 8) and 0xFF).toByte()
        data[11] = (checksum and 0xFF).toByte()
        assertEquals(0, handler.calculateChecksum(data, 0, data.size))
    }

    @Test
    fun `calculateChecksum handles odd-length data`() {
        val data = byteArrayOf(0x01, 0x02, 0x03)
        val checksum = handler.calculateChecksum(data, 0, data.size)
        assertTrue(checksum in 0..0xFFFF)
    }

    @Test
    fun `handlePacket respects length parameter and ignores trailing buffer data`() {
        val packet = buildDnsQueryPacket("blocked.com")
        val bigBuffer = ByteArray(32767)
        System.arraycopy(packet, 0, bigBuffer, 0, packet.size)
        handler.handlePacket(bigBuffer, packet.size, output)
        assertTrue(output.size() > 0, "Should handle packet using length param, not buffer size")
    }
}
