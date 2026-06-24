// ============================================================================
// filename: src/core/EcoNetAgentUtils.java
// destination: EcoNet/src/core/EcoNetAgentUtils.java
// purpose: Java utilities for AI chat platform integration and research-coding
//          optimization. Provides interoperability layer for JVM-based agents,
//          structured context extraction, and KER validation services.
//
// This file is designed to be:
//   - Compatible with Java 8+ for maximum platform support
//   - Self-documenting with embedded metadata for RAG pipelines
//   - Interoperable with Kotlin code via clean FFI boundaries
//   - Readable by AI agents for understanding repository capabilities
// ============================================================================

package org.econet.core;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Ecological plane enumeration representing the different dimensions of
 * environmental and system health monitored by EcoNet.
 */
public enum EcologicalPlane {
    ENERGY("Energy", 0.0, 1.0, 0.95),
    HYDRAULIC("Hydraulic Systems", 0.0, 1.0, 0.92),
    CARBON("Carbon Footprint", 0.0, 1.0, 0.08),
    BIODIVERSITY("Biodiversity Impact", 0.0, 1.0, 0.90),
    MATERIALS("Materials & Resources", 0.0, 1.0, 0.88),
    DATA_QUALITY("Data Quality", 0.0, 1.0, 0.98),
    TOPOLOGY("Network Topology", 0.0, 1.0, 0.85),
    RESTORATION("Ecological Restoration", 0.0, 1.0, null);

    private final String displayName;
    private final double thresholdMin;
    private final double thresholdMax;
    private final Double targetValue;

    EcologicalPlane(String displayName, double thresholdMin, double thresholdMax, Double targetValue) {
        this.displayName = displayName;
        this.thresholdMin = thresholdMin;
        this.thresholdMax = thresholdMax;
        this.targetValue = targetValue;
    }

    public String getDisplayName() { return displayName; }
    public double getThresholdMin() { return thresholdMin; }
    public double getThresholdMax() { return thresholdMax; }
    public Optional<Double> getTargetValue() { return Optional.ofNullable(targetValue); }

    public static Optional<EcologicalPlane> fromString(String value) {
        for (EcologicalPlane plane : values()) {
            if (plane.name().equalsIgnoreCase(value)) {
                return Optional.of(plane);
            }
        }
        return Optional.empty();
    }

    public static List<String> getAllPlanes() {
        List<String> planes = new ArrayList<>();
        for (EcologicalPlane plane : values()) {
            planes.add(plane.name());
        }
        return planes;
    }
}

/**
 * KER (Knowledge-Energy-Risk) score container with validation logic.
 * Aligned with EcoNetSchemaShard2026v1 constraints.
 */
public class KERScore {
    private final double knowledge;
    private final double energy;
    private final double risk;
    private final long timestamp;
    private final String nodeId;
    private final String shardId;

    public KERScore(double knowledge, double energy, double risk, long timestamp, String nodeId, String shardId) {
        if (knowledge < 0.0 || knowledge > 1.0) {
            throw new IllegalArgumentException("Knowledge must be in [0, 1], got " + knowledge);
        }
        if (energy < 0.0 || energy > 1.0) {
            throw new IllegalArgumentException("Energy must be in [0, 1], got " + energy);
        }
        if (risk < 0.0 || risk > 1.0) {
            throw new IllegalArgumentException("Risk must be in [0, 1], got " + risk);
        }
        
        this.knowledge = knowledge;
        this.energy = energy;
        this.risk = risk;
        this.timestamp = timestamp;
        this.nodeId = nodeId != null ? nodeId : "";
        this.shardId = shardId != null ? shardId : "";
    }

    public KERScore(double knowledge, double energy, double risk) {
        this(knowledge, energy, risk, System.currentTimeMillis(), "", "");
    }

    public double getKnowledge() { return knowledge; }
    public double getEnergy() { return energy; }
    public double getRisk() { return risk; }
    public long getTimestamp() { return timestamp; }
    public String getNodeId() { return nodeId; }
    public String getShardId() { return shardId; }

    /**
     * Validate against production deployment thresholds.
     */
    public boolean meetsProductionThresholds() {
        return meetsProductionThresholds(0.95, 0.92, 0.12);
    }

    public boolean meetsProductionThresholds(double kThreshold, double eThreshold, double rThreshold) {
        return knowledge >= kThreshold && energy >= eThreshold && risk <= rThreshold;
    }

    /**
     * Check monotonicity against previous scores.
     */
    public boolean isMonotoneImprovement(KERScore previous) {
        return this.knowledge >= previous.knowledge &&
               this.energy >= previous.energy &&
               this.risk <= previous.risk;
    }

    /**
     * Convert to JSON string for agent consumption.
     */
    public String toJson() {
        return String.format(
            "{\"k\":%.4f,\"e\":%.4f,\"r\":%.4f,\"t\":%d,\"node\":\"%s\",\"shard\":\"%s\"}",
            knowledge, energy, risk, timestamp, nodeId, shardId
        );
    }

