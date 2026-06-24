// ============================================================================
// filename: src/core/EcoNetAgentUtils.kt
// destination: EcoNet/src/core/EcoNetAgentUtils.kt
// purpose: Kotlin utilities for AI chat platform integration and research-coding
//          optimization. Provides structured context extraction, KER validation,
//          and agent-capability discovery without external dependencies.
//
// This file is designed to be:
//   - Readable by AI agents for understanding repository capabilities
//   - Executable on JVM/Android for runtime agent interactions
//   - Self-documenting with embedded metadata for RAG pipelines
// ============================================================================

package org.econet.core

/**
 * Represents an ecological plane in the EcoNet constellation.
 * Each plane has specific metrics, thresholds, and safety constraints.
 */
enum class EcologicalPlane(
    val displayName: String,
    val defaultThresholdMin: Double = 0.0,
    val defaultThresholdMax: Double = 1.0,
    val targetValue: Double? = null
) {
    ENERGY("Energy", targetValue = 0.95),
    HYDRAULIC("Hydraulic Systems", targetValue = 0.92),
    CARBON("Carbon Footprint", targetValue = 0.08),
    BIODIVERSITY("Biodiversity Impact", targetValue = 0.90),
    MATERIALS("Materials & Resources", targetValue = 0.88),
    DATA_QUALITY("Data Quality", targetValue = 0.98),
    TOPOLOGY("Network Topology", targetValue = 0.85),
    RESTORATION("Ecological Restoration");

    companion object {
        fun fromString(value: String): EcologicalPlane? =
            entries.find { it.name.equals(value, ignoreCase = true) }

        fun allPlanes(): List<String> = entries.map { it.name }
    }
}

/**
 * KER (Knowledge-Energy-Risk) score container with validation logic.
 * Aligned with EcoNetSchemaShard2026v1 constraints.
 */
data class KERScore(
    val knowledge: Double,
    val energy: Double,
    val risk: Double,
    val timestamp: Long = System.currentTimeMillis(),
    val nodeId: String = "",
    val shardId: String = ""
) {
    init {
        require(knowledge in 0.0..1.0) { "Knowledge must be in [0, 1], got $knowledge" }
        require(energy in 0.0..1.0) { "Energy must be in [0, 1], got $energy" }
        require(risk in 0.0..1.0) { "Risk must be in [0, 1], got $risk" }
    }

    /**
     * Validate against production deployment thresholds.
     * Returns true if scores meet PROD lane requirements.
     */
    fun meetsProductionThresholds(
        kThreshold: Double = 0.95,
        eThreshold: Double = 0.92,
        rThreshold: Double = 0.12
    ): Boolean = knowledge >= kThreshold && energy >= eThreshold && risk <= rThreshold

    /**
     * Check monotonicity against previous scores.
     * K and E should not decrease; R should not increase.
     */
    fun isMonotoneImprovement(previous: KERScore): Boolean =
        knowledge >= previous.knowledge &&
        energy >= previous.energy &&
        risk <= previous.risk

    /**
     * Convert to JSON-like string for agent consumption.
     */
    fun toJson(): String = buildString {
        append("{")
        append("\"k\":$knowledge,")
        append("\"e\":$energy,")
        append("\"r\":$risk,")
        append("\"t\":$timestamp,")
        append("\"node\":\"$nodeId\",")
        append("\"shard\":\"$shardId\"")
        append("}")
    }

    companion object {
        fun fromJson(json: String): KERScore? {
            return try {
                // Simple parsing without external dependencies
                val k = extractDouble(json, "\"k\":") ?: return null
                val e = extractDouble(json, "\"e\":") ?: return null
                val r = extractDouble(json, "\"r\":") ?: return null
                val t = extractLong(json, "\"t\":") ?: System.currentTimeMillis()
                val node = extractString(json, "\"node\":\"") ?: ""
                val shard = extractString(json, "\"shard\":\"") ?: ""
                KERScore(knowledge = k, energy = e, risk = r, timestamp = t, nodeId = node, shardId = shard)
            } catch (e: Exception) {
                null
            }
        }

        private fun extractDouble(json: String, key: String): Double? {
            val start = json.indexOf(key) + key.length
            if (start < key.length) return null
            val end = json.indexOfAny(charArrayOf(',', '}'), start)
            return json.substring(start, end).toDoubleOrNull()
        }

        private fun extractLong(json: String, key: String): Long? {
            val start = json.indexOf(key) + key.length
            if (start < key.length) return null
            val end = json.indexOfAny(charArrayOf(',', '}'), start)
            return json.substring(start, end).toLongOrNull()
        }

        private fun extractString(json: String, key: String): String? {
            val start = json.indexOf(key) + key.length
            if (start < key.length) return null
            val end = json.indexOf('"', start)
            return json.substring(start, end)
        }
    }
}

