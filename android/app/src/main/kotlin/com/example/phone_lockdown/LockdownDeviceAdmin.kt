package com.example.phone_lockdown

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class LockdownDeviceAdmin : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Disabling device admin will allow Phone Lockdown to be uninstalled. Are you sure?"
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}
