package com.example.phone_lockdown

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class VpnController(private val context: Context) {

    companion object {
        const val VPN_REQUEST_CODE = 1001
        private const val TAG = "VpnController"
    }

    var pendingVpnResult: MethodChannel.Result? = null

    fun prepareVpn(activity: Activity, result: MethodChannel.Result) {
        val intent = VpnService.prepare(activity)
        if (intent == null) {
            result.success(true)
        } else {
            pendingVpnResult = result
            activity.startActivityForResult(intent, VPN_REQUEST_CODE)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            val approved = resultCode == Activity.RESULT_OK
            pendingVpnResult?.success(approved)
            pendingVpnResult = null
            return true
        }
        return false
    }

    fun startVpnService() {
        try {
            val intent = Intent(context, LockdownVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN service", e)
        }
    }

    fun stopVpnService() {
        try {
            val intent = Intent(context, LockdownVpnService::class.java).apply {
                action = "STOP"
            }
            context.startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop VPN service", e)
        }
    }

    fun isVpnActive(): Boolean {
        return LockdownVpnService.instance != null
    }
}