/**
 * Lyapunov stability check result.
 * Used for validating state transitions in safety-critical systems.
 */
data class LyapunovCheckResult(
    val stable: Boolean,
    val vtBefore: Double,
    val vtAfter: Double,
    val deltaVt: Double,
    val epsilon: Double = 0.01,
    val reason: String = ""
) {
    val isStable: Boolean get() = stable && deltaVt <= epsilon

    companion object {
        fun check(
            vtBefore: Double,
            vtAfter: Double,
            epsilon: Double = 0.01
        ): LyapunovCheckResult {
            val delta = vtAfter - vtBefore
            val stable = delta <= epsilon
            return LyapunovCheckResult(
                stable = stable,
                vtBefore = vtBefore,
                vtAfter = vtAfter,
                deltaVt = delta,
                epsilon = epsilon,
                reason = if (stable) {
                    "Lyapunov stable: ΔV_t = $delta ≤ ε"
                } else {
                    "Lyapunov unstable: ΔV_t = $delta > ε"
                }
            )
        }
    }
}

/**
 * Artifact metadata for AI agent discovery.
 * Mirrors the ai_agent_discovery_index SQL table structure.
 */
data class ArtifactMetadata(
    val artifactPath: String,
    val artifactType: ArtifactType,
    val repoTarget: String,
    val roleBand: RoleBand,
    val laneDefault: LaneDefault,
    val semanticSummary: String,
    val purposeKeywords: List<String>,
    val ecologicalPlanes: List<EcologicalPlane>,
    val agentHints: Map<String, Any?> = emptyMap(),
    val complexityScore: Double = 0.5,
    val criticalityLevel: CriticalityLevel = CriticalityLevel.NORMAL,
    val dependsOnPaths: List<String> = emptyList(),
    val referencedByPaths: List<String> = emptyList()
) {
    enum class ArtifactType { SQL, KOTLIN, JAVA, RUST, CPP, HEADER, LUA, ALN, DOC, CONFIG }
    enum class RoleBand { SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP, EDGESCRIPT }
    enum class LaneDefault { RESEARCH, EXPPROD, PROD, DIAGNOSTIC }
    enum class CriticalityLevel { LOW, NORMAL, HIGH, CRITICAL }

    fun toJson(): String = buildString {
        append("{")
        append("\"path\":\"$artifactPath\",")
        append("\"type\":\"$artifactType\",")
        append("\"repo\":\"$repoTarget\",")
        append("\"role\":\"$roleBand\",")
        append("\"lane\":\"$laneDefault\",")
        append("\"summary\":\"${semanticSummary.replace("\"", "\\\"")}\",")
        append("\"keywords\":[${purposeKeywords.joinToString(",") { "\"$it\"" }}],")
        append("\"planes\":[${ecologicalPlanes.joinToString(",") { "\"${it.name}\"" }}],")
        append("\"complexity\":$complexityScore,")
        append("\"criticality\":\"$criticalityLevel\"")
        append("}")
    }
}

/**
 * Research action template for coding agent automation.
 * Provides pre-validated code generation patterns.
 */
