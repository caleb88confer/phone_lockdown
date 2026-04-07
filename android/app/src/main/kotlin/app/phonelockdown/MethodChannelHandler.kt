package app.phonelockdown

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodChannelHandler(
    private val activity: Activity,
    private val permissionManager: PermissionManager,
    private val vpnController: VpnController,
    private val blockingStateManager: BlockingStateManager,
    private val appListHelper: AppListHelper,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                result.success(appListHelper.getInstalledApps())
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
            "prepareVpn" -> {
                vpnController.prepareVpn(activity, result)
            }
            "startVpn" -> {
                vpnController.startVpnService()
                result.success(null)
            }
            "stopVpn" -> {
                vpnController.stopVpnService()
                result.success(null)
            }
            "isVpnActive" -> {
                result.success(vpnController.isVpnActive())
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