    /**
     * Parse KERScore from JSON string.
     */
    public static Optional<KERScore> fromJson(String json) {
        try {
            Double k = extractDouble(json, "\"k\":");
            Double e = extractDouble(json, "\"e\":");
            Double r = extractDouble(json, "\"r\":");
            Long t = extractLong(json, "\"t\":");
            String node = extractString(json, "\"node\":\"");
            String shard = extractString(json, "\"shard\":\"");

            if (k == null || e == null || r == null) {
                return Optional.empty();
            }

            return Optional.of(new KERScore(
                k, e, r,
                t != null ? t : System.currentTimeMillis(),
                node != null ? node : "",
                shard != null ? shard : ""
            ));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    private static Double extractDouble(String json, String key) {
        Pattern pattern = Pattern.compile(Pattern.quote(key) + "([\\d.]+)");
        Matcher matcher = pattern.matcher(json);
        if (matcher.find()) {
            return Double.parseDouble(matcher.group(1));
        }
        return null;
    }

    private static Long extractLong(String json, String key) {
        Pattern pattern = Pattern.compile(Pattern.quote(key) + "(\\d+)");
        Matcher matcher = pattern.matcher(json);
        if (matcher.find()) {
            return Long.parseLong(matcher.group(1));
        }
        return null;
    }

    private static String extractString(String json, String key) {
        Pattern pattern = Pattern.compile(Pattern.quote(key) + "([^\"]*)");
        Matcher matcher = pattern.matcher(json);
        if (matcher.find()) {
            return matcher.group(1);
        }
        return null;
    }

    @Override
    public String toString() {
        return toJson();
    }
}

/**
 * Lyapunov stability check result.
 */
public class LyapunovCheckResult {
    private final boolean stable;
    private final double vtBefore;
    private final double vtAfter;
    private final double deltaVt;
    private final double epsilon;
    private final String reason;

    private LyapunovCheckResult(boolean stable, double vtBefore, double vtAfter, 
                                 double deltaVt, double epsilon, String reason) {
        this.stable = stable;
        this.vtBefore = vtBefore;
        this.vtAfter = vtAfter;
        this.deltaVt = deltaVt;
        this.epsilon = epsilon;
        this.reason = reason;
    }

    public boolean isStable() { return stable && deltaVt <= epsilon; }
    public boolean isStableRaw() { return stable; }
    public double getVtBefore() { return vtBefore; }
    public double getVtAfter() { return vtAfter; }
    public double getDeltaVt() { return deltaVt; }
    public double getEpsilon() { return epsilon; }
    public String getReason() { return reason; }

    public static LyapunovCheckResult check(double vtBefore, double vtAfter) {
        return check(vtBefore, vtAfter, 0.01);
    }

    public static LyapunovCheckResult check(double vtBefore, double vtAfter, double epsilon) {
        double delta = vtAfter - vtBefore;
        boolean stable = delta <= epsilon;
        String reason = stable 
            ? String.format("Lyapunov stable: ΔV_t = %.6f ≤ ε", delta)
            : String.format("Lyapunov unstable: ΔV_t = %.6f > ε", delta);
        
        return new LyapunovCheckResult(stable, vtBefore, vtAfter, delta, epsilon, reason);
    }

    @Override
    public String toString() {
        return String.format(
            "{\"stable\":%b,\"vtBefore\":%.6f,\"vtAfter\":%.6f,\"deltaVt\":%.6f,\"reason\":\"%s\"}",
            isStable(), vtBefore, vtAfter, deltaVt, reason
        );
    }
}

/**
 * Artifact metadata for AI agent discovery.
 */
public class ArtifactMetadata {
    public enum ArtifactType { SQL, KOTLIN, JAVA, RUST, CPP, HEADER, LUA, ALN, DOC, CONFIG }
    public enum RoleBand { SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP, EDGESCRIPT }
    public enum LaneDefault { RESEARCH, EXPPROD, PROD, DIAGNOSTIC }
    public enum CriticalityLevel { LOW, NORMAL, HIGH, CRITICAL }

    private final String artifactPath;
    private final ArtifactType artifactType;
    private final String repoTarget;
    private final RoleBand roleBand;
    private final LaneDefault laneDefault;
    private final String semanticSummary;
    private final List<String> purposeKeywords;
    private final List<EcologicalPlane> ecologicalPlanes;
    private final Map<String, Object> agentHints;
    private final double complexityScore;
    private final CriticalityLevel criticalityLevel;
    private final List<String> dependsOnPaths;
    private final List<String> referencedByPaths;

    private ArtifactMetadata(Builder builder) {
        this.artifactPath = builder.artifactPath;
        this.artifactType = builder.artifactType;
        this.repoTarget = builder.repoTarget;
        this.roleBand = builder.roleBand;
        this.laneDefault = builder.laneDefault;
        this.semanticSummary = builder.semanticSummary;
        this.purposeKeywords = Collections.unmodifiableList(new ArrayList<>(builder.purposeKeywords));
        this.ecologicalPlanes = Collections.unmodifiableList(new ArrayList<>(builder.ecologicalPlanes));
        this.agentHints = Collections.unmodifiableMap(new HashMap<>(builder.agentHints));
        this.complexityScore = builder.complexityScore;
        this.criticalityLevel = builder.criticalityLevel;
        this.dependsOnPaths = Collections.unmodifiableList(new ArrayList<>(builder.dependsOnPaths));
        this.referencedByPaths = Collections.unmodifiableList(new ArrayList<>(builder.referencedByPaths));
    }

    // Getters
    public String getArtifactPath() { return artifactPath; }
    public ArtifactType getArtifactType() { return artifactType; }
    public String getRepoTarget() { return repoTarget; }
    public RoleBand getRoleBand() { return roleBand; }
    public LaneDefault getLaneDefault() { return laneDefault; }
    public String getSemanticSummary() { return semanticSummary; }
    public List<String> getPurposeKeywords() { return purposeKeywords; }
    public List<EcologicalPlane> getEcologicalPlanes() { return ecologicalPlanes; }
    public Map<String, Object> getAgentHints() { return agentHints; }
    public double getComplexityScore() { return complexityScore; }
    public CriticalityLevel getCriticalityLevel() { return criticalityLevel; }
    public List<String> getDependsOnPaths() { return dependsOnPaths; }
    public List<String> getReferencedByPaths() { return referencedByPaths; }

    public String toJson() {
        StringBuilder sb = new StringBuilder("{");
        sb.append("\"path\":\"").append(artifactPath).append("\",");
        sb.append("\"type\":\"").append(artifactType).append("\",");
        sb.append("\"repo\":\"").append(repoTarget).append("\",");
        sb.append("\"role\":\"").append(roleBand).append("\",");
        sb.append("\"lane\":\"").append(laneDefault).append("\",");
        sb.append("\"summary\":\"").append(semanticSummary.replace("\"", "\\\"")).append("\",");
        sb.append("\"keywords\":[");
        for (int i = 0; i < purposeKeywords.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append("\"").append(purposeKeywords.get(i)).append("\"");
        }
        sb.append("],");
        sb.append("\"planes\":[");
        for (int i = 0; i < ecologicalPlanes.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append("\"").append(ecologicalPlanes.get(i).name()).append("\"");
        }
        sb.append("],");
        sb.append("\"complexity\":").append(complexityScore).append(",");
        sb.append("\"criticality\":\"").append(criticalityLevel).append("\"");
        sb.append("}");
        return sb.toString();
    }

    public static class Builder {
        private String artifactPath;
        private ArtifactType artifactType;
        private String repoTarget = "EcoNet";
        private RoleBand roleBand = RoleBand.SPINE;
        private LaneDefault laneDefault = LaneDefault.RESEARCH;
        private String semanticSummary = "";
        private List<String> purposeKeywords = new ArrayList<>();
        private List<EcologicalPlane> ecologicalPlanes = new ArrayList<>();
        private Map<String, Object> agentHints = new HashMap<>();
        private double complexityScore = 0.5;
        private CriticalityLevel criticalityLevel = CriticalityLevel.NORMAL;
        private List<String> dependsOnPaths = new ArrayList<>();
        private List<String> referencedByPaths = new ArrayList<>();

        public Builder artifactPath(String path) { this.artifactPath = path; return this; }
        public Builder artifactType(ArtifactType type) { this.artifactType = type; return this; }
        public Builder repoTarget(String target) { this.repoTarget = target; return this; }
        public Builder roleBand(RoleBand band) { this.roleBand = band; return this; }
        public Builder laneDefault(LaneDefault lane) { this.laneDefault = lane; return this; }
        public Builder semanticSummary(String summary) { this.semanticSummary = summary; return this; }
        public Builder purposeKeywords(List<String> keywords) { this.purposeKeywords = keywords; return this; }
        public Builder ecologicalPlanes(List<EcologicalPlane> planes) { this.ecologicalPlanes = planes; return this; }
        public Builder agentHints(Map<String, Object> hints) { this.agentHints = hints; return this; }
        public Builder complexityScore(double score) { this.complexityScore = score; return this; }
        public Builder criticalityLevel(CriticalityLevel level) { this.criticalityLevel = level; return this; }
        public Builder dependsOnPaths(List<String> paths) { this.dependsOnPaths = paths; return this; }
        public Builder referencedByPaths(List<String> paths) { this.referencedByPaths = paths; return this; }

        public ArtifactMetadata build() {
            return new ArtifactMetadata(this);
        }
    }
}

/**
 * Research action template for coding agent automation.
 */
public class ResearchActionTemplate {
    public enum ActionCategory { SCHEMA_MIGRATION, CODE_GENERATION, TEST_CREATION, DOCUMENTATION, VALIDATION }
    public enum EffortLevel { LOW, MEDIUM, HIGH }

    private final String actionKey;
    private final ActionCategory actionCategory;
    private final List<String> affectedArtifacts;
    private final EffortLevel estimatedEffort;
    private final String riskAssessment;
    private final String codeTemplate;
    private final String sqlMigration;
    private final String testStub;
    private final List<String> preconditions;
    private final List<String> postconditions;

    private ResearchActionTemplate(Builder builder) {
        this.actionKey = builder.actionKey;
        this.actionCategory = builder.actionCategory;
        this.affectedArtifacts = Collections.unmodifiableList(new ArrayList<>(builder.affectedArtifacts));
        this.estimatedEffort = builder.estimatedEffort;
        this.riskAssessment = builder.riskAssessment;
        this.codeTemplate = builder.codeTemplate;
        this.sqlMigration = builder.sqlMigration;
        this.testStub = builder.testStub;
        this.preconditions = Collections.unmodifiableList(new ArrayList<>(builder.preconditions));
        this.postconditions = Collections.unmodifiableList(new ArrayList<>(builder.postconditions));
    }

    public String getActionKey() { return actionKey; }
    public ActionCategory getActionCategory() { return actionCategory; }
    public List<String> getAffectedArtifacts() { return affectedArtifacts; }
    public EffortLevel getEstimatedEffort() { return estimatedEffort; }
    public String getRiskAssessment() { return riskAssessment; }
    public Optional<String> getCodeTemplate() { return Optional.ofNullable(codeTemplate); }
    public Optional<String> getSqlMigration() { return Optional.ofNullable(sqlMigration); }
    public Optional<String> getTestStub() { return Optional.ofNullable(testStub); }
    public List<String> getPreconditions() { return preconditions; }
    public List<String> getPostconditions() { return postconditions; }

    public Optional<String> apply(Map<String, String> parameters) {
        if (codeTemplate != null) {
            return Optional.of(applyTemplate(codeTemplate, parameters));
        } else if (sqlMigration != null) {
            return Optional.of(applyTemplate(sqlMigration, parameters));
        }
        return Optional.empty();
    }

    private String applyTemplate(String template, Map<String, String> parameters) {
        String result = template;
        for (Map.Entry<String, String> entry : parameters.entrySet()) {
            result = result.replace("<" + entry.getKey() + ">", entry.getValue());
        }
        return result;
    }

    public boolean checkPreconditions(java.util.function.Predicate<String> checker) {
        return preconditions.stream().allMatch(checker);
    }

    public boolean checkPostconditions(java.util.function.Predicate<String> checker) {
        return postconditions.stream().allMatch(checker);
    }

    public static class Builder {
        private String actionKey;
        private ActionCategory actionCategory;
        private List<String> affectedArtifacts = new ArrayList<>();
        private EffortLevel estimatedEffort = EffortLevel.MEDIUM;
        private String riskAssessment = "";
        private String codeTemplate;
        private String sqlMigration;
        private String testStub;
        private List<String> preconditions = new ArrayList<>();
        private List<String> postconditions = new ArrayList<>();

        public Builder actionKey(String key) { this.actionKey = key; return this; }
        public Builder actionCategory(ActionCategory category) { this.actionCategory = category; return this; }
        public Builder affectedArtifacts(List<String> artifacts) { this.affectedArtifacts = artifacts; return this; }
        public Builder estimatedEffort(EffortLevel effort) { this.estimatedEffort = effort; return this; }
        public Builder riskAssessment(String assessment) { this.riskAssessment = assessment; return this; }
        public Builder codeTemplate(String template) { this.codeTemplate = template; return this; }
        public Builder sqlMigration(String migration) { this.sqlMigration = migration; return this; }
        public Builder testStub(String stub) { this.testStub = stub; return this; }
        public Builder preconditions(List<String> conditions) { this.preconditions = conditions; return this; }
        public Builder postconditions(List<String> conditions) { this.postconditions = conditions; return this; }

        public ResearchActionTemplate build() {
            return new ResearchActionTemplate(this);
        }
    }
}

/**
 * Agent capability descriptor for AI chat platform integration.
 */
public class AgentCapability {
    public enum CapabilityType { READ_ONLY, ANALYSIS, GENERATION, VALIDATION, TRANSFORM }

    private final String capabilityKey;
    private final CapabilityType capabilityType;
    private final List<String> scopeArtifacts;
    private final List<String> scopeTables;
    private final List<String> scopeFunctions;
    private final Map<String, Object> constraints;
    private final boolean requiresReview;
    private final int maxBatchSize;
    private final String outputFormat;
    private final String outputDestination;
    private final String description;
    private final String exampleInput;
    private final String exampleOutput;

    private AgentCapability(Builder builder) {
        this.capabilityKey = builder.capabilityKey;
        this.capabilityType = builder.capabilityType;
        this.scopeArtifacts = Collections.unmodifiableList(new ArrayList<>(builder.scopeArtifacts));
        this.scopeTables = Collections.unmodifiableList(new ArrayList<>(builder.scopeTables));
        this.scopeFunctions = Collections.unmodifiableList(new ArrayList<>(builder.scopeFunctions));
        this.constraints = Collections.unmodifiableMap(new HashMap<>(builder.constraints));
        this.requiresReview = builder.requiresReview;
        this.maxBatchSize = builder.maxBatchSize;
        this.outputFormat = builder.outputFormat;
        this.outputDestination = builder.outputDestination;
        this.description = builder.description;
        this.exampleInput = builder.exampleInput;
        this.exampleOutput = builder.exampleOutput;
    }

    public String getCapabilityKey() { return capabilityKey; }
    public CapabilityType getCapabilityType() { return capabilityType; }
    public List<String> getScopeArtifacts() { return scopeArtifacts; }
    public List<String> getScopeTables() { return scopeTables; }
    public List<String> getScopeFunctions() { return scopeFunctions; }
    public Map<String, Object> getConstraints() { return constraints; }
    public boolean isRequiresReview() { return requiresReview; }
    public int getMaxBatchSize() { return maxBatchSize; }
    public String getOutputFormat() { return outputFormat; }
    public Optional<String> getOutputDestination() { return Optional.ofNullable(outputDestination); }
    public String getDescription() { return description; }
    public Optional<String> getExampleInput() { return Optional.ofNullable(exampleInput); }
    public Optional<String> getExampleOutput() { return Optional.ofNullable(exampleOutput); }

    public boolean isInScope(String artifactPath) {
        if (scopeArtifacts.isEmpty()) return true;
        for (String pattern : scopeArtifacts) {
            if (pattern.endsWith("*")) {
                if (artifactPath.startsWith(pattern.substring(0, pattern.length() - 1))) {
                    return true;
                }
            } else if (pattern.startsWith("**/")) {
                if (artifactPath.contains(pattern.substring(3))) {
                    return true;
                }
            } else if (artifactPath.equals(pattern)) {
                return true;
            }
        }
        return false;
    }

    public ConstraintValidationReport validateConstraints(Map<String, Object> context) {
        List<String> violations = new ArrayList<>();
        
        for (Map.Entry<String, Object> entry : constraints.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();
            
            if ("query_type".equals(key) && "SELECT".equals(value)) {
                Object contextQueryType = context.get("query_type");
                if (!"SELECT".equals(contextQueryType)) {
                    violations.add("Only SELECT queries allowed");
                }
            } else if ("modifications_prohibited".equals(key) && Boolean.TRUE.equals(value)) {
                Object isModification = context.get("is_modification");
                if (Boolean.TRUE.equals(isModification)) {
                    violations.add("Modifications prohibited for this capability");
                }
            } else if ("aggregation_only".equals(key) && Boolean.TRUE.equals(value)) {
                Object isAggregation = context.get("is_aggregation");
                if (!Boolean.TRUE.equals(isAggregation)) {
                    violations.add("Only aggregation queries allowed");
                }
            }
        }

        return new ConstraintValidationReport(violations.isEmpty(), violations);
    }

    public static class ConstraintValidationReport {
        private final boolean valid;
        private final List<String> violations;

        public ConstraintValidationReport(boolean valid, List<String> violations) {
            this.valid = valid;
            this.violations = Collections.unmodifiableList(new ArrayList<>(violations));
        }

        public boolean isValid() { return valid; }
        public List<String> getViolations() { return violations; }

        @Override
        public String toString() {
            return String.format("{\"valid\":%b,\"violations\":%s}", valid, violations);
        }
    }

    public static class Builder {
        private String capabilityKey;
        private CapabilityType capabilityType;
        private List<String> scopeArtifacts = new ArrayList<>();
        private List<String> scopeTables = new ArrayList<>();
        private List<String> scopeFunctions = new ArrayList<>();
        private Map<String, Object> constraints = new HashMap<>();
        private boolean requiresReview = true;
        private int maxBatchSize = 1;
        private String outputFormat = "TEXT";
        private String outputDestination;
        private String description = "";
        private String exampleInput;
        private String exampleOutput;

        public Builder capabilityKey(String key) { this.capabilityKey = key; return this; }
        public Builder capabilityType(CapabilityType type) { this.capabilityType = type; return this; }
        public Builder scopeArtifacts(List<String> artifacts) { this.scopeArtifacts = artifacts; return this; }
        public Builder scopeTables(List<String> tables) { this.scopeTables = tables; return this; }
        public Builder scopeFunctions(List<String> functions) { this.scopeFunctions = functions; return this; }
        public Builder constraints(Map<String, Object> constraints) { this.constraints = constraints; return this; }
        public Builder requiresReview(boolean requires) { this.requiresReview = requires; return this; }
        public Builder maxBatchSize(int size) { this.maxBatchSize = size; return this; }
        public Builder outputFormat(String format) { this.outputFormat = format; return this; }
        public Builder outputDestination(String dest) { this.outputDestination = dest; return this; }
        public Builder description(String desc) { this.description = desc; return this; }
        public Builder exampleInput(String input) { this.exampleInput = input; return this; }
        public Builder exampleOutput(String output) { this.exampleOutput = output; return this; }

        public AgentCapability build() {
            return new AgentCapability(this);
        }
    }
}

/**
 * Main utility class for AI agent interactions with the EcoNet repository.
 */
public final class EcoNetAgentUtils {

    private EcoNetAgentUtils() {
        // Utility class, prevent instantiation
    }

    /**
     * Extract artifact metadata from a file path.
     */
    public static Optional<ArtifactMetadata> extractArtifactMetadata(String filePath) {
        if (filePath == null || filePath.isEmpty()) {
            return Optional.empty();
        }

        ArtifactMetadata.ArtifactType artifactType = determineArtifactType(filePath);
        if (artifactType == null) {
            return Optional.empty();
        }

        String repoTarget = inferRepoTarget(filePath);
        ArtifactMetadata.RoleBand roleBand = inferRoleBand(filePath, artifactType);
        ArtifactMetadata.LaneDefault laneDefault = inferLaneDefault(roleBand);

        return Optional.of(new ArtifactMetadata.Builder()
            .artifactPath(filePath)
            .artifactType(artifactType)
            .repoTarget(repoTarget)
            .roleBand(roleBand)
            .laneDefault(laneDefault)
            .semanticSummary(generateSemanticSummary(filePath, artifactType))
            .purposeKeywords(extractPurposeKeywords(filePath))
            .ecologicalPlanes(inferEcologicalPlanes(filePath))
            .complexityScore(estimateComplexity(filePath, artifactType))
            .criticalityLevel(determineCriticality(filePath, artifactType))
            .build());
    }

    /**
     * Validate a KER score transition for monotonicity and Lyapunov stability.
     */
    public static KerTransitionValidation validateKerTransition(
            KERScore previous, KERScore current, 
            double vtBefore, double vtAfter) {
        return validateKerTransition(previous, current, vtBefore, vtAfter, 0.01);
    }

    public static KerTransitionValidation validateKerTransition(
            KERScore previous, KERScore current, 
            double vtBefore, double vtAfter, double epsilon) {
        
        boolean monotoneOk = current.isMonotoneImprovement(previous);
        LyapunovCheckResult lyapunovResult = LyapunovCheckResult.check(vtBefore, vtAfter, epsilon);
        boolean valid = monotoneOk && lyapunovResult.isStable();

        List<String> recommendations = new ArrayList<>();
        if (!monotoneOk) {
            recommendations.add("KER metrics violate monotonicity constraints");
        }
        if (!lyapunovResult.isStable()) {
            recommendations.add(lyapunovResult.getReason());
        }

        return new KerTransitionValidation(valid, monotoneOk, lyapunovResult.isStable(), lyapunovResult, recommendations);
    }

    /**
     * Get available agent capabilities.
     */
    public static List<AgentCapability> getAvailableCapabilities() {
        List<AgentCapability> capabilities = new ArrayList<>();

        capabilities.add(new AgentCapability.Builder()
            .capabilityKey("read_schema_definitions")
            .capabilityType(AgentCapability.CapabilityType.READ_ONLY)
            .scopeArtifacts(Arrays.asList("db/*.sql"))
            .scopeTables(Arrays.asList("econet_repo_index", "cybo_workload_ledger", "blastradius_link"))
            .constraint("query_type", "SELECT")
            .constraint("modifications_prohibited", true)
            .requiresReview(false)
            .maxBatchSize(100)
            .outputFormat("SQL")
            .description("Read-only access to schema definitions for analysis")
            .build());

        capabilities.add(new AgentCapability.Builder()
            .capabilityKey("analyze_ker_metrics")
            .capabilityType(AgentCapability.CapabilityType.ANALYSIS)
            .scopeArtifacts(Arrays.asList("db/db_econet_constellation_research_spine.sql"))
            .scopeTables(Arrays.asList("cybo_workload_ledger", "v_cybo_workload_window"))
            .constraint("aggregation_only", true)
            .constraint("time_range_required", true)
            .requiresReview(false)
            .maxBatchSize(50)
            .outputFormat("JSON")
            .description("Analyze KER metrics with temporal aggregations")
            .build());

        capabilities.add(new AgentCapability.Builder()
            .capabilityKey("validate_ker_monotonicity")
            .capabilityType(AgentCapability.CapabilityType.VALIDATION)
            .scopeArtifacts(Arrays.asList("src/cpp/cyboquatic_guard/*"))
            .scopeFunctions(Arrays.asList("KerGuard::check_upgrade"))
            .constraint("input_type", "KerState")
            .constraint("output_type", "KerGuardResult")
            .requiresReview(false)
            .maxBatchSize(1)
            .outputFormat("JSON")
            .description("Validate KER monotonicity and Lyapunov safety")
            .build());

        return capabilities;
    }

    private static ArtifactMetadata.ArtifactType determineArtifactType(String filePath) {
        if (filePath.endsWith(".sql")) return ArtifactMetadata.ArtifactType.SQL;
        if (filePath.endsWith(".kt")) return ArtifactMetadata.ArtifactType.KOTLIN;
        if (filePath.endsWith(".java")) return ArtifactMetadata.ArtifactType.JAVA;
        if (filePath.endsWith(".rs")) return ArtifactMetadata.ArtifactType.RUST;
        if (filePath.endsWith(".cpp")) return ArtifactMetadata.ArtifactType.CPP;
        if (filePath.endsWith(".hpp") || filePath.endsWith(".h")) return ArtifactMetadata.ArtifactType.HEADER;
        if (filePath.endsWith(".lua")) return ArtifactMetadata.ArtifactType.LUA;
        if (filePath.endsWith(".aln")) return ArtifactMetadata.ArtifactType.ALN;
        if (filePath.endsWith(".md")) return ArtifactMetadata.ArtifactType.DOC;
        if (filePath.endsWith(".json") || filePath.endsWith(".yaml") || filePath.endsWith(".yml")) 
            return ArtifactMetadata.ArtifactType.CONFIG;
        return null;
    }

    private static String inferRepoTarget(String filePath) {
        if (filePath.startsWith("android/") || filePath.startsWith("Cyboquatics-Android/")) 
            return "EcoNet-Android";
        if (filePath.startsWith("src/")) return "EcoNet-Core";
        if (filePath.startsWith("db/") || filePath.startsWith(".econet/")) return "EcoNet-DB";
        if (filePath.startsWith("crates/")) return "EcoNet-Crates";
        return "EcoNet";
    }

    private static ArtifactMetadata.RoleBand inferRoleBand(String filePath, ArtifactMetadata.ArtifactType artifactType) {
        if (filePath.contains("/core/") || filePath.contains("actuator")) 
            return ArtifactMetadata.RoleBand.ENGINE;
        if (filePath.contains("/guard/") || filePath.contains("guard")) 
            return ArtifactMetadata.RoleBand.SPINE;
        if (filePath.startsWith("db/") || filePath.startsWith(".econet/")) 
            return ArtifactMetadata.RoleBand.SPINE;
        if (filePath.startsWith("android/") || filePath.startsWith("Cyboquatics-Android/")) 
            return ArtifactMetadata.RoleBand.APP;
        if (filePath.contains("research")) 
            return ArtifactMetadata.RoleBand.RESEARCH;
        return ArtifactMetadata.RoleBand.SPINE;
    }

    private static ArtifactMetadata.LaneDefault inferLaneDefault(ArtifactMetadata.RoleBand roleBand) {
        switch (roleBand) {
            case RESEARCH: return ArtifactMetadata.LaneDefault.RESEARCH;
            case ENGINE: return ArtifactMetadata.LaneDefault.PROD;
            case APP: return ArtifactMetadata.LaneDefault.PROD;
            default: return ArtifactMetadata.LaneDefault.RESEARCH;
        }
    }

    private static String generateSemanticSummary(String filePath, ArtifactMetadata.ArtifactType artifactType) {
        String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
        if (artifactType == ArtifactMetadata.ArtifactType.SQL) {
            return "SQL schema definition for " + fileName;
        } else if (artifactType == ArtifactMetadata.ArtifactType.KOTLIN) {
            return "Kotlin implementation: " + fileName;
        } else if (artifactType == ArtifactMetadata.ArtifactType.CPP || 
                   artifactType == ArtifactMetadata.ArtifactType.HEADER) {
            String kind = artifactType == ArtifactMetadata.ArtifactType.HEADER ? "header" : "implementation";
            return "C++ " + kind + ": " + fileName;
        }
        return "Repository artifact: " + fileName;
    }

    private static List<String> extractPurposeKeywords(String filePath) {
        String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            fileName = fileName.substring(0, dotIndex);
        }
        return Arrays.asList(fileName.split("_"));
    }

    private static List<EcologicalPlane> inferEcologicalPlanes(String filePath) {
        List<EcologicalPlane> planes = new ArrayList<>();
        String lowerPath = filePath.toLowerCase();

        if (lowerPath.contains("energy") || lowerPath.contains("power") || lowerPath.contains("battery")) {
            planes.add(EcologicalPlane.ENERGY);
        }
        if (lowerPath.contains("hydraulic") || lowerPath.contains("water") || lowerPath.contains("flow")) {
            planes.add(EcologicalPlane.HYDRAULIC);
        }
        if (lowerPath.contains("carbon") || lowerPath.contains("emission")) {
            planes.add(EcologicalPlane.CARBON);
        }
        if (lowerPath.contains("bio") || lowerPath.contains("eco")) {
            planes.add(EcologicalPlane.BIODIVERSITY);
        }
        if (lowerPath.contains("material") || lowerPath.contains("resource")) {
            planes.add(EcologicalPlane.MATERIALS);
        }
        if (lowerPath.contains("data") || lowerPath.contains("index") || lowerPath.contains("schema")) {
            planes.add(EcologicalPlane.DATA_QUALITY);
        }
        if (lowerPath.contains("topology") || lowerPath.contains("network") || lowerPath.contains("graph")) {
            planes.add(EcologicalPlane.TOPOLOGY);
        }

        if (lowerPath.contains("failsafe") || lowerPath.contains("guard") || lowerPath.contains("safety")) {
            planes.add(EcologicalPlane.DATA_QUALITY);
            planes.add(EcologicalPlane.ENERGY);
        }

        if (planes.isEmpty()) {
            planes.add(EcologicalPlane.DATA_QUALITY);
        }

        return planes;
    }

    private static double estimateComplexity(String filePath, ArtifactMetadata.ArtifactType artifactType) {
        double score = 0.5;

        int depth = 0;
        for (char c : filePath.toCharArray()) {
            if (c == '/') depth++;
        }
        score += (depth - 3) * 0.05;

        switch (artifactType) {
            case CPP:
            case HEADER:
                score += 0.15;
                break;
            case RUST:
                score += 0.1;
                break;
            case SQL:
                score -= 0.1;
                break;
        }

        String lowerPath = filePath.toLowerCase();
        if (lowerPath.contains("failsafe") || lowerPath.contains("guard") || lowerPath.contains("safety")) {
            score += 0.2;
        }

        return Math.max(0.0, Math.min(1.0, score));
    }

    private static ArtifactMetadata.CriticalityLevel determineCriticality(String filePath, ArtifactMetadata.ArtifactType artifactType) {
        String lowerPath = filePath.toLowerCase();

        if (lowerPath.contains("failsafe") || lowerPath.contains("guard") || lowerPath.contains("safety")) {
            return ArtifactMetadata.CriticalityLevel.CRITICAL;
        }
        if (lowerPath.contains("actuator") || lowerPath.contains("hardware")) {
            return ArtifactMetadata.CriticalityLevel.HIGH;
        }
        if (filePath.startsWith("db/") && lowerPath.contains("schema")) {
            return ArtifactMetadata.CriticalityLevel.HIGH;
        }
        if (filePath.startsWith(".econet/")) {
            return ArtifactMetadata.CriticalityLevel.CRITICAL;
        }
        return ArtifactMetadata.CriticalityLevel.NORMAL;
    }
}

/**
 * Validation result for KER state transitions.
 */
class KerTransitionValidation {
    private final boolean valid;
    private final boolean monotoneOk;
    private final boolean lyapunovOk;
    private final LyapunovCheckResult lyapunovDetails;
    private final List<String> recommendations;