data class ResearchActionTemplate(
    val actionKey: String,
    val actionCategory: ActionCategory,
    val affectedArtifacts: List<String>,
    val estimatedEffort: EffortLevel = EffortLevel.MEDIUM,
    val riskAssessment: String = "",
    val codeTemplate: String? = null,
    val sqlMigration: String? = null,
    val testStub: String? = null,
    val preconditions: List<String> = emptyList(),
    val postconditions: List<String> = emptyList()
) {
    enum class ActionCategory { SCHEMA_MIGRATION, CODE_GENERATION, TEST_CREATION, DOCUMENTATION, VALIDATION }
    enum class EffortLevel { LOW, MEDIUM, HIGH }

    /**
     * Apply template with parameter substitution.
     */
    fun apply(parameters: Map<String, String>): String? {
        return codeTemplate?.let { template ->
            parameters.fold(template) { acc, (key, value) ->
                acc.replace("<$key>", value)
            }
        } ?: sqlMigration?.let { migration ->
            parameters.fold(migration) { acc, (key, value) ->
                acc.replace("<$key>", value)
            }
        }
    }

    /**
     * Validate preconditions before applying action.
     */
    fun checkPreconditions(checker: (String) -> Boolean): Boolean =
        preconditions.all { checker(it) }

    /**
     * Validate postconditions after applying action.
     */
    fun checkPostconditions(checker: (String) -> Boolean): Boolean =
        postconditions.all { checker(it) }
}

/**
 * Agent capability descriptor for AI chat platform integration.
 * Declares what operations an AI agent can safely perform.
 */
data class AgentCapability(
    val capabilityKey: String,
    val capabilityType: CapabilityType,
    val scopeArtifacts: List<String> = emptyList(),
    val scopeTables: List<String> = emptyList(),
    val scopeFunctions: List<String> = emptyList(),
    val constraints: Map<String, Any?> = emptyMap(),
    val requiresReview: Boolean = true,
    val maxBatchSize: Int = 1,
    val outputFormat: String = "TEXT",
    val outputDestination: String? = null,
    val description: String = "",
    val exampleInput: String? = null,
    val exampleOutput: String? = null
) {
    enum class CapabilityType { READ_ONLY, ANALYSIS, GENERATION, VALIDATION, TRANSFORM }

    /**
     * Check if an artifact is within this capability's scope.
     */
    fun isInScope(artifactPath: String): Boolean {
        if (scopeArtifacts.isEmpty()) return true
        return scopeArtifacts.any { pattern ->
            when {
                pattern.endsWith("*") -> artifactPath.startsWith(pattern.dropLast(1))
                pattern.startsWith("**/") -> artifactPath.contains(pattern.drop(3))
                else -> artifactPath == pattern
            }
        }
    }

    /**
     * Generate a constraint validation report.
     */
    fun validateConstraints(context: Map<String, Any?>): ConstraintValidationReport {
        val violations = mutableListOf<String>()
        
        constraints.forEach { (key, value) ->
            when (key) {
                "query_type" -> {
                    if (value == "SELECT" && context["query_type"] != "SELECT") {
                        violations.add("Only SELECT queries allowed")
                    }
                }
                "modifications_prohibited" -> {
                    if (value == true && (context["is_modification"] as? Boolean == true)) {
                        violations.add("Modifications prohibited for this capability")
                    }
                }
                "aggregation_only" -> {
                    if (value == true && (context["is_aggregation"] as? Boolean != true)) {
                        violations.add("Only aggregation queries allowed")
                    }
                }
            }
        }

        return ConstraintValidationReport(
            valid = violations.isEmpty(),
            violations = violations
        )
    }

    data class ConstraintValidationReport(
        val valid: Boolean,
        val violations: List<String>
    )
}

/**
 * Blast radius impact assessment.
 * Used for evaluating the scope of changes or events.
 */
