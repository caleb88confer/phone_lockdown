package app.phonelockdown

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

class AppListHelper(private val context: Context) {

    private val iconCacheManager = IconCacheManager(context.cacheDir)

    fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager

        // Query all launcher activities in a single batch call
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launchablePackages = pm.queryIntentActivities(launcherIntent, 0)
            .map { it.activityInfo.packageName }
            .filter { it != context.packageName }
            .toSet()

        // Clean up cached icons for uninstalled apps
        iconCacheManager.cleanStaleCacheEntries(launchablePackages)

        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { app -> launchablePackages.contains(app.packageName) }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "appName" to (app.loadLabel(pm)?.toString() ?: app.packageName),
                    "iconPath" to iconCacheManager.getIconPath(app.packageName, app.loadIcon(pm))
                )
            }
            .sortedBy { (it["appName"] as String).lowercase() }
    }
}
