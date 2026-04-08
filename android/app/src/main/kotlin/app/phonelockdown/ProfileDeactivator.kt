package app.phonelockdown

import org.json.JSONArray

data class DeactivationResult(
    val updatedAlarmsJson: String,
    val updatedBlocksJson: String,
    val mergedPackages: Set<String>,
    val mergedWebsites: Set<String>,
    val hasRemainingProfiles: Boolean
)

object ProfileDeactivator {

    fun computeDeactivation(
        alarmsJson: String,
        blocksJson: String,
        profileId: String
    ): DeactivationResult {
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }

        val blocks = JSONArray(blocksJson)
        val updatedBlocks = JSONArray()
        val mergedPackages = mutableSetOf<String>()
        val mergedWebsites = mutableSetOf<String>()

        for (i in 0 until blocks.length()) {
            val obj = blocks.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedBlocks.put(obj)
                val pkgs = obj.getJSONArray("blockedPackages")
                for (j in 0 until pkgs.length()) {
                    mergedPackages.add(pkgs.getString(j))
                }
                val webs = obj.getJSONArray("blockedWebsites")
                for (j in 0 until webs.length()) {
                    mergedWebsites.add(webs.getString(j))
                }
            }
        }

        return DeactivationResult(
            updatedAlarmsJson = updatedAlarms.toString(),
            updatedBlocksJson = updatedBlocks.toString(),
            mergedPackages = mergedPackages,
            mergedWebsites = mergedWebsites,
            hasRemainingProfiles = updatedBlocks.length() > 0
        )
    }
}
