package app.phonelockdown

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.provider.Settings

class PermissionManager(private val context: Context) {

    fun checkPermissions(): Map<String, Boolean> {
        return mapOf(
            "accessibility" to isAccessibilityServiceEnabled(),
            "deviceAdmin" to isDeviceAdminEnabled(),
            "vpn" to (VpnService.prepare(context) == null),
        )
    }

    fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "${context.packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }

    fun isDeviceAdminEnabled(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, LockdownDeviceAdmin::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            val serviceName = "${context.packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
            val bundle = android.os.Bundle()
            bundle.putString(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:show_fragment_args", bundle)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun requestDeviceAdmin() {
        val adminComponent = ComponentName(context, LockdownDeviceAdmin::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Phone Lockdown needs device admin to prevent uninstallation while blocking is active."
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
