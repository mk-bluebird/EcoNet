# EcoNet

EcoNet is an ecosafety governance constellation providing Lyapunov-stable, KER-governed coordination for Cyboquatic machinery and environmental restoration systems.

## Repository Structure

```
EcoNet/
├── .econet/                          # Manifest and governance schemas
│   └── econet_repo_index.sql         # Self-manifest with KER targets
├── db/                               # SQLite schemas for constellation orchestration
│   ├── db_econet_ai_agent_discovery.sql  # AI agent discovery layer (NEW)
│   ├── db_econet_constellation_research_spine.sql
│   ├── db_econet_cyboquatic_index.sql
│   └── db_econet_file_index.sql
├── src/
│   ├── core/                         # Core utilities and safety systems
│   │   ├── actuator_failsafe.hpp/cpp # 6D convex safety corridor enforcement
│   │   ├── EcoNetAgentUtils.kt       # Kotlin AI agent utilities (NEW)
│   │   └── EcoNetAgentUtils.java     # Java AI agent utilities (NEW)
│   ├── cpp/cyboquatic_guard/         # C++ KER monotonicity validation
│   └── ...                           # Additional source modules
├── android/                          # Android integration layers
└── Cyboquatics-Android/              # Cyboquatic visualizer applications
```

## AI Chat Platform Integration

This repository includes specialized utilities designed for AI chat platforms and coding agents:

### SQL Discovery Layer (`db/db_econet_ai_agent_discovery.sql`)

Provides structured metadata for AI agent consumption:
- **ai_agent_discovery_index**: Semantic search index for all code artifacts
- **research_action_cache**: Pre-validated code generation templates
- **agent_capability_hints**: Declares safe operations for AI agents
- **ecological_plane_xref**: Cross-references linking files to ecological planes
- **ker_context_registry**: KER (Knowledge-Energy-Risk) context for safety-critical work

Key views for RAG pipelines:
- `v_ai_artifact_full_context`: Complete artifact context for retrieval
- `v_econet_ai_quick_context`: Rapid context injection for chat platforms
- `v_ker_targets_summary`: Production threshold lookup

### Kotlin Utilities (`src/core/EcoNetAgentUtils.kt`)

Zero-dependency Kotlin utilities providing:
- `EcologicalPlane`: Enum of all monitored ecological dimensions
- `KERScore`: Data class with validation and JSON serialization
- `LyapunovCheckResult`: Stability verification for state transitions
- `ArtifactMetadata`: Structured artifact description for agents
- `ResearchActionTemplate`: Pre-validated code/migration templates
- `AgentCapability`: Capability descriptors with constraint validation
- `BlastRadiusImpact`: Impact assessment for changes/events

### Java Utilities (`src/core/EcoNetAgentUtils.java`)

Java 8+ compatible utilities providing:
- Full interoperability with Kotlin equivalents
- Builder patterns for object construction
- Optional-based null safety
- JSON serialization/deserialization

## KER Targets (Production Lane)

| Metric | Threshold | Direction |
|--------|-----------|-----------|
| Knowledge (K) | ≥ 0.95 | Higher is better |
| Energy (E) | ≥ 0.92 | Higher is better |
| Risk (R) | ≤ 0.12 | Lower is better |

## Ecological Planes

The system monitors seven ecological planes:
1. **ENERGY**: Power capture, efficiency, and thermal management
2. **HYDRAULIC**: Water flow, pressure, and hydrological buffers
3. **CARBON**: Carbon footprint and sequestration metrics
4. **BIODIVERSITY**: Ecosystem impact and species protection
5. **MATERIALS**: Resource utilization and reclamation ratios
6. **DATA_QUALITY**: Telemetry accuracy and manifest integrity
7. **TOPOLOGY**: Network connectivity and graph structure

## Safety Guarantees

- **Non-actuating research spine**: All research-band code is read-only diagnostic
- **Lyapunov stability**: V_t must be non-increasing (ΔV_t ≤ ε)
- **KER monotonicity**: K and E non-decreasing, R non-increasing
- **6D convex corridor**: Hardware actuation bounded by safety limits

## Agent Capabilities

AI agents operating on this repository can safely:

| Capability | Type | Review Required | Scope |
|------------|------|-----------------|-------|
| `read_schema_definitions` | READ_ONLY | No | db/*.sql |
| `analyze_ker_metrics` | ANALYSIS | No | Workload ledger tables |
| `validate_ker_monotonicity` | VALIDATION | No | cyboquatic_guard module |
| `generate_sql_migrations` | GENERATION | Yes | Schema modifications |
| `extract_ecological_planes` | ANALYSIS | No | All artifacts |

## Usage Examples

### Querying Artifact Context (SQL)

```sql
-- Get full context for a specific artifact
SELECT * FROM v_ai_artifact_full_context 
WHERE artifact_path LIKE '%actuator_failsafe%';

-- Find all CRITICAL artifacts
SELECT artifact_path, semantic_summary, ecological_planes 
FROM ai_agent_discovery_index 
WHERE criticality_level = 'CRITICAL';

-- Search by ecological plane
SELECT * FROM v_econet_ai_quick_context 
WHERE ecological_context LIKE '%ENERGY%';
```

### Validating KER Transitions (Kotlin)

```kotlin
val previous = KERScore(knowledge = 0.95, energy = 0.92, risk = 0.10)
val current = KERScore(knowledge = 0.96, energy = 0.93, risk = 0.09)

val validation = EcoNetAgentUtils.validateKerTransition(
    previous = previous,
    current = current,
    vtBefore = 0.50,
    vtAfter = 0.48
)

if (validation.valid) {
    println("Transition approved: ${validation.toJson()}")
} else {
    println("Transition rejected: ${validation.recommendations}")
}
```

### Extracting Artifact Metadata (Java)

```java
Optional<ArtifactMetadata> meta = EcoNetAgentUtils.extractArtifactMetadata(
    "src/core/actuator_failsafe.cpp"
);

meta.ifPresent(m -> {
    System.out.println("Type: " + m.getArtifactType());
    System.out.println("Criticality: " + m.getCriticalityLevel());
    System.out.println("Planes: " + m.getEcologicalPlanes());
    System.out.println("JSON: " + m.toJson());
});
```

## License

EcoNet operates under ecosafety governance constraints. All deployments must maintain KER targets and Lyapunov stability guarantees.