package app.phonelockdown

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodChannelHandler(
    private val permissionManager: PermissionManager,
    private val blockingStateManager: BlockingStateManager,
    private val appListHelper: AppListHelper,
    private val browserListHelper: BrowserListHelper,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                result.success(appListHelper.getInstalledApps())
            }
            "getInstalledBrowsers" -> {
                result.success(browserListHelper.getInstalledBrowsers())
            }
            "getCustomBrowsers" -> {
                result.success(blockingStateManager.getCustomBrowsers())
            }
            "updateCustomBrowsers" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                blockingStateManager.updateCustomBrowsers(packages)
                result.success(null)
            }
            "checkPermissions" -> {
                result.success(permissionManager.checkPermissions())
            }
            "updateBlockingState" -> {
                val isBlocking = call.argument<Boolean>("isBlocking") ?: false
                val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                val websites = call.argument<List<String>>("blockedWebsites") ?: emptyList()
                val activeProfileBlocks = call.argument<List<Map<String, Any>>>("activeProfileBlocks")
                blockingStateManager.updateBlockingState(isBlocking, packages, websites, activeProfileBlocks)
                result.success(null)
            }
            "getEnforcementState" -> {
                result.success(blockingStateManager.getEnforcementState())
            }
            "openAccessibilitySettings" -> {
                permissionManager.openAccessibilitySettings()
                result.success(null)
            }
            "openUsageStatsSettings" -> {
                permissionManager.openUsageStatsSettings()
                result.success(null)
            }
            "requestDeviceAdmin" -> {
                permissionManager.requestDeviceAdmin()
                result.success(null)
            }
            "scheduleFailsafeAlarm" -> {
                val profileId = call.argument<String>("profileId") ?: ""
                val failsafeMillis = call.argument<Int>("failsafeMillis") ?: 0
                blockingStateManager.scheduleFailsafeAlarm(profileId, failsafeMillis.toLong())
                result.success(null)
            }
            "cancelFailsafeAlarm" -> {
                val profileId = call.argument<String>("profileId") ?: ""
                blockingStateManager.cancelFailsafeAlarm(profileId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
