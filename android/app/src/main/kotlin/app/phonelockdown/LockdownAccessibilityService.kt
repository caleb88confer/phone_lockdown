package app.phonelockdown

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
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

        private const val EDIT_TEXT_CLASS = "android.widget.EditText"
        private const val FALLBACK_NODE_VISIT_LIMIT = 500
        private const val FALLBACK_CANDIDATE_LIMIT = 20

        /** Set blocking state without triggering notification update */
        fun setBlockingActiveSilently(value: Boolean) {
            _isBlockingActive = value
        }
    }

    private val lastCheckedUrl = mutableMapOf<String, String>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadStateFromPrefs()
        createNotificationChannel()
        updateForegroundNotification()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleAppBlocking(packageName)
                handleUrlBlocking(packageName)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleUrlBlocking(packageName)
            }
        }
    }

    private fun handleAppBlocking(packageName: String) {
        if (AppBlockingDecider.shouldBlock(packageName, isBlockingActive, blockedPackages, this.packageName)) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(
                this,
                "This app is blocked by Phone Lockdown",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun handleUrlBlocking(packageName: String) {
        if (!isBlockingActive) return
        if (blockedWebsites.isEmpty()) return
        if (packageName !in BrowserPackages.all(this)) return

        val root = rootInActiveWindow ?: return

        val knownIdTexts: List<CharSequence?> = BrowserPackages.URL_BAR_VIEW_IDS[packageName]
            ?.let { id -> root.findAccessibilityNodeInfosByViewId(id)?.map { it.text } }
            ?: emptyList()

        val fallbackTexts: List<CharSequence?> =
            if (knownIdTexts.any { !it.isNullOrBlank() }) emptyList()
            else collectEditTextText(root)

        val url = BrowserUrlExtractor.pickUrl(knownIdTexts, fallbackTexts) ?: return

        if (lastCheckedUrl[packageName] == url) return
        lastCheckedUrl[packageName] = url

        if (DomainMatcher.matches(url, blockedWebsites)) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            Handler(Looper.getMainLooper()).postDelayed({
                performGlobalAction(GLOBAL_ACTION_HOME)
            }, 150L)
            Toast.makeText(
                this,
                "Website blocked by Phone Lockdown",
                Toast.LENGTH_SHORT
            ).show()
            lastCheckedUrl.remove(packageName)
        }
    }

    private fun collectEditTextText(root: AccessibilityNodeInfo): List<CharSequence?> {
        val out = mutableListOf<CharSequence?>()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        var visited = 0
        while (stack.isNotEmpty() && visited < FALLBACK_NODE_VISIT_LIMIT && out.size < FALLBACK_CANDIDATE_LIMIT) {
            val node = stack.removeLast()
            visited++
            if (node.className == EDIT_TEXT_CLASS) {
                out.add(node.text)
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.addLast(it) }
            }
        }
        return out
    }

    override fun onInterrupt() {
        // Required override
    }

    override fun onDestroy() {
        instance = null
        lastCheckedUrl.clear()
        super.onDestroy()
    }

    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        setBlockingActiveSilently(prefs.getBoolean(Constants.PREF_IS_BLOCKING, false))
        blockedPackages = prefs.getStringSet(Constants.PREF_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
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
