package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class AppBlockingDeciderTest {

    private val ownPackage = "app.phonelockdown"

    @Test
    fun `shouldBlock returns true for blocked package when active`() {
        assertTrue(
            AppBlockingDecider.shouldBlock("com.blocked.app", true, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for unblocked package when active`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.allowed.app", true, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for blocked package when inactive`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.blocked.app", false, setOf("com.blocked.app"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for own package`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("app.phonelockdown", true, setOf("app.phonelockdown"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for systemui`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.systemui", true, setOf("com.android.systemui"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for launcher`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.launcher", true, setOf("com.android.launcher"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for launcher3`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.android.launcher3", true, setOf("com.android.launcher3"), ownPackage)
        )
    }

    @Test
    fun `shouldBlock returns false for nexuslauncher`() {
        assertFalse(
            AppBlockingDecider.shouldBlock(
                "com.google.android.apps.nexuslauncher", true,
                setOf("com.google.android.apps.nexuslauncher"), ownPackage
            )
        )
    }

    @Test
    fun `shouldBlock returns false for empty blocked set`() {
        assertFalse(
            AppBlockingDecider.shouldBlock("com.some.app", true, emptySet(), ownPackage)
        )
    }

    @Test
    fun `isSystemPackage returns true for all system packages`() {
        val systemPkgs = listOf(
            "app.phonelockdown",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher"
        )
        for (pkg in systemPkgs) {
            assertTrue(AppBlockingDecider.isSystemPackage(pkg, ownPackage), "Expected $pkg to be system package")
        }
    }

    @Test
    fun `isSystemPackage returns false for regular apps`() {
        assertFalse(AppBlockingDecider.isSystemPackage("com.instagram.android", ownPackage))
        assertFalse(AppBlockingDecider.isSystemPackage("com.twitter.android", ownPackage))
    }
}