data class BlastRadiusImpact(
    val sourceKind: String,
    val sourceId: String,
    val targetKind: String,
    val targetId: String,
    val impactPlane: EcologicalPlane,
    val impactType: ImpactType,
    val impactScore: Double,
    val impactBand: ImpactBand,
    val radiusMeters: Int? = null,
    val radiusHours: Int? = null,
    val vtSensitivity: Double? = null,
    val evidenceTag: String = "",
    val evidenceSource: String = ""
) {
    enum class ImpactType { LOAD, BUFFER, MAR, SUBSTRATE, SURCHARGE, FOOTPRINT, CONNECTIVITY, OTHER }
    enum class ImpactBand { SAFE, GOLD, HARD, EXCEEDED }

    init {
        require(impactScore in 0.0..1.0) { "Impact score must be in [0, 1]" }
    }

    /**
     * Determine if impact is within acceptable limits.
     */
    fun isAcceptable(): Boolean = impactBand != ImpactBand.EXCEEDED

    /**
     * Get recommended action based on impact band.
     */
    fun recommendedAction(): String = when (impactBand) {
        ImpactBand.SAFE -> "No action required"
        ImpactBand.GOLD -> "Monitor closely"
        ImpactBand.HARD -> "Review and mitigate"
        ImpactBand.EXCEEDED -> "Immediate intervention required"
    }

    companion object {
        fun fromImpactScore(score: Double): ImpactBand = when {
            score < 0.3 -> ImpactBand.SAFE
            score < 0.6 -> ImpactBand.GOLD
            score < 0.9 -> ImpactBand.HARD
            else -> ImpactBand.EXCEEDED
        }
    }
}

/**
 * Utility object for AI agent interactions with the EcoNet repository.
 * Provides static methods for context extraction, validation, and discovery.
 */
object EcoNetAgentUtils {

    /**
     * Extract artifact metadata from a file path.
     * Returns null if the artifact type cannot be determined.
     */
    fun extractArtifactMetadata(filePath: String): ArtifactMetadata? {
        val artifactType = when {
            filePath.endsWith(".sql") -> ArtifactMetadata.ArtifactType.SQL
            filePath.endsWith(".kt") -> ArtifactMetadata.ArtifactType.KOTLIN
            filePath.endsWith(".java") -> ArtifactMetadata.ArtifactType.JAVA
            filePath.endsWith(".rs") -> ArtifactMetadata.ArtifactType.RUST
            filePath.endsWith(".cpp") -> ArtifactMetadata.ArtifactType.CPP
            filePath.endsWith(".hpp") || filePath.endsWith(".h") -> ArtifactMetadata.ArtifactType.HEADER
            filePath.endsWith(".lua") -> ArtifactMetadata.ArtifactType.LUA
            filePath.endsWith(".aln") -> ArtifactMetadata.ArtifactType.ALN
            filePath.endsWith(".md") -> ArtifactMetadata.ArtifactType.DOC
            filePath.endsWith(".json") || filePath.endsWith(".yaml") || filePath.endsWith(".yml") -> 
                ArtifactMetadata.ArtifactType.CONFIG
            else -> return null
        }

        val repoTarget = inferRepoTarget(filePath)
        val roleBand = inferRoleBand(filePath, artifactType)
        val laneDefault = inferLaneDefault(roleBand)

        return ArtifactMetadata(
            artifactPath = filePath,
            artifactType = artifactType,
            repoTarget = repoTarget,
            roleBand = roleBand,
            laneDefault = laneDefault,
            semanticSummary = generateSemanticSummary(filePath, artifactType),
            purposeKeywords = extractPurposeKeywords(filePath, artifactType),
            ecologicalPlanes = inferEcologicalPlanes(filePath),
            complexityScore = estimateComplexity(filePath, artifactType),
            criticalityLevel = determineCriticality(filePath, artifactType)
        )
    }

