package app.phonelockdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

class BlockingStateManager(
    private val context: Context,
) {
    fun updateBlockingState(
        isBlocking: Boolean,
        packages: List<String>,
        websites: List<String>,
        activeProfileBlocks: List<Map<String, Any>>? = null
    ) {
        val prefs = PrefsHelper.getPrefs(context)
        val editor = prefs.edit()
            .putBoolean(Constants.PREF_IS_BLOCKING, isBlocking)
            .putStringSet(Constants.PREF_BLOCKED_PACKAGES, packages.toSet())
            .putStringSet(Constants.PREF_BLOCKED_WEBSITES, websites.toSet())

        if (activeProfileBlocks != null) {
            val jsonArray = JSONArray()
            for (block in activeProfileBlocks) {
                val obj = JSONObject()
                obj.put("profileId", block["profileId"])
                val pkgArray = JSONArray()
                @Suppress("UNCHECKED_CAST")
                for (pkg in (block["blockedPackages"] as? List<String>) ?: emptyList()) {
                    pkgArray.put(pkg)
                }
                obj.put("blockedPackages", pkgArray)
                val webArray = JSONArray()
                @Suppress("UNCHECKED_CAST")
                for (web in (block["blockedWebsites"] as? List<String>) ?: emptyList()) {
                    webArray.put(web)
                }
                obj.put("blockedWebsites", webArray)
                jsonArray.put(obj)
            }
            editor.putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, jsonArray.toString())
        }

        editor.commit()

        LockdownAccessibilityService.isBlockingActive = isBlocking
        LockdownAccessibilityService.blockedPackages = packages.toSet()
        LockdownAccessibilityService.blockedWebsites = websites.toSet()
    }

    fun getEnforcementState(): Map<String, Any> {
        val prefs = PrefsHelper.getPrefs(context)
        val isBlocking = prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)
        val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]")
        val blocks = JSONArray(blocksJson)
        val activeProfileIds = mutableListOf<String>()
        for (i in 0 until blocks.length()) {
            activeProfileIds.add(blocks.getJSONObject(i).getString("profileId"))
        }
        return mapOf(
            "isBlocking" to isBlocking,
            "activeProfileIds" to activeProfileIds,
        )
    }

    fun scheduleFailsafeAlarm(profileId: String, failsafeMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, FailsafeAlarmReceiver::class.java).apply {
            putExtra("profileId", profileId)
        }
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTime = System.currentTimeMillis() + failsafeMillis

        val prefs = PrefsHelper.getPrefs(context)
        val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }
        val newAlarm = JSONObject()
        newAlarm.put("profileId", profileId)
        newAlarm.put("alarmTimeMillis", triggerTime)
        updatedAlarms.put(newAlarm)
        prefs.edit().putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString()).apply()

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        } catch (e: SecurityException) {
            AppLogger.w("BlockingState", "Exact alarm not allowed, using inexact alarm", e)
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }

    fun cancelFailsafeAlarm(profileId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, FailsafeAlarmReceiver::class.java)
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)

        val prefs = PrefsHelper.getPrefs(context)
        val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }
        prefs.edit().putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString()).apply()
    }
}
