package app.phonelockdown

object BrowserPackages {

    val ALL: Set<String> = setOf(
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
}
