package com.example.phone_lockdown

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.phone_lockdown/blocker"

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
                        updateBlockingState(isBlocking, packages, websites)
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openUsageStatsSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "requestDeviceAdmin" -> {
                        requestDeviceAdmin(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkPermissions(): Map<String, Boolean> {
        val accessibilityEnabled = isAccessibilityServiceEnabled()
        val deviceAdminEnabled = isDeviceAdminEnabled()
        return mapOf(
            "accessibility" to accessibilityEnabled,
            "deviceAdmin" to deviceAdminEnabled,
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
        websites: List<String>
    ) {
        val prefs = getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("isBlocking", isBlocking)
            .putStringSet("blockedPackages", packages.toSet())
            .putStringSet("blockedWebsites", websites.toSet())
            .apply()

        LockdownAccessibilityService.isBlockingActive = isBlocking
        LockdownAccessibilityService.blockedPackages = packages.toSet()
        LockdownAccessibilityService.blockedWebsites = websites.toSet()
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