    public KerTransitionValidation(boolean valid, boolean monotoneOk, boolean lyapunovOk,
                                   LyapunovCheckResult lyapunovDetails, List<String> recommendations) {
        this.valid = valid;
        this.monotoneOk = monotoneOk;
        this.lyapunovOk = lyapunovOk;
        this.lyapunovDetails = lyapunovDetails;
        this.recommendations = Collections.unmodifiableList(new ArrayList<>(recommendations));
    }

    public boolean isValid() { return valid; }
    public boolean isMonotoneOk() { return monotoneOk; }
    public boolean isLyapunovOk() { return lyapunovOk; }
    public LyapunovCheckResult getLyapunovDetails() { return lyapunovDetails; }
    public List<String> getRecommendations() { return recommendations; }

    public String toJson() {
        StringBuilder sb = new StringBuilder("{");
        sb.append("\"valid\":").append(valid).append(",");
        sb.append("\"monotoneOk\":").append(monotoneOk).append(",");
        sb.append("\"lyapunovOk\":").append(lyapunovOk).append(",");
        sb.append("\"deltaVt\":").append(lyapunovDetails.getDeltaVt()).append(",");
        sb.append("\"recommendations\":[");
        for (int i = 0; i < recommendations.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append("\"").append(recommendations.get(i)).append("\"");
        }
        sb.append("]");
        sb.append("}");
        return sb.toString();
    }

    @Override
    public String toString() {
        return toJson();
    }
}