    /**
     * Validate a KER score transition for monotonicity and Lyapunov stability.
     */
    fun validateKerTransition(
        previous: KERScore,
        current: KERScore,
        vtBefore: Double,
        vtAfter: Double,
        epsilon: Double = 0.01
    ): KerTransitionValidation {
        val monotoneOk = current.isMonotoneImprovement(previous)
        val lyapunovResult = LyapunovCheckResult.check(vtBefore, vtAfter, epsilon)
        
        return KerTransitionValidation(
            valid = monotoneOk && lyapunovResult.isStable,
            monotoneOk = monotoneOk,
            lyapunovOk = lyapunovResult.isStable,
            lyapunovDetails = lyapunovResult,
            recommendations = buildList {
                if (!monotoneOk) {
                    add("KER metrics violate monotonicity constraints")
                }
                if (!lyapunovResult.isStable) {
                    add(lyapunovResult.reason)
                }
            }
        )
    }

    /**
     * Generate a list of available agent capabilities.
     */
    fun getAvailableCapabilities(): List<AgentCapability> = listOf(
        AgentCapability(
            capabilityKey = "read_schema_definitions",
            capabilityType = AgentCapability.CapabilityType.READ_ONLY,
            scopeArtifacts = listOf("db/*.sql"),
            scopeTables = listOf("econet_repo_index", "cybo_workload_ledger", "blastradius_link"),
            constraints = mapOf(
                "query_type" to "SELECT",
                "modifications_prohibited" to true
            ),
            requiresReview = false,
            maxBatchSize = 100,
            outputFormat = "SQL",
            description = "Read-only access to schema definitions for analysis"
        ),
        AgentCapability(
            capabilityKey = "analyze_ker_metrics",
            capabilityType = AgentCapability.CapabilityType.ANALYSIS,
            scopeArtifacts = listOf("db/db_econet_constellation_research_spine.sql"),
            scopeTables = listOf("cybo_workload_ledger", "v_cybo_workload_window"),
            constraints = mapOf(
                "aggregation_only" to true,
                "time_range_required" to true
            ),
            requiresReview = false,
            maxBatchSize = 50,
            outputFormat = "JSON",
            description = "Analyze KER metrics with temporal aggregations"
        ),
        AgentCapability(
            capabilityKey = "validate_ker_monotonicity",
            capabilityType = AgentCapability.CapabilityType.VALIDATION,
            scopeArtifacts = listOf("src/cpp/cyboquatic_guard/*"),
            scopeFunctions = listOf("KerGuard::check_upgrade"),
            constraints = mapOf(
                "input_type" to "KerState",
                "output_type" to "KerGuardResult"
            ),
            requiresReview = false,
            maxBatchSize = 1,
            outputFormat = "JSON",
            description = "Validate KER monotonicity and Lyapunov safety"
        )
    )

    /**
     * Get research action templates for common coding tasks.
     */
    fun getResearchActionTemplates(): List<ResearchActionTemplate> = listOf(
        ResearchActionTemplate(
            actionKey = "add_ker_field_to_ledger",
            actionCategory = ResearchActionTemplate.ActionCategory.SCHEMA_MIGRATION,
            affectedArtifacts = listOf("db/db_econet_constellation_research_spine.sql:cybo_workload_ledger"),
            estimatedEffort = ResearchActionTemplate.EffortLevel.LOW,
            riskAssessment = "Low risk - additive schema change with nullable field",
            sqlMigration = """
                ALTER TABLE cybo_workload_ledger ADD COLUMN <field_name> REAL;
                ALTER TABLE cybo_workload_ledger ADD CONSTRAINT chk_<field_name> 
                    CHECK (<field_name> >= 0.0 AND <field_name> <= 1.0);
            """.trimIndent(),
            preconditions = listOf("table_exists:cybo_workload_ledger", "field_not_exists:<field_name>"),
            postconditions = listOf("field_exists:<field_name>", "constraint_exists:chk_<field_name>")
        ),
        ResearchActionTemplate(
            actionKey = "generate_kotlin_data_class",
            actionCategory = ResearchActionTemplate.ActionCategory.CODE_GENERATION,
            affectedArtifacts = listOf("**/*.kt"),
            estimatedEffort = ResearchActionTemplate.EffortLevel.LOW,
            riskAssessment = "No risk - generates new Kotlin data classes",
            codeTemplate = """
                data class <ClassName>(
                    val <property>: <Type>,
                    // ... additional properties
                ) {
                    fun isValid(): Boolean {
                        return <validation_logic>
                    }
                }
            """.trimIndent(),
            preconditions = listOf("package_exists:<package_name>"),
            postconditions = listOf("file_created:<path>", "compiles:true")
        )
    )

