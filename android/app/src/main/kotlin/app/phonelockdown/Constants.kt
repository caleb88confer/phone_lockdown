package app.phonelockdown

object Constants {
    // SharedPreferences keys
    const val PREF_IS_BLOCKING = "isBlocking"
    const val PREF_BLOCKED_PACKAGES = "blockedPackages"
    const val PREF_BLOCKED_WEBSITES = "blockedWebsites"
    const val PREF_ACTIVE_PROFILE_BLOCKS = "activeProfileBlocks"
    const val PREF_FAILSAFE_ALARMS = "failsafeAlarms"
    const val PREF_CUSTOM_BROWSER_PACKAGES = "customBrowserPackages"

    // Method channel
    const val METHOD_CHANNEL = "app.phonelockdown/blocker"
}
