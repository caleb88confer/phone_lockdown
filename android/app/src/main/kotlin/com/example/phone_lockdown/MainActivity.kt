package com.example.phone_lockdown

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.phone_lockdown/blocker"
    private var pendingVpnResult: MethodChannel.Result? = null

    companion object {
        private const val VPN_REQUEST_CODE = 1001
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        scheduleServiceMonitor()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        val helper = AppListHelper(applicationContext)
                        result.success(helper.getInstalledApps())
                    }
                    "checkPermissions" -> {
                        result.success(checkPermissions())
                    }
                    "updateBlockingState" -> {
                        val isBlocking = call.argument<Boolean>("isBlocking") ?: false
                        val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                        val websites = call.argument<List<String>>("blockedWebsites") ?: emptyList()
                        val activeProfileBlocks = call.argument<List<Map<String, Any>>>("activeProfileBlocks")
                        updateBlockingState(isBlocking, packages, websites, activeProfileBlocks)
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    "openUsageStatsSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "requestDeviceAdmin" -> {
                        requestDeviceAdmin(result)
                    }
                    "prepareVpn" -> {
                        prepareVpn(result)
                    }
                    "startVpn" -> {
                        startVpnService()
                        result.success(null)
                    }
                    "stopVpn" -> {
                        stopVpnService()
                        result.success(null)
                    }
                    "isVpnActive" -> {
                        result.success(LockdownVpnService.instance != null)
                    }
                    "scheduleFailsafeAlarm" -> {
                        val profileId = call.argument<String>("profileId") ?: ""
                        val failsafeMillis = call.argument<Int>("failsafeMillis") ?: 0
                        scheduleFailsafeAlarm(profileId, failsafeMillis.toLong())
                        result.success(null)
                    }
                    "cancelFailsafeAlarm" -> {
                        val profileId = call.argument<String>("profileId") ?: ""
                        cancelFailsafeAlarm(profileId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkPermissions(): Map<String, Boolean> {
        val accessibilityEnabled = isAccessibilityServiceEnabled()
        val deviceAdminEnabled = isDeviceAdminEnabled()
        val vpnPrepared = VpnService.prepare(this) == null
        return mapOf(
            "accessibility" to accessibilityEnabled,
            "deviceAdmin" to deviceAdminEnabled,
            "vpn" to vpnPrepared,
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/${LockdownAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }

    private fun isDeviceAdminEnabled(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, LockdownDeviceAdmin::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    private fun updateBlockingState(
        isBlocking: Boolean,
        packages: List<String>,
        websites: List<String>,
        activeProfileBlocks: List<Map<String, Any>>? = null
    ) {
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
            .putBoolean("isBlocking", isBlocking)
            .putStringSet("blockedPackages", packages.toSet())
            .putStringSet("blockedWebsites", websites.toSet())

        // Store per-profile block data for FailsafeAlarmReceiver to recompute
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
            editor.putString("activeProfileBlocks", jsonArray.toString())
        }

        editor.apply()

        LockdownAccessibilityService.isBlockingActive = isBlocking
        LockdownAccessibilityService.blockedPackages = packages.toSet()
        LockdownAccessibilityService.blockedWebsites = websites.toSet()

        // Manage VPN service based on blocking state and website list
        if (isBlocking && websites.isNotEmpty()) {
            LockdownVpnService.blockedWebsites = websites.toSet()
            if (LockdownVpnService.instance == null && VpnService.prepare(this) == null) {
                startVpnService()
            }
        } else {
            stopVpnService()
        }
    }

    private fun scheduleFailsafeAlarm(profileId: String, failsafeMillis: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, FailsafeAlarmReceiver::class.java).apply {
            putExtra("profileId", profileId)
        }
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTime = System.currentTimeMillis() + failsafeMillis

        // Store alarm data for ServiceMonitorWorker backup check
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
        val alarms = JSONArray(alarmsJson)
        // Remove existing alarm for this profile
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
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        } catch (e: SecurityException) {
            // Fallback for devices that don't allow exact alarms
            Log.w(TAG, "Exact alarm not allowed, using inexact alarm", e)
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }

    private fun cancelFailsafeAlarm(profileId: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, FailsafeAlarmReceiver::class.java)
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)

        // Remove from stored alarms
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            // Already consented
            result.success(true)
        } else {
            pendingVpnResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE) {
            val approved = resultCode == Activity.RESULT_OK
            pendingVpnResult?.success(approved)
            pendingVpnResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun startVpnService() {
        try {
            val intent = Intent(this, LockdownVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN service", e)
        }
    }

    private fun stopVpnService() {
        try {
            val intent = Intent(this, LockdownVpnService::class.java).apply {
                action = "STOP"
            }
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop VPN service", e)
        }
    }

    private fun requestDeviceAdmin(result: MethodChannel.Result) {
        val adminComponent = ComponentName(this, LockdownDeviceAdmin::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Phone Lockdown needs device admin to prevent uninstallation while blocking is active."
            )
        }
        startActivity(intent)
        result.success(null)
    }

    private fun openAccessibilitySettings() {
        // Try to open the specific service settings page directly
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            val serviceName = "${packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
            val bundle = android.os.Bundle()
            bundle.putString(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:show_fragment_args", bundle)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general accessibility settings
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
    }

    private fun scheduleServiceMonitor() {
        val workRequest = PeriodicWorkRequestBuilder<ServiceMonitorWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            ServiceMonitorWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}
