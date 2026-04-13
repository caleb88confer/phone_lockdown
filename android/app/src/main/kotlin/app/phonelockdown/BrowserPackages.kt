package app.phonelockdown

import android.content.Context

object BrowserPackages {

    val HARDCODED: Set<String> = setOf(
        "com.android.chrome",
        "org.mozilla.firefox",
        "com.brave.browser",
        "com.opera.browser",
        "com.microsoft.emmx",
        "com.samsung.android.app.sbrowser",
        "com.duckduckgo.mobile.browser",
    )

    val URL_BAR_VIEW_IDS: Map<String, String> = mapOf(
        "com.android.chrome" to "com.android.chrome:id/url_bar",
        "com.brave.browser" to "com.brave.browser:id/url_bar",
        "com.microsoft.emmx" to "com.microsoft.emmx:id/url_bar",
        "org.mozilla.firefox" to "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
        "com.duckduckgo.mobile.browser" to "com.duckduckgo.mobile.android:id/omnibarTextInput",
        "com.samsung.android.app.sbrowser" to "com.sec.android.app.sbrowser:id/location_bar_edit_text",
        "com.opera.browser" to "com.opera.browser:id/url_field",
    )

    fun all(context: Context): Set<String> = HARDCODED + getCustom(context)

    fun getCustom(context: Context): Set<String> {
        val prefs = PrefsHelper.getPrefs(context)
        return prefs.getStringSet(Constants.PREF_CUSTOM_BROWSER_PACKAGES, emptySet()) ?: emptySet()
    }

    fun setCustom(context: Context, packages: Set<String>) {
        val prefs = PrefsHelper.getPrefs(context)
        prefs.edit().putStringSet(Constants.PREF_CUSTOM_BROWSER_PACKAGES, packages).commit()
    }
}
