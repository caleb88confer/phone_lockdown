package com.example.phone_lockdown

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer

class LockdownVpnService : VpnService() {

    companion object {
        private const val TAG = "LockdownVpn"
        private const val CHANNEL_ID = "lockdown_vpn"
        private const val NOTIFICATION_ID = 1002
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val DNS_SERVER = "8.8.8.8"
        private const val DNS_SERVER_SECONDARY = "8.8.4.4"
        private val DNS_SERVERS = listOf("8.8.8.8", "8.8.4.4", "1.1.1.1")
        private const val DNS_TIMEOUT_MS = 3000
        private const val DNS_PORT = 53
        private const val MAX_PACKET_SIZE = 32767

        var instance: LockdownVpnService? = null
        @Volatile var blockedWebsites: Set<String> = emptySet()
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile
    private var isRunning = false
    private var processingThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        loadStateFromPrefs()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startVpn()

        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        stopVpn()
        instance = null
        super.onDestroy()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN revoked by system (another VPN may have taken over)")
        stopVpn()
        super.onRevoke()
    }

    private fun startVpn() {
        if (isRunning) return

        try {
            val builder = Builder()
                .setSession("Phone Lockdown")
                .addAddress(VPN_ADDRESS, 32)
                .addRoute(DNS_SERVER, 32)
                .addRoute(DNS_SERVER_SECONDARY, 32)
                .addDnsServer(DNS_SERVER)
                .addDnsServer(DNS_SERVER_SECONDARY)
                .setBlocking(true)

            // Allow our own app to bypass the VPN
            builder.addDisallowedApplication(packageName)

            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface")
                stopSelf()
                return
            }

            isRunning = true
            processingThread = Thread(::processPackets, "VPN-PacketProcessor").also { it.start() }
            Log.i(TAG, "VPN started, blocking ${blockedWebsites.size} websites")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN", e)
            stopSelf()
        }
    }

    private fun stopVpn() {
        isRunning = false
        processingThread?.interrupt()
        processingThread = null

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun processPackets() {
        val vpnFd = vpnInterface ?: return
        val inputStream = FileInputStream(vpnFd.fileDescriptor)
        val outputStream = FileOutputStream(vpnFd.fileDescriptor)
        val packet = ByteArray(MAX_PACKET_SIZE)

        while (isRunning) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) {
                    Thread.sleep(10)
                    continue
                }

                val packetData = packet.copyOf(length)
                handlePacket(packetData, outputStream)
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "Error processing packet", e)
                }
            }
        }

        try {
            inputStream.close()
            outputStream.close()
        } catch (_: Exception) {}
    }

    private fun handlePacket(packet: ByteArray, outputStream: FileOutputStream) {
        // Minimum IP header is 20 bytes
        if (packet.size < 20) return

        // Check IP version (should be 4)
        val version = (packet[0].toInt() shr 4) and 0xF
        if (version != 4) return

        val ipHeaderLength = (packet[0].toInt() and 0xF) * 4
        val protocol = packet[9].toInt() and 0xFF

        // Only handle UDP (protocol 17)
        if (protocol != 17) return

        // Check we have enough data for UDP header (8 bytes)
        if (packet.size < ipHeaderLength + 8) return

        // Extract destination port from UDP header
        val destPort = ((packet[ipHeaderLength + 2].toInt() and 0xFF) shl 8) or
                (packet[ipHeaderLength + 3].toInt() and 0xFF)

        // Only handle DNS (port 53)
        if (destPort != DNS_PORT) return

        // Extract DNS payload
        val udpHeaderLength = 8
        val dnsOffset = ipHeaderLength + udpHeaderLength
        if (dnsOffset >= packet.size) return

        val dnsPayload = packet.copyOfRange(dnsOffset, packet.size)

        if (!DnsPacketParser.isQuery(dnsPayload)) return

        val domain = DnsPacketParser.extractDomainFromQuery(dnsPayload)
        if (domain != null && DomainMatcher.matches(domain, blockedWebsites)) {
            Log.d(TAG, "Blocking DNS query for: $domain")
            val nxdomainDns = DnsPacketParser.buildNxdomainResponse(dnsPayload)
            val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, nxdomainDns)
            outputStream.write(responsePacket)
            outputStream.flush()
            return
        }

        // Forward non-blocked DNS queries to real DNS server
        try {
            val responseDns = forwardDnsQuery(dnsPayload)
            if (responseDns != null) {
                val responsePacket = buildIpUdpResponse(packet, ipHeaderLength, responseDns)
                outputStream.write(responsePacket)
                outputStream.flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error forwarding DNS query", e)
        }
    }

    /**
     * Forwards a DNS query to real DNS servers with failover.
     * Tries each server in DNS_SERVERS sequentially; moves to the next on timeout or error.
     */
    private fun forwardDnsQuery(dnsPayload: ByteArray): ByteArray? {
        for (server in DNS_SERVERS) {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket)

                val dnsServer = InetAddress.getByName(server)
                val sendPacket = DatagramPacket(dnsPayload, dnsPayload.size, dnsServer, DNS_PORT)
                socket.soTimeout = DNS_TIMEOUT_MS
                socket.send(sendPacket)

                val responseBuffer = ByteArray(MAX_PACKET_SIZE)
                val receivePacket = DatagramPacket(responseBuffer, responseBuffer.size)
                socket.receive(receivePacket)

                return responseBuffer.copyOf(receivePacket.length)
            } catch (e: Exception) {
                Log.w(TAG, "DNS forwarding to $server failed: ${e.message}")
            } finally {
                socket?.close()
            }
        }
        Log.e(TAG, "All DNS servers failed")
        return null
    }

    /**
     * Builds an IP+UDP response packet by swapping source/dest addresses and ports,
     * and replacing the DNS payload.
     */
    private fun buildIpUdpResponse(
        originalPacket: ByteArray,
        ipHeaderLength: Int,
        dnsResponse: ByteArray
    ): ByteArray {
        val udpHeaderLength = 8
        val totalLength = ipHeaderLength + udpHeaderLength + dnsResponse.size
        val response = ByteArray(totalLength)

        // Copy original IP header
        System.arraycopy(originalPacket, 0, response, 0, ipHeaderLength)

        // Update total length in IP header (bytes 2-3)
        response[2] = ((totalLength shr 8) and 0xFF).toByte()
        response[3] = (totalLength and 0xFF).toByte()

        // Swap source and destination IP addresses
        // Source IP: bytes 12-15, Dest IP: bytes 16-19
        for (i in 0 until 4) {
            val temp = response[12 + i]
            response[12 + i] = response[16 + i]
            response[16 + i] = temp
        }

        // Zero IP checksum before recalculating
        response[10] = 0
        response[11] = 0
        val ipChecksum = calculateChecksum(response, 0, ipHeaderLength)
        response[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        response[11] = (ipChecksum and 0xFF).toByte()

        // Build UDP header
        val udpOffset = ipHeaderLength
        // Swap source and destination ports
        response[udpOffset] = originalPacket[udpOffset + 2]
        response[udpOffset + 1] = originalPacket[udpOffset + 3]
        response[udpOffset + 2] = originalPacket[udpOffset]
        response[udpOffset + 3] = originalPacket[udpOffset + 1]

        // UDP length
        val udpLength = udpHeaderLength + dnsResponse.size
        response[udpOffset + 4] = ((udpLength shr 8) and 0xFF).toByte()
        response[udpOffset + 5] = (udpLength and 0xFF).toByte()

        // Zero UDP checksum (optional for IPv4)
        response[udpOffset + 6] = 0
        response[udpOffset + 7] = 0

        // Copy DNS response payload
        System.arraycopy(dnsResponse, 0, response, udpOffset + udpHeaderLength, dnsResponse.size)

        return response
    }

    private fun calculateChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        val end = offset + length

        while (i < end - 1) {
            sum += ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            i += 2
        }

        // Handle odd byte
        if (i < end) {
            sum += (data[i].toInt() and 0xFF) shl 8
        }

        // Fold 32-bit sum to 16 bits
        while (sum shr 16 != 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }

        return sum.inv() and 0xFFFF
    }

    private fun loadStateFromPrefs() {
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Website Blocking VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active when website blocking is enabled"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Phone Lockdown")
            .setContentText("Website blocking active — ${blockedWebsites.size} sites blocked")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
