package app.phonelockdown

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
class FailsafeAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "failsafe_timer"
        private const val NOTIFICATION_ID = 3001

        /**
         * Recompute merged block lists from remaining active profile blocks,
         * excluding the specified profile ID. Updates accessibility service state.
         * Returns true if there are still active profiles remaining.
         */
        fun deactivateProfile(context: Context, profileId: String): Boolean {
            val prefs = PrefsHelper.getPrefs(context)

            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]") ?: "[]"
            val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]") ?: "[]"

            val result = ProfileDeactivator.computeDeactivation(alarmsJson, blocksJson, profileId)

            prefs.edit()
                .putBoolean(Constants.PREF_IS_BLOCKING, result.hasRemainingProfiles)
                .putStringSet(Constants.PREF_BLOCKED_PACKAGES, if (result.hasRemainingProfiles) result.mergedPackages else emptySet())
                .putStringSet(Constants.PREF_BLOCKED_WEBSITES, if (result.hasRemainingProfiles) result.mergedWebsites else emptySet())
                .putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, result.updatedBlocksJson)
                .putString(Constants.PREF_FAILSAFE_ALARMS, result.updatedAlarmsJson)
                .commit()

            LockdownAccessibilityService.isBlockingActive = result.hasRemainingProfiles
            LockdownAccessibilityService.blockedPackages = if (result.hasRemainingProfiles) result.mergedPackages else emptySet()
            LockdownAccessibilityService.blockedWebsites = if (result.hasRemainingProfiles) result.mergedWebsites else emptySet()

            return result.hasRemainingProfiles
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val profileId = intent.getStringExtra("profileId") ?: return
        AppLogger.d("Failsafe", "Failsafe alarm fired for profile: $profileId")

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
