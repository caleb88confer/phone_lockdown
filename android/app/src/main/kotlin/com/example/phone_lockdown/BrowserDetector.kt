package com.example.phone_lockdown

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

class BrowserDetector(private val context: Context) {

    fun getInstalledBrowserPackages(): Set<String> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
        val resolveInfos = context.packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )
        return resolveInfos.map { it.activityInfo.packageName }.toSet()
    }

    companion object {
        // Known URL bar resource IDs for popular browsers
        val URL_BAR_IDS = mapOf(
            "com.android.chrome" to listOf(
                "com.android.chrome:id/url_bar",
                "com.android.chrome:id/search_box_text"
            ),
            "org.mozilla.firefox" to listOf(
                "org.mozilla.firefox:id/url_bar_title",
                "org.mozilla.firefox:id/mozac_browser_toolbar_url_view"
            ),
            "com.brave.browser" to listOf(
                "com.brave.browser:id/url_bar",
                "com.brave.browser:id/search_box_text"
            ),
            "com.opera.browser" to listOf(
                "com.opera.browser:id/url_field"
            ),
            "com.microsoft.emmx" to listOf(
                "com.microsoft.emmx:id/url_bar",
                "com.microsoft.emmx:id/search_box_text"
            ),
            "com.sec.android.app.sbrowser" to listOf(
                "com.sec.android.app.sbrowser:id/location_bar_edit_text"
            ),
        )
    }
}
