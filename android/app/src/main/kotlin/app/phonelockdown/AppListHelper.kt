package app.phonelockdown

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream

class AppListHelper(private val context: Context) {

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

        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { app -> launchablePackages.contains(app.packageName) }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "appName" to (app.loadLabel(pm)?.toString() ?: app.packageName),
                    "icon" to drawableToBase64(app.loadIcon(pm))
                )
            }
            .sortedBy { (it["appName"] as String).lowercase() }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = drawableToBitmap(drawable)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        val bytes = stream.toByteArray()
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }

        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
