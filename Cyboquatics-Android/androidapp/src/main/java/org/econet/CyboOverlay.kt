// filename: androidapp/src/main/java/org/econet/CyboOverlay.kt
// destination: Cyboquatics-Android/androidapp/src/main/java/org/econet/CyboOverlay.kt

package org.econet

object CyboOverlay {

    init {
        // Adjust to match your cdylib name produced from eco_restoration_shard
        System.loadLibrary("eco_restoration_shard")
    }

    @JvmStatic
    external fun econet_get_ker_targets(dbPath: String, repoName: String): String?

    @JvmStatic
    external fun econet_get_blast_radius_for_node(dbPath: String, nodeId: String): String?

    @JvmStatic
    external fun econet_get_workload_trends_for_node(dbPath: String, nodeId: String): String?

    fun kerTargets(dbPath: String, repoName: String): String? {
        return econet_get_ker_targets(dbPath, repoName)
    }

    fun blastRadius(dbPath: String, nodeId: String): String? {
        return econet_get_blast_radius_for_node(dbPath, nodeId)
    }

    fun workloadTrends(dbPath: String, nodeId: String): String? {
        return econet_get_workload_trends_for_node(dbPath, nodeId)
    }
}
