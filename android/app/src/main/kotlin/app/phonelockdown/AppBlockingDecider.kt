package app.phonelockdown

object AppBlockingDecider {

    private val SYSTEM_PACKAGES = setOf(
        "com.android.systemui",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher"
    )

    fun isSystemPackage(packageName: String, ownPackageName: String): Boolean {
        return packageName == ownPackageName || packageName in SYSTEM_PACKAGES
    }

    fun shouldBlock(
        packageName: String,
        isBlockingActive: Boolean,
        blockedPackages: Set<String>,
        ownPackageName: String
    ): Boolean {
        if (!isBlockingActive) return false
        if (isSystemPackage(packageName, ownPackageName)) return false
        return packageName in blockedPackages
    }
}