    /**
     * Infer repository target from file path.
     */
    private fun inferRepoTarget(filePath: String): String = when {
        filePath.startsWith("android/") || filePath.startsWith("Cyboquatics-Android/") -> "EcoNet-Android"
        filePath.startsWith("src/") -> "EcoNet-Core"
        filePath.startsWith("db/") || filePath.startsWith(".econet/") -> "EcoNet-DB"
        filePath.startsWith("crates/") -> "EcoNet-Crates"
        else -> "EcoNet"
    }

    /**
     * Infer role band from file path and type.
     */
    private fun inferRoleBand(filePath: String, artifactType: ArtifactMetadata.ArtifactType): ArtifactMetadata.RoleBand = when {
        filePath.contains("/core/") || filePath.contains("actuator") -> ArtifactMetadata.RoleBand.ENGINE
        filePath.contains("/guard/") || filePath.contains("guard") -> ArtifactMetadata.RoleBand.SPINE
        filePath.startsWith("db/") || filePath.startsWith(".econet/") -> ArtifactMetadata.RoleBand.SPINE
        filePath.startsWith("android/") || filePath.startsWith("Cyboquatics-Android/") -> ArtifactMetadata.RoleBand.APP
        filePath.contains("research") -> ArtifactMetadata.RoleBand.RESEARCH
        else -> ArtifactMetadata.RoleBand.SPINE
    }

    /**
     * Infer default lane from role band.
     */
    private fun inferLaneDefault(roleBand: ArtifactMetadata.RoleBand): ArtifactMetadata.LaneDefault = when (roleBand) {
        ArtifactMetadata.RoleBand.RESEARCH -> ArtifactMetadata.LaneDefault.RESEARCH
        ArtifactMetadata.RoleBand.ENGINE -> ArtifactMetadata.LaneDefault.PROD
        ArtifactMetadata.RoleBand.SPINE -> ArtifactMetadata.LaneDefault.RESEARCH
        ArtifactMetadata.RoleBand.APP -> ArtifactMetadata.LaneDefault.PROD
        else -> ArtifactMetadata.LaneDefault.RESEARCH
    }

    /**
     * Generate a semantic summary for an artifact.
     */
    private fun generateSemanticSummary(filePath: String, artifactType: ArtifactMetadata.ArtifactType): String {
        val fileName = filePath.substringAfterLast('/')
        return when {
            artifactType == ArtifactMetadata.ArtifactType.SQL -> 
                "SQL schema definition for $fileName"
            artifactType == ArtifactMetadata.ArtifactType.KOTLIN -> 
                "Kotlin implementation: $fileName"
            artifactType == ArtifactMetadata.ArtifactType.CPP || 
            artifactType == ArtifactMetadata.ArtifactType.HEADER ->
                "C++ ${if (artifactType == ArtifactMetadata.ArtifactType.HEADER) "header" else "implementation"}: $fileName"
            else -> "Repository artifact: $fileName"
        }
    }

    /**
     * Extract purpose keywords from file path and name.
     */
    private fun extractPurposeKeywords(filePath: String, artifactType: ArtifactMetadata.ArtifactType): List<String> {
        val fileName = filePath.substringAfterLast('/').substringBefore('.')
        return fileName.split('_').filter { it.isNotEmpty() }
    }

