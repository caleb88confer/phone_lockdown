package app.phonelockdown

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray

class ServiceMonitorWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        const val CHANNEL_ID = "lockdown_monitor"
        const val NOTIFICATION_ID = 2001
        const val WORK_NAME = "lockdown_service_monitor"
    }

    override fun doWork(): Result {
        val prefs = PrefsHelper.getPrefs(applicationContext)
        val isBlocking = prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)

        if (!isBlocking) return Result.success()

        // Backup check: expire any overdue failsafe alarms
        checkExpiredFailsafeAlarms(prefs)

        // Re-read isBlocking in case failsafe check cleared it
        if (!prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)) return Result.success()

        val isServiceRunning = isAccessibilityServiceEnabled()
        if (!isServiceRunning) {
            showNotification(
                "Accessibility Service Disabled",
                "The accessibility service was disabled. App blocking is not active. Please re-enable it."
            )
        }

        return Result.success()
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "${applicationContext.packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            applicationContext.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }

    private fun checkExpiredFailsafeAlarms(prefs: android.content.SharedPreferences) {
        try {
            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]") ?: "[]"
            val alarms = JSONArray(alarmsJson)
            val now = System.currentTimeMillis()

            for (i in 0 until alarms.length()) {
                val obj = alarms.getJSONObject(i)
                val alarmTime = obj.getLong("alarmTimeMillis")
                if (now >= alarmTime) {
                    val profileId = obj.getString("profileId")
                    AppLogger.d("Monitor", "Failsafe expired (backup) for profile: $profileId")
                    FailsafeAlarmReceiver.deactivateProfile(applicationContext, profileId)
                }
            }
        } catch (e: Exception) {
            AppLogger.e("Monitor", "Error checking failsafe alarms", e)
        }
    }

    private fun showNotification(title: String, message: String) {
        val notificationManager =
            applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lockdown Monitor",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when blocking service is disabled"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
