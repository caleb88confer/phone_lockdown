package com.example.phone_lockdown

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import androidx.core.app.NotificationCompat

class LockdownAccessibilityService : AccessibilityService() {

    companion object {
        var instance: LockdownAccessibilityService? = null
        var blockedPackages: Set<String> = emptySet()
        var blockedWebsites: Set<String> = emptySet()
        private var _isBlockingActive: Boolean = false
        var isBlockingActive: Boolean
            get() = _isBlockingActive
            set(value) {
                _isBlockingActive = value
                instance?.updateForegroundNotification()
            }

        private const val CHANNEL_ID = "lockdown_active"
        private const val NOTIFICATION_ID = 1001

        /** Set blocking state without triggering notification update */
        fun setBlockingActiveSilently(value: Boolean) {
            _isBlockingActive = value
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadStateFromPrefs()
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

    override fun onInterrupt() {
        // Required override
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        setBlockingActiveSilently(prefs.getBoolean("isBlocking", false))
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
