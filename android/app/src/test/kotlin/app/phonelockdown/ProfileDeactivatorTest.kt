package app.phonelockdown

import org.json.JSONArray
import org.json.JSONObject
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class ProfileDeactivatorTest {

    private fun buildBlocksJson(vararg profiles: Triple<String, List<String>, List<String>>): String {
        val arr = JSONArray()
        for ((id, pkgs, webs) in profiles) {
            val obj = JSONObject()
            obj.put("profileId", id)
            obj.put("blockedPackages", JSONArray(pkgs))
            obj.put("blockedWebsites", JSONArray(webs))
            arr.put(obj)
        }
        return arr.toString()
    }

    private fun buildAlarmsJson(vararg profileIds: String): String {
        val arr = JSONArray()
        for (id in profileIds) {
            val obj = JSONObject()
            obj.put("profileId", id)
            obj.put("alarmTimeMillis", System.currentTimeMillis() + 60000)
            arr.put(obj)
        }
        return arr.toString()
    }

    @Test
    fun `single profile removed clears everything`() {
        val blocks = buildBlocksJson(Triple("p1", listOf("com.app.a"), listOf("example.com")))
        val alarms = buildAlarmsJson("p1")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p1")

        assertFalse(result.hasRemainingProfiles)
        assertTrue(result.mergedPackages.isEmpty())
        assertTrue(result.mergedWebsites.isEmpty())
        assertEquals(0, JSONArray(result.updatedBlocksJson).length())
        assertEquals(0, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `one of two profiles removed keeps remaining profile data`() {
        val blocks = buildBlocksJson(
            Triple("p1", listOf("com.app.a"), listOf("a.com")),
            Triple("p2", listOf("com.app.b"), listOf("b.com"))
        )
        val alarms = buildAlarmsJson("p1", "p2")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p1")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.b"), result.mergedPackages)
        assertEquals(setOf("b.com"), result.mergedWebsites)
        assertEquals(1, JSONArray(result.updatedBlocksJson).length())
        assertEquals(1, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `three profiles middle removed merges remaining two`() {
        val blocks = buildBlocksJson(
            Triple("p1", listOf("com.app.a"), listOf("a.com")),
            Triple("p2", listOf("com.app.b"), listOf("b.com")),
            Triple("p3", listOf("com.app.c"), listOf("c.com"))
        )
        val alarms = buildAlarmsJson("p1", "p2", "p3")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "p2")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.a", "com.app.c"), result.mergedPackages)
        assertEquals(setOf("a.com", "c.com"), result.mergedWebsites)
        assertEquals(2, JSONArray(result.updatedBlocksJson).length())
        assertEquals(2, JSONArray(result.updatedAlarmsJson).length())
    }

    @Test
    fun `unknown profile id is a no-op`() {
        val blocks = buildBlocksJson(Triple("p1", listOf("com.app.a"), listOf("a.com")))
        val alarms = buildAlarmsJson("p1")

        val result = ProfileDeactivator.computeDeactivation(alarms, blocks, "unknown")

        assertTrue(result.hasRemainingProfiles)
        assertEquals(setOf("com.app.a"), result.mergedPackages)
        assertEquals(setOf("a.com"), result.mergedWebsites)
    }

    @Test
    fun `empty alarms and blocks json is a no-op`() {
        val result = ProfileDeactivator.computeDeactivation("[]", "[]", "p1")

        assertFalse(result.hasRemainingProfiles)
        assertTrue(result.mergedPackages.isEmpty())
        assertTrue(result.mergedWebsites.isEmpty())
    }
}
