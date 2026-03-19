package com.example.phone_lockdown

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import androidx.core.app.NotificationCompat

class LockdownAccessibilityService : AccessibilityService() {

    companion object {
        var instance: LockdownAccessibilityService? = null
        var blockedPackages: Set<String> = emptySet()
        var blockedWebsites: Set<String> = emptySet()
        var isBlockingActive: Boolean = false
            set(value) {
                field = value
                instance?.updateForegroundNotification()
            }

        private const val CHANNEL_ID = "lockdown_active"
        private const val NOTIFICATION_ID = 1001
    }

    private var browserPackages: Set<String> = emptySet()

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadStateFromPrefs()
        browserPackages = BrowserDetector(this).getInstalledBrowserPackages()
        createNotificationChannel()
        updateForegroundNotification()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isBlockingActive) return

        val packageName = event.packageName?.toString() ?: return

        // Don't block our own app, system UI, or the launcher
        if (isSystemPackage(packageName)) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleAppBlocking(packageName)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (blockedWebsites.isNotEmpty() && browserPackages.contains(packageName)) {
                    handleBrowserContentChanged(packageName)
                }
            }
        }
    }

    private fun isSystemPackage(packageName: String): Boolean {
        return packageName == this.packageName ||
            packageName == "com.android.systemui" ||
            packageName == "com.android.launcher" ||
            packageName == "com.android.launcher3" ||
            packageName == "com.google.android.apps.nexuslauncher"
    }

    private fun handleAppBlocking(packageName: String) {
        if (blockedPackages.contains(packageName)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(
                this,
                "This app is blocked by Phone Lockdown",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun handleBrowserContentChanged(browserPackage: String) {
        val rootNode = rootInActiveWindow ?: return
        val urlText = extractUrlFromBrowser(rootNode, browserPackage)
        rootNode.recycle()

        if (urlText != null && DomainMatcher.matches(urlText, blockedWebsites)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(
                this,
                "This website is blocked by Phone Lockdown",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun extractUrlFromBrowser(
        rootNode: AccessibilityNodeInfo,
        browserPackage: String
    ): String? {
        // Try known URL bar IDs for this browser
        val knownIds = BrowserDetector.URL_BAR_IDS[browserPackage]
        if (knownIds != null) {
            for (id in knownIds) {
                val nodes = rootNode.findAccessibilityNodeInfosByViewId(id)
                if (nodes.isNullOrEmpty()) continue
                val text = nodes[0].text?.toString()
                nodes.forEach { it.recycle() }
                if (!text.isNullOrBlank()) return text
            }
        }

        // Fallback: search for an EditText node that looks like a URL bar
        return findUrlBarFallback(rootNode)
    }

    private fun findUrlBarFallback(node: AccessibilityNodeInfo): String? {
        if (node.className?.toString() == "android.widget.EditText") {
            val text = node.text?.toString()
            if (text != null && text.contains(".") && !text.contains(" ")) {
                return text
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findUrlBarFallback(child)
            child.recycle()
            if (result != null) return result
        }

        return null
    }

    override fun onInterrupt() {
        // Required override
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    private fun loadStateFromPrefs() {
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        // Set field directly to avoid triggering the setter before instance is ready
        Companion::class.java.getDeclaredField("isBlockingActive").let {
            it.isAccessible = true
            it.setBoolean(Companion, prefs.getBoolean("isBlocking", false))
        }
        blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet()
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lockdown Active",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Phone Lockdown is actively blocking apps"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(message: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Phone Lockdown")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    fun updateForegroundNotification() {
        if (isBlockingActive) {
            val count = blockedPackages.size + blockedWebsites.size
            val notification = buildNotification("Blocking active — $count items blocked")
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification)
        } else {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }
    }
}
