package app.phonelockdown

import android.content.Context
import android.content.Intent
import android.net.Uri

class BrowserListHelper(private val context: Context) {

    private val iconCacheManager = IconCacheManager(context.cacheDir)

    fun getInstalledBrowsers(): List<Map<String, Any>> {
        val pm = context.packageManager

        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse("http://example.com"))
        val resolveInfos = pm.queryIntentActivities(viewIntent, 0)

        val seenPackages = mutableSetOf<String>()
        val browsers = mutableListOf<Map<String, Any>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName ?: continue
            if (pkg == context.packageName) continue
            if (pkg in BrowserPackages.HARDCODED) continue
            if (!seenPackages.add(pkg)) continue

            val appName = info.loadLabel(pm)?.toString() ?: pkg
            val iconPath = iconCacheManager.getIconPath(pkg, info.loadIcon(pm))

            browsers.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "iconPath" to iconPath,
                )
            )
        }

        return browsers.sortedBy { (it["appName"] as String).lowercase() }
    }
}
