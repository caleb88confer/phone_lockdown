package app.phonelockdown

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ExecutorCompletionService
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class LockdownVpnService : VpnService() {

    companion object {
        private const val CHANNEL_ID = "lockdown_vpn"
        private const val NOTIFICATION_ID = 1002
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val DNS_SERVER = "8.8.8.8"
        private const val DNS_SERVER_SECONDARY = "8.8.4.4"
        private val DNS_SERVERS = listOf("8.8.8.8", "8.8.4.4", "1.1.1.1")
        private const val DNS_TIMEOUT_MS = 1500
        private const val DNS_PORT = 53
        private const val MAX_PACKET_SIZE = 32767

        var instance: LockdownVpnService? = null
        @Volatile var blockedWebsites: Set<String> = emptySet()
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile
    private var isRunning = false
    private var processingThread: Thread? = null
    private var dnsExecutor: ExecutorService? = null
    private val dnsCache = DnsCache()
    private val packetHandler = VpnPacketHandler(
        blockedWebsites = { blockedWebsites },
        dnsCache = dnsCache,
        dnsResolver = object : DnsResolver {
            override fun forward(dnsPayload: ByteArray): ByteArray? = forwardDnsQuery(dnsPayload)
        }
    )

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
        AppLogger.w("VPN", "VPN revoked by system (another VPN may have taken over)")
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

            builder.addDisallowedApplication(packageName)

            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                AppLogger.e("VPN", "Failed to establish VPN interface")
                stopSelf()
                return
            }

            isRunning = true
            dnsExecutor = Executors.newFixedThreadPool(4) { r ->
                Thread(r, "VPN-DnsWorker").also { it.isDaemon = true }
            }
            processingThread = Thread(::processPackets, "VPN-PacketProcessor").also { it.start() }
            AppLogger.i("VPN", "VPN started, blocking ${blockedWebsites.size} websites")
        } catch (e: Exception) {
            AppLogger.e("VPN", "Failed to start VPN", e)
            stopSelf()
        }
    }

    private fun stopVpn() {
        isRunning = false

        dnsExecutor?.let { executor ->
            executor.shutdown()
            try {
                if (!executor.awaitTermination(2, TimeUnit.SECONDS)) {
                    executor.shutdownNow()
                }
            } catch (_: InterruptedException) {
                executor.shutdownNow()
            }
        }
        dnsExecutor = null

        dnsCache.clear()
        processingThread?.interrupt()
        processingThread = null

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            AppLogger.e("VPN", "Error closing VPN interface", e)
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
        val executor = dnsExecutor ?: return

        while (isRunning) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) continue

                val pending: PendingDnsQuery?
                synchronized(outputStream) {
                    pending = packetHandler.handlePacket(packet, length, outputStream)
                }
                if (pending != null) {
                    executor.submit {
                        synchronized(outputStream) {
                            packetHandler.completePendingQuery(pending, outputStream)
                        }
                    }
                }
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                if (isRunning) {
                    AppLogger.e("VPN", "Error processing packet", e)
                }
            }
        }

        try {
            inputStream.close()
            outputStream.close()
        } catch (_: Exception) {}
    }

    /**
     * Forwards a DNS query to all DNS servers in parallel, returning the first successful response.
     */
    private fun forwardDnsQuery(dnsPayload: ByteArray): ByteArray? {
        val raceExecutor = Executors.newFixedThreadPool(DNS_SERVERS.size)
        val completionService = ExecutorCompletionService<ByteArray?>(raceExecutor)

        try {
            for (server in DNS_SERVERS) {
                completionService.submit {
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

                        responseBuffer.copyOf(receivePacket.length)
                    } catch (e: Exception) {
                        AppLogger.w("VPN", "DNS racing to $server failed: ${e.message}")
                        null
                    } finally {
                        socket?.close()
                    }
                }
            }

            // Take results as they complete, return the first non-null
            for (i in DNS_SERVERS.indices) {
                try {
                    val future = completionService.poll(DNS_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)
                        ?: break // Timed out waiting for any result
                    val result = future.get()
                    if (result != null) return result
                } catch (e: Exception) {
                    // This server's result failed, try next
                }
            }

            AppLogger.e("VPN", "All DNS servers failed (parallel race)")
            return null
        } finally {
            raceExecutor.shutdownNow()
        }
    }

    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
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
