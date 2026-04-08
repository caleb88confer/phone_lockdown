package app.phonelockdown

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray

class FailsafeAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FailsafeAlarmReceiver"
        private const val CHANNEL_ID = "failsafe_timer"
        private const val NOTIFICATION_ID = 3001

        /**
         * Recompute merged block lists from remaining active profile blocks,
         * excluding the specified profile ID. Updates accessibility service and VPN.
         * Returns true if there are still active profiles remaining.
         */
        fun deactivateProfile(context: Context, profileId: String): Boolean {
            val prefs = PrefsHelper.getPrefs(context)

            // Remove this profile from failsafe alarms
            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
            val alarms = JSONArray(alarmsJson)
            val updatedAlarms = JSONArray()
            for (i in 0 until alarms.length()) {
                val obj = alarms.getJSONObject(i)
                if (obj.getString("profileId") != profileId) {
                    updatedAlarms.put(obj)
                }
            }

            // Remove this profile from active profile blocks and recompute merged lists
            val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]")
            val blocks = JSONArray(blocksJson)
            val updatedBlocks = JSONArray()
            val mergedPackages = mutableSetOf<String>()
            val mergedWebsites = mutableSetOf<String>()

            for (i in 0 until blocks.length()) {
                val obj = blocks.getJSONObject(i)
                if (obj.getString("profileId") != profileId) {
                    updatedBlocks.put(obj)
                    val pkgs = obj.getJSONArray("blockedPackages")
                    for (j in 0 until pkgs.length()) {
                        mergedPackages.add(pkgs.getString(j))
                    }
                    val webs = obj.getJSONArray("blockedWebsites")
                    for (j in 0 until webs.length()) {
                        mergedWebsites.add(webs.getString(j))
                    }
                }
            }

            val hasRemainingProfiles = updatedBlocks.length() > 0

            prefs.edit()
                .putBoolean(Constants.PREF_IS_BLOCKING, hasRemainingProfiles)
                .putStringSet(Constants.PREF_BLOCKED_PACKAGES, if (hasRemainingProfiles) mergedPackages else emptySet())
                .putStringSet(Constants.PREF_BLOCKED_WEBSITES, if (hasRemainingProfiles) mergedWebsites else emptySet())
                .putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, updatedBlocks.toString())
                .putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString())
                .commit()

            // Update accessibility service
            LockdownAccessibilityService.isBlockingActive = hasRemainingProfiles
            LockdownAccessibilityService.blockedPackages = if (hasRemainingProfiles) mergedPackages else emptySet()
            LockdownAccessibilityService.blockedWebsites = if (hasRemainingProfiles) mergedWebsites else emptySet()

            // Update VPN
            if (!hasRemainingProfiles || mergedWebsites.isEmpty()) {
                try {
                    val vpnIntent = Intent(context, LockdownVpnService::class.java).apply {
                        action = "STOP"
                    }
                    context.startService(vpnIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop VPN service", e)
                }
            } else {
                LockdownVpnService.blockedWebsites = mergedWebsites
            }

            return hasRemainingProfiles
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val profileId = intent.getStringExtra("profileId") ?: return
        Log.d(TAG, "Failsafe alarm fired for profile: $profileId")

        deactivateProfile(context, profileId)

        showNotification(context, "Failsafe timer expired — blocking deactivated for a profile")
    }

    private fun showNotification(context: Context, message: String) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Failsafe Timer",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when failsafe timer expires"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Phone Lockdown")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