    /**
     * Infer ecological planes from file content hints in path.
     */
    private fun inferEcologicalPlanes(filePath: String): List<EcologicalPlane> {
        val planes = mutableListOf<EcologicalPlane>()
        
        when {
            filePath.contains("energy") || filePath.contains("power") || filePath.contains("battery") -> 
                planes.add(EcologicalPlane.ENERGY)
            filePath.contains("hydraulic") || filePath.contains("water") || filePath.contains("flow") -> 
                planes.add(EcologicalPlane.HYDRAULIC)
            filePath.contains("carbon") || filePath.contains("emission") -> 
                planes.add(EcologicalPlane.CARBON)
            filePath.contains("bio") || filePath.contains("eco") -> 
                planes.add(EcologicalPlane.BIODIVERSITY)
            filePath.contains("material") || filePath.contains("resource") -> 
                planes.add(EcologicalPlane.MATERIALS)
            filePath.contains("data") || filePath.contains("index") || filePath.contains("schema") -> 
                planes.add(EcologicalPlane.DATA_QUALITY)
            filePath.contains("topology") || filePath.contains("network") || filePath.contains("graph") -> 
                planes.add(EcologicalPlane.TOPOLOGY)
        }
        
        if (filePath.contains("failsafe") || filePath.contains("guard") || filePath.contains("safety")) {
            planes.addAll(listOf(EcologicalPlane.DATA_QUALITY, EcologicalPlane.ENERGY))
        }
        
        return planes.ifEmpty { listOf(EcologicalPlane.DATA_QUALITY) }
    }

    /**
     * Estimate complexity score based on artifact characteristics.
     */
    private fun estimateComplexity(filePath: String, artifactType: ArtifactMetadata.ArtifactType): Double {
        var score = 0.5
        
        // Adjust based on path depth
        val depth = filePath.count { it == '/' }
        score += (depth - 3) * 0.05
        
        // Adjust based on artifact type
        when (artifactType) {
            ArtifactMetadata.ArtifactType.CPP, 
            ArtifactMetadata.ArtifactType.HEADER -> score += 0.15
            ArtifactMetadata.ArtifactType.RUST -> score += 0.1
            ArtifactMetadata.ArtifactType.SQL -> score -= 0.1
            else -> {}
        }
        
        // Safety-critical files are more complex
        if (filePath.contains("failsafe") || filePath.contains("guard") || filePath.contains("safety")) {
            score += 0.2
        }
        
        return score.coerceIn(0.0, 1.0)
    }

    /**
     * Determine criticality level from artifact characteristics.
     */
    private fun determineCriticality(filePath: String, artifactType: ArtifactMetadata.ArtifactType): ArtifactMetadata.CriticalityLevel {
        return when {
            filePath.contains("failsafe") || filePath.contains("guard") || filePath.contains("safety") -> 
                ArtifactMetadata.CriticalityLevel.CRITICAL
            filePath.contains("actuator") || filePath.contains("hardware") -> 
                ArtifactMetadata.CriticalityLevel.HIGH
            filePath.startsWith("db/") && filePath.contains("schema") -> 
                ArtifactMetadata.CriticalityLevel.HIGH
            filePath.startsWith(".econet/") -> 
                ArtifactMetadata.CriticalityLevel.CRITICAL
            else -> 
                ArtifactMetadata.CriticalityLevel.NORMAL
        }
    }
}

/**
 * Validation result for KER state transitions.
 */
data class KerTransitionValidation(
    val valid: Boolean,
    val monotoneOk: Boolean,
    val lyapunovOk: Boolean,
    val lyapunovDetails: LyapunovCheckResult,
    val recommendations: List<String>
) {
    fun toJson(): String = buildString {
        append("{")
        append("\"valid\":$valid,")
        append("\"monotoneOk\":$monotoneOk,")
        append("\"lyapunovOk\":$lyapunovOk,")
        append("\"deltaVt\":${lyapunovDetails.deltaVt},")
        append("\"recommendations\":[${recommendations.joinToString(",") { "\"$it\"" }}]")
        append("}")
    }
}
