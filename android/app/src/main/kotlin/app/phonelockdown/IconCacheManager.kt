package app.phonelockdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.File
import java.io.FileOutputStream

class IconCacheManager(private val cacheDir: File) {

    private val iconDir = File(cacheDir, "app_icons")

    init {
        if (!iconDir.exists()) {
            iconDir.mkdirs()
        }
    }

    /**
     * Returns the file path for the cached icon. If the icon is not cached,
     * renders the drawable to a PNG file and returns that path.
     */
    fun getIconPath(packageName: String, drawable: Drawable): String {
        val iconFile = File(iconDir, "$packageName.png")
        if (iconFile.exists()) {
            return iconFile.absolutePath
        }

        val bitmap = drawableToBitmap(drawable)
        FileOutputStream(iconFile).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        }
        return iconFile.absolutePath
    }

    /**
     * Removes cached icons for packages that are no longer installed.
     */
    fun cleanStaleCacheEntries(currentPackageNames: Set<String>) {
        val cachedFiles = iconDir.listFiles() ?: return
        for (file in cachedFiles) {
            val cachedPackage = file.nameWithoutExtension
            if (cachedPackage !in currentPackageNames) {
                file.delete()
            }
        }
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
