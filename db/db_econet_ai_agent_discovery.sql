-- ============================================================================
-- filename: db/db_econet_ai_agent_discovery.sql
-- destination: EcoNet/db/db_econet_ai_agent_discovery.sql
-- purpose: AI-agent discovery layer for EcoNet constellation repositories
-- 
-- This schema provides:
--   1. Semantic search indexes for code artifacts and their purposes
--   2. Agent capability hints for automated repository navigation
--   3. Research-action optimization tables for coding agents
--   4. Cross-reference graphs linking files, functions, and ecological planes
--   5. Queryable metadata for LLM context injection and RAG pipelines
--
-- Designed for read-only consumption by AI chat platforms, coding agents,
-- and orchestration layers. No write operations from external agents.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- 1. AI Agent Discovery Index
--    Maps repository artifacts to semantic descriptions usable by LLMs
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_agent_discovery_index (
    discovery_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    artifact_path     TEXT NOT NULL UNIQUE,
    artifact_type     TEXT NOT NULL CHECK (artifact_type IN ('SQL', 'KOTLIN', 'JAVA', 'RUST', 'CPP', 'HEADER', 'LUA', 'ALN', 'DOC', 'CONFIG')),
    repo_target       TEXT NOT NULL,
    role_band         TEXT NOT NULL CHECK (role_band IN ('SPINE', 'RESEARCH', 'ENGINE', 'MATERIAL', 'GOV', 'APP', 'EDGESCRIPT')),
    lane_default      TEXT NOT NULL CHECK (lane_default IN ('RESEARCH', 'EXPPROD', 'PROD', 'DIAGNOSTIC')),
    
    -- Semantic metadata for AI consumption
    semantic_summary  TEXT NOT NULL,
    purpose_keywords  TEXT NOT NULL,  -- CSV of searchable keywords
    ecological_planes TEXT,           -- CSV: ENERGY, HYDRAULIC, CARBON, BIODIVERSITY, MATERIALS, DATA_QUALITY, TOPOLOGY
    
    -- Agent hints
    agent_hints       TEXT,           -- JSON-like hints for coding agents
    complexity_score  REAL DEFAULT 0.5 CHECK (complexity_score BETWEEN 0.0 AND 1.0),
    criticality_level TEXT DEFAULT 'NORMAL' CHECK (criticality_level IN ('LOW', 'NORMAL', 'HIGH', 'CRITICAL')),
    
    -- Cross-references
    depends_on_paths  TEXT,           -- CSV of artifact paths this depends on
    referenced_by     TEXT,           -- CSV of artifact paths that reference this
    
    -- Governance and audit
    signing_did       TEXT,
    evidence_hex      TEXT,
    created_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_ai_discovery_artifact_type
    ON ai_agent_discovery_index(artifact_type, repo_target);

CREATE INDEX IF NOT EXISTS idx_ai_discovery_role_band
    ON ai_agent_discovery_index(role_band, lane_default);

CREATE INDEX IF NOT EXISTS idx_ai_discovery_ecological_planes
    ON ai_agent_discovery_index(ecological_planes);

-- Full-text search virtual table for semantic queries
CREATE VIRTUAL TABLE IF NOT EXISTS fts_ai_discovery_search USING fts5(
    artifact_path,
    semantic_summary,
    purpose_keywords,
    ecological_planes,
    agent_hints,
    content='ai_agent_discovery_index',
    content_rowid='discovery_id'
);

-- ============================================================================
-- 2. Research Action Optimization Tables
--    Pre-computed metadata to accelerate coding agent workflows
-- ============================================================================

CREATE TABLE IF NOT EXISTS research_action_cache (
    cache_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    action_key        TEXT NOT NULL UNIQUE,  -- e.g., 'add_ker_field', 'update_blast_radius'
    action_category   TEXT NOT NULL CHECK (action_category IN ('SCHEMA_MIGRATION', 'CODE_GENERATION', 'TEST_CREATION', 'DOCUMENTATION', 'VALIDATION')),
    
    -- Cached analysis results
    affected_artifacts TEXT NOT NULL,  -- JSON array of artifact paths
    estimated_effort  TEXT DEFAULT 'MEDIUM' CHECK (estimated_effort IN ('LOW', 'MEDIUM', 'HIGH')),
    risk_assessment   TEXT,           -- Risk notes for the action
    
    -- Pre-computed templates or snippets
    code_template     TEXT,
    sql_migration     TEXT,
    test_stub         TEXT,
    
    -- Validation rules
    preconditions     TEXT,           -- JSON array of precondition checks
    postconditions    TEXT,           -- JSON array of postcondition validations
    
    -- Metadata
    last_validated_utc TEXT,
    validation_status TEXT DEFAULT 'PENDING' CHECK (validation_status IN ('PENDING', 'VALIDATED', 'DEPRECATED')),
    created_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_research_action_category
    ON research_action_cache(action_category, validation_status);

-- ============================================================================
-- 3. Agent Capability Hints
--    Declares what operations AI agents can safely perform
-- ============================================================================

CREATE TABLE IF NOT EXISTS agent_capability_hints (
    hint_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    capability_key    TEXT NOT NULL UNIQUE,
    capability_type   TEXT NOT NULL CHECK (capability_type IN ('READ_ONLY', 'ANALYSIS', 'GENERATION', 'VALIDATION', 'TRANSFORM')),
    
    -- Scope of capability
    scope_artifacts   TEXT,           -- CSV of artifact paths or patterns
    scope_tables      TEXT,           -- CSV of table names
    scope_functions   TEXT,           -- CSV of function/procedure names
    
    -- Constraints
    constraints_json  TEXT,           -- JSON object with constraint definitions
    requires_review   INTEGER NOT NULL DEFAULT 1 CHECK (requires_review IN (0, 1)),
    max_batch_size    INTEGER DEFAULT 1,
    
    -- Output specifications
    output_format     TEXT,           -- e.g., 'SQL', 'KOTLIN', 'JSON', 'MARKDOWN'
    output_destination TEXT,          -- Path pattern for generated files
    
    -- Documentation
    description       TEXT NOT NULL,
    example_input     TEXT,
    example_output    TEXT,
    
    created_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_agent_capability_type
    ON agent_capability_hints(capability_type, requires_review);

-- ============================================================================
-- 4. Ecological Plane Cross-Reference Graph
--    Links artifacts to ecological planes and their metrics
-- ============================================================================

CREATE TABLE IF NOT EXISTS ecological_plane_xref (
    xref_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    artifact_path     TEXT NOT NULL,
    plane_name        TEXT NOT NULL CHECK (plane_name IN ('ENERGY', 'HYDRAULIC', 'CARBON', 'BIODIVERSITY', 'MATERIALS', 'DATA_QUALITY', 'TOPOLOGY', 'RESTORATION')),
    
    -- Relationship type
    relationship_type TEXT NOT NULL CHECK (relationship_type IN ('DEFINES', 'CONSUMES', 'PRODUCES', 'MONITORS', 'CONTROLS', 'REPORTS')),
    
    -- Metrics and thresholds
    metric_name       TEXT,
    metric_unit       TEXT,
    threshold_min     REAL,
    threshold_max     REAL,
    target_value      REAL,
    
    -- Evidence and provenance
    evidence_source   TEXT,
    confidence_score  REAL DEFAULT 0.5 CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    
    created_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE (artifact_path, plane_name, relationship_type, metric_name)
);

CREATE INDEX IF NOT EXISTS idx_eco_plane_artifact
    ON ecological_plane_xref(artifact_path, plane_name);

CREATE INDEX IF NOT EXISTS idx_eco_plane_relationship
    ON ecological_plane_xref(plane_name, relationship_type);

-- ============================================================================
-- 5. KER (Knowledge-Energy-Risk) Context Registry
--    Provides KER-related context for AI agents working on safety-critical code
-- ============================================================================

CREATE TABLE IF NOT EXISTS ker_context_registry (
    context_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    context_key       TEXT NOT NULL UNIQUE,
    context_type      TEXT NOT NULL CHECK (context_type IN ('CORRIDOR_LIMIT', 'LYAPUNOV_FUNCTION', 'KER_TARGET', 'BLAST_RADIUS', 'WORKLOAD_LEDGER')),
    
    -- Context definition
    mathematical_def  TEXT,           -- LaTeX or plain-text mathematical definition
    natural_language  TEXT NOT NULL,  -- Human-readable explanation
    code_references   TEXT,           -- CSV of file:function references
    
    -- Parameters and bounds
    parameters_json   TEXT,           -- JSON object with parameter definitions
    lower_bound       REAL,
    upper_bound       REAL,
    default_value     REAL,
    
    -- Safety constraints
    invariant_rules   TEXT,           -- JSON array of invariant conditions
    violation_action  TEXT DEFAULT 'LOG_AND_ALERT',
    
    -- Provenance
    source_paper      TEXT,
    source_aln        TEXT,           -- ALN specification reference
    signing_did       TEXT,
    
    created_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_utc       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_ker_context_type
    ON ker_context_registry(context_type);

-- ============================================================================
-- 6. AI Chat Platform Integration Views
--    Pre-joined views optimized for LLM context injection
-- ============================================================================

-- View: Complete artifact context for RAG retrieval
DROP VIEW IF EXISTS v_ai_artifact_full_context;

CREATE VIEW v_ai_artifact_full_context AS
SELECT
    d.discovery_id,
    d.artifact_path,
    d.artifact_type,
    d.repo_target,
    d.role_band,
    d.lane_default,
    d.semantic_summary,
    d.purpose_keywords,
    d.ecological_planes,
    d.agent_hints,
    d.complexity_score,
    d.criticality_level,
    GROUP_CONCAT(DISTINCT e.plane_name || ':' || e.relationship_type) AS plane_relationships,
    GROUP_CONCAT(DISTINCT k.context_key || ':' || k.context_type) AS ker_contexts,
    d.created_utc,
    d.updated_utc
FROM ai_agent_discovery_index d
LEFT JOIN ecological_plane_xref e ON e.artifact_path = d.artifact_path
LEFT JOIN ker_context_registry k ON INSTR(d.depends_on_paths, k.context_key) > 0
GROUP BY d.discovery_id;

-- View: Research action recommendations by artifact
DROP VIEW IF EXISTS v_research_actions_by_artifact;

CREATE VIEW v_research_actions_by_artifact AS
SELECT
    d.artifact_path,
    d.artifact_type,
    r.action_key,
    r.action_category,
    r.affected_artifacts,
    r.estimated_effort,
    r.code_template,
    r.sql_migration,
    r.validation_status
FROM ai_agent_discovery_index d
CROSS JOIN research_action_cache r
WHERE r.validation_status = 'VALIDATED'
  AND (INSTR(r.affected_artifacts, d.artifact_path) > 0 OR r.affected_artifacts LIKE '%ALL%');

-- View: Agent capabilities by artifact type
DROP VIEW IF EXISTS v_capabilities_by_artifact;

CREATE VIEW v_capabilities_by_artifact AS
SELECT
    c.capability_key,
    c.capability_type,
    c.scope_artifacts,
    c.constraints_json,
    c.requires_review,
    c.output_format,
    c.description,
    CASE 
        WHEN c.scope_artifacts IS NULL THEN 'ALL'
        ELSE c.scope_artifacts
    END AS effective_scope
FROM agent_capability_hints c
WHERE c.requires_review = 0 OR c.requires_review = 1;

-- View: KER targets summary for quick agent lookup
DROP VIEW IF EXISTS v_ker_targets_summary;

CREATE VIEW v_ker_targets_summary AS
SELECT
    context_key,
    context_type,
    natural_language,
    lower_bound,
    upper_bound,
    default_value,
    invariant_rules,
    source_aln
FROM ker_context_registry
WHERE context_type IN ('KER_TARGET', 'CORRIDOR_LIMIT')
ORDER BY context_type, context_key;

-- ============================================================================
-- 7. Seed Data for AI Agent Discovery
--    Pre-populated entries for existing repository artifacts
-- ============================================================================

INSERT OR IGNORE INTO ai_agent_discovery_index (
    artifact_path, artifact_type, repo_target, role_band, lane_default,
    semantic_summary, purpose_keywords, ecological_planes,
    agent_hints, complexity_score, criticality_level, depends_on_paths
) VALUES
-- Database schemas
('db/db_econet_constellation_research_spine.sql', 'SQL', 'EcoNet', 'SPINE', 'RESEARCH',
 'Non-actuating research spine schema defining blast radius links, workload ledger, and manifest-backed KER targets for constellation orchestration.',
 'blast-radius,workload-ledger,KER-targets,research-spine,constellation,non-actuating',
 'DATA_QUALITY,TOPOLOGY',
 '{"agent_type":"schema-reader","write_prohibited":true,"read_pattern":"SELECT-only"}',
 0.7, 'HIGH', '.econet/econet_repo_index.sql'),

('db/db_econet_file_index.sql', 'SQL', 'EcoNet', 'SPINE', 'RESEARCH',
 'Constellation-wide file index table guiding AI agents to locate artifacts within the EcoNet repository structure.',
 'file-index,artifact-discovery,agent-navigation,repository-mapping',
 'DATA_QUALITY',
 '{"agent_type":"navigator","provides_paths":true}',
 0.4, 'NORMAL', NULL),

('.econet/econet_repo_index.sql', 'SQL', 'EcoNet', 'SPINE', 'RESEARCH',
 'EcoNet self-manifest declaring KER targets, governance SPINE role, and Cyboquatic machinery coordination contracts.',
 'manifest,KER-targets,governance,SPINE,Cyboquatic,coordination',
 'DATA_QUALITY,TOPOLOGY',
 '{"agent_type":"manifest-parser","validates_against":"EcoNetSchemaShard2026v1"}',
 0.6, 'CRITICAL', NULL),

-- Kotlin Android code
('android/app/src/main/java/org/mkbluebird/cyberquatic/sync/AdaptiveSyncStrategy.kt', 'KOTLIN', 'EcoNet', 'APP', 'PROD',
 'Android adaptive synchronization strategy implementing battery-aware, location-based KER score synchronization with nearby Cyboquatic nodes.',
 'adaptive-sync,battery-aware,geofencing,KER-sync,Android,Cyboquatic',
 'ENERGY,DATA_QUALITY',
 '{"agent_type":"code-analyzer","language":"Kotlin","framework":"Android","async":"coroutines"}',
 0.65, 'HIGH', 'CyboOverlay.kt'),

('Cyboquatics-Android/androidapp/src/main/java/org/econet/CyboOverlay.kt', 'KOTLIN', 'EcoNet', 'APP', 'PROD',
 'JNI overlay providing Kotlin access to native cdylib functions for KER targets, blast radius queries, and workload trends from SQLite databases.',
 'JNI,cdylib-overlay,KER-query,blast-radius,workload-trends,native-interop',
 'DATA_QUALITY,ENERGY',
 '{"agent_type":"ffi-wrapper","native_lib":"eco_restoration_shard","functions":["econet_get_ker_targets","econet_get_blast_radius_for_node"]}',
 0.5, 'HIGH', 'db/db_econet_constellation_research_spine.sql'),

-- C++ core code
('src/core/actuator_failsafe.hpp', 'HEADER', 'EcoNet', 'ENGINE', 'PROD',
 'C++ header defining 6D convex safety corridor limits, actuator metrics, and hardware register mappings for subsea actuator fail-safe system.',
 'failsafe,safety-corridor,actuator,hardware-registers,Lyapunov,MT6883',
 'ENERGY,MATERIALS,DATA_QUALITY',
 '{"agent_type":"safety-critical","language":"C++","abi":"C-FFI","review_required":true}',
 0.85, 'CRITICAL', 'src/core/actuator_failsafe.cpp'),

('src/core/actuator_failsafe.cpp', 'CPP', 'EcoNet', 'ENGINE', 'PROD',
 'C++ implementation of subsea actuator control loop with Lyapunov stability validation, corridor enforcement, and emergency isolation procedures.',
 'failsafe-implementation,corridor-enforcement,Lyapunov-stability,emergency-isolation,actuator-control',
 'ENERGY,MATERIALS,DATA_QUALITY',
 '{"agent_type":"safety-critical","language":"C++","implements":"SafetyCorridor","callbacks":"RiskEventCallback"}',
 0.9, 'CRITICAL', 'src/core/actuator_failsafe.hpp'),

('src/cpp/cyboquatic_guard/ker_guard.hpp', 'HEADER', 'EcoNet', 'SPINE', 'RESEARCH',
 'C++ header for KER monotonicity guard ensuring Knowledge, Energy, and Risk metrics maintain non-decreasing K/E and non-increasing R during upgrades.',
 'KER-guard,monotonicity,Lyapunov,upgrade-validation,safety-check',
 'DATA_QUALITY,ENERGY',
 '{"agent_type":"validation","checks":["K_monotone","E_monotone","R_nonincreasing","Lyapunov_safe"]}',
 0.7, 'CRITICAL', 'src/cpp/cyboquatic_guard/ker_guard.cpp'),

('src/cpp/cyboquatic_guard/ker_guard.cpp', 'CPP', 'EcoNet', 'SPINE', 'RESEARCH',
 'C++ implementation of KER upgrade validation checking monotonicity constraints and Lyapunov safety conditions before allowing state transitions.',
 'KER-validation,monotonicity-check,Lyapunov-verification,upgrade-safety',
 'DATA_QUALITY,ENERGY',
 '{"agent_type":"validator","input":"KerState","output":"KerGuardResult"}',
 0.65, 'CRITICAL', 'src/cpp/cyboquatic_guard/ker_guard.hpp');

-- Seed ecological plane cross-references
INSERT OR IGNORE INTO ecological_plane_xref (
    artifact_path, plane_name, relationship_type, metric_name, metric_unit,
    threshold_min, threshold_max, target_value, confidence_score
) VALUES
-- Energy plane
('src/core/actuator_failsafe.hpp', 'ENERGY', 'MONITORS', 'kinetic_efficiency', 'ratio', 0.0, 1.0, 0.95, 0.9),
('src/core/actuator_failsafe.cpp', 'ENERGY', 'CONTROLS', 'roh_kelvin_per_hour', 'K/h', 0.0, 0.30, 0.15, 0.85),
('android/app/src/main/java/org/mkbluebird/cyberquatic/sync/AdaptiveSyncStrategy.kt', 'ENERGY', 'CONSUMES', 'battery_level', 'percent', 0.0, 100.0, 80.0, 0.95),

-- Data quality plane
('db/db_econet_constellation_research_spine.sql', 'DATA_QUALITY', 'DEFINES', 'ker_score_accuracy', 'ratio', 0.0, 1.0, 0.98, 0.92),
('.econet/econet_repo_index.sql', 'DATA_QUALITY', 'DEFINES', 'manifest_schema_version', 'integer', 1, 10, 1, 1.0),
('src/cpp/cyboquatic_guard/ker_guard.cpp', 'DATA_QUALITY', 'VALIDATES', 'ker_monotonicity', 'boolean', NULL, NULL, 1.0, 0.98),

-- Materials plane
('src/core/actuator_failsafe.hpp', 'MATERIALS', 'MONITORS', 'resource_depletion', 'ratio', 0.0, 0.13, 0.05, 0.8),

-- Topology plane
('db/db_econet_constellation_research_spine.sql', 'TOPOLOGY', 'DEFINES', 'blast_radius_links', 'count', 0, NULL, NULL, 0.88);

-- Seed KER context registry
INSERT OR IGNORE INTO ker_context_registry (
    context_key, context_type, mathematical_def, natural_language, code_references,
    parameters_json, lower_bound, upper_bound, default_value, invariant_rules,
    violation_action, source_aln
) VALUES
('ker_target_k', 'KER_TARGET', 'K \\in [0, 1]', 'Knowledge metric representing system understanding and model accuracy. Must be >= 0.95 for production deployment.',
 'db/db_econet_constellation_research_spine.sql:econet_repo_index.ker_target_k,CyboOverlay.kt:econet_get_ker_targets',
 '{"description":"Knowledge score","interpretation":"Higher is better","production_threshold":0.95}',
 0.0, 1.0, 0.95,
 '["K >= 0.95 for PROD lane", "K must not decrease between versions"]',
 'LOG_AND_ALERT',
 'EcoNetSchemaShard2026v1'),

('ker_target_e', 'KER_TARGET', 'E \\in [0, 1]', 'Energy efficiency metric representing energy capture and utilization effectiveness. Must be >= 0.92 for production.',
 'db/db_econet_constellation_research_spine.sql:econet_repo_index.ker_target_e,AdaptiveSyncStrategy.kt:getBatteryLevel',
 '{"description":"Energy efficiency","interpretation":"Higher is better","production_threshold":0.92}',
 0.0, 1.0, 0.92,
 '["E >= 0.92 for PROD lane", "E must not decrease between versions"]',
 'LOG_AND_ALERT',
 'EcoNetSchemaShard2026v1'),

('ker_target_r', 'KER_TARGET', 'R \\in [0, 1]', 'Risk metric representing aggregate system risk across all ecological planes. Must be <= 0.12 for production.',
 'db/db_econet_constellation_research_spine.sql:econet_repo_index.ker_target_r,ker_guard.cpp:check_upgrade',
 '{"description":"Risk score","interpretation":"Lower is better","production_threshold":0.12}',
 0.0, 1.0, 0.12,
 '["R <= 0.12 for PROD lane", "R must not increase between versions"]',
 'EMERGENCY_ISOLATE',
 'EcoNetSchemaShard2026v1'),

('lyapunov_corridor', 'CORRIDOR_LIMIT', '\\Delta V_t = V_{t+1} - V_t \\leq \\epsilon', 'Lyapunov stability corridor requiring non-increasing residual over time with small tolerance epsilon for numerical precision.',
 'src/core/actuator_failsafe.cpp:check_safety_corridor,src/cpp/cyboquatic_guard/ker_guard.cpp:check_upgrade',
 '{"epsilon":0.01,"interpretation":"V_t should decrease or stay constant","violation_means":"instability"}',
 NULL, NULL, NULL,
 '["V_t_new <= V_t_old + epsilon", "Sustained increase triggers fail-safe"]',
 'EMERGENCY_ISOLATE',
 'CyboquaticEcosafetyContinuity2026v1.aln'),

('blast_radius_impact', 'BLAST_RADIUS', 'impact\\_score \\in [0, 1]', 'Normalized impact score representing fraction of safety corridor affected by a change or event.',
 'db/db_econet_constellation_research_spine.sql:blastradius_link.impact_score',
 '{"bands":{"SAFE":"<0.3","GOLD":"0.3-0.6","HARD":"0.6-0.9","EXCEEDED":">0.9"}}',
 0.0, 1.0, NULL,
 '["impact_score <= 0.9 for normal operation", "EXCEEDED band requires immediate review"]',
 'LOG_AND_ALERT',
 'EcoNetSchemaShard2026v1');

-- Seed research action cache
INSERT OR IGNORE INTO research_action_cache (
    action_key, action_category, affected_artifacts, estimated_effort, risk_assessment,
    code_template, sql_migration, preconditions, postconditions, validation_status
) VALUES
('add_ker_field_to_ledger', 'SCHEMA_MIGRATION',
 '["db/db_econet_constellation_research_spine.sql:cybo_workload_ledger"]', 'LOW',
 'Low risk - additive schema change with nullable field',
 NULL,
 '-- Add new KER-related field to workload ledger
ALTER TABLE cybo_workload_ledger ADD COLUMN <field_name> REAL;
-- Add check constraint if bounded
ALTER TABLE cybo_workload_ledger ADD CONSTRAINT chk_<field_name> CHECK (<field_name> >= 0.0 AND <field_name> <= 1.0);',
 '["table_exists:cybo_workload_ledger", "field_not_exists:<field_name>"]',
 '["field_exists:<field_name>", "constraint_exists:chk_<field_name>"]',
 'VALIDATED'),

('create_blast_radius_view', 'SCHEMA_MIGRATION',
 '["db/db_econet_constellation_research_spine.sql:blastradius_link"]', 'LOW',
 'No risk - view creation only, no data modification',
 NULL,
 'CREATE VIEW IF NOT EXISTS v_<view_name> AS
SELECT <columns>
FROM blastradius_link
WHERE <conditions>
GROUP BY <grouping>;',
 '["table_exists:blastradius_link"]',
 '["view_exists:v_<view_name>"]',
 'VALIDATED'),

('generate_kotlin_data_class', 'CODE_GENERATION',
 '["**/*.kt"]', 'LOW',
 'No risk - generates new Kotlin data classes',
 'data class <ClassName>(
    val <property>: <Type>,
    // ... additional properties
) {
    fun isValid(): Boolean {
        return <validation_logic>
    }
}',
 NULL,
 '["package_exists:<package_name>"]',
 '["file_created:<path>", "compiles:true"]',
 'VALIDATED'),

('add_ecological_plane_xref', 'VALIDATION',
 '["ALL"]', 'MEDIUM',
 'Medium risk - modifies cross-reference graph, affects query results',
 NULL,
 NULL,
 '["artifact_exists:<artifact_path>", "plane_valid:<plane_name>"]',
 '["xref_created:<artifact_path>:<plane_name>", "index_updated:true"]',
 'VALIDATED');

-- Seed agent capability hints
INSERT OR IGNORE INTO agent_capability_hints (
    capability_key, capability_type, scope_artifacts, scope_tables, scope_functions,
    constraints_json, requires_review, max_batch_size, output_format, output_destination,
    description, example_input, example_output
) VALUES
('read_schema_definitions', 'READ_ONLY', 'db/*.sql',
 'econet_repo_index,cybo_workload_ledger,blastradius_link,econet_layer,econet_role_hint',
 NULL,
 '{"query_type":"SELECT","joins_allowed":true,"modifications_prohibited":true}',
 0, 100, 'SQL', NULL,
 'Read-only access to schema definitions for analysis and documentation generation.',
 'SELECT * FROM econet_repo_index WHERE role_band = ''SPINE''',
 'ResultSet with repo metadata'),

('analyze_ker_metrics', 'ANALYSIS', 'db/db_econet_constellation_research_spine.sql',
 'cybo_workload_ledger,v_cybo_workload_window',
 NULL,
 '{"aggregation_only":true,"time_range_required":true}',
 0, 50, 'JSON', 'analysis/ker_analysis_*.json',
 'Analyze KER metrics from workload ledger with temporal aggregations.',
 '{"nodeid":"phx_node_001","start_ms":1234567890,"end_ms":1234567990}',
 '{"mean_k":0.96,"mean_e":0.93,"mean_r":0.08,"fraction_corridor_ok":0.98}'),

('generate_sql_migrations', 'GENERATION', 'db/*.sql', NULL, NULL,
 '{"must_include_pragma":true,"foreign_keys_required":true,"rollback_optional":true}',
 1, 5, 'SQL', 'db/migrations/',
 'Generate SQL migration scripts with proper pragma and constraint handling.',
 '{"action":"add_column","table":"cybo_workload_ledger","column":"new_metric REAL"}',
 'ALTER TABLE cybo_workload_ledger ADD COLUMN new_metric REAL;'),

('validate_ker_monotonicity', 'VALIDATION', 'src/cpp/cyboquatic_guard/*',
 NULL, 'KerGuard::check_upgrade',
 '{"input_type":"KerState","output_type":"KerGuardResult","checks":["K","E","R","V_t"]}',
 0, 1, 'JSON', 'validation/ker_check_*.json',
 'Validate KER monotonicity and Lyapunov safety for state transitions.',
 '{"k_old":0.95,"e_old":0.92,"r_old":0.10,"vt_old":0.5,"k_new":0.96,"e_new":0.93,"r_new":0.09,"vt_new":0.48}',
 '{"monotone_ok":true,"lyapunov_ok":true,"reason":"KER upgrade monotone and Lyapunov-safe"}'),

('extract_ecological_planes', 'ANALYSIS', '**/*', NULL, NULL,
 '{"pattern_matching":true,"keyword_extraction":true}',
 0, 200, 'JSON', 'metadata/ecological_planes_index.json',
 'Extract ecological plane references from all artifacts for cross-reference indexing.',
 '{"artifact_path":"src/core/actuator_failsafe.cpp"}',
 '{"planes":["ENERGY","MATERIALS","DATA_QUALITY"],"confidence":0.87}');

-- ============================================================================
-- 8. Utility Functions (as comments for manual deployment)
--    These can be implemented as application-layer functions or triggers
-- ============================================================================

/*
-- Function: Update FTS index when ai_agent_discovery_index changes
CREATE TRIGGER IF NOT EXISTS trg_ai_discovery_after_insert
AFTER INSERT ON ai_agent_discovery_index
BEGIN
    INSERT INTO fts_ai_discovery_search (rowid, artifact_path, semantic_summary, purpose_keywords, ecological_planes, agent_hints)
    VALUES (NEW.discovery_id, NEW.artifact_path, NEW.semantic_summary, NEW.purpose_keywords, NEW.ecological_planes, NEW.agent_hints);
END;

CREATE TRIGGER IF NOT EXISTS trg_ai_discovery_after_delete
AFTER DELETE ON ai_agent_discovery_index
BEGIN
    INSERT INTO fts_ai_discovery_search (fts_ai_discovery_search) VALUES ('delete:' || OLD.discovery_id);
END;

-- Function: Get similar artifacts by semantic similarity
-- Usage: SELECT * FROM find_similar_artifacts('some/artifact/path.sql', 5);
CREATE VIEW IF NOT EXISTS v_find_similar_artifacts AS
SELECT
    base.artifact_path AS query_artifact,
    match.artifact_path AS similar_artifact,
    match.semantic_summary,
    match.complexity_score,
    match.criticality_level
FROM ai_agent_discovery_index base
CROSS JOIN ai_agent_discovery_index match
WHERE base.artifact_path != match.artifact_path
  AND (
      base.ecological_planes LIKE '%' || match.ecological_planes || '%'
      OR base.purpose_keywords LIKE '%' || match.purpose_keywords || '%'
  )
ORDER BY base.artifact_path, match.complexity_score DESC;
*/

-- ============================================================================
-- 9. Final Index for AI Chat Platform Quick Lookup
-- ============================================================================

-- Summary view for rapid AI chat platform context injection
DROP VIEW IF EXISTS v_econet_ai_quick_context;

CREATE VIEW v_econet_ai_quick_context AS
SELECT
    'ARTIFACT:' || d.artifact_path AS context_marker,
    d.artifact_type,
    d.repo_target,
    d.role_band || '/' || d.lane_default AS role_lane,
    d.semantic_summary AS description,
    d.purpose_keywords AS searchable_terms,
    COALESCE(e.plane_relationships, 'NO_PLANE_XREF') AS ecological_context,
    COALESCE(k.natural_language, 'NO_KER_CONTEXT') AS ker_context,
    d.criticality_level,
    d.updated_utc
FROM ai_agent_discovery_index d
LEFT JOIN (
    SELECT artifact_path, GROUP_CONCAT(plane_name || ':' || relationship_type) AS plane_relationships
    FROM ecological_plane_xref
    GROUP BY artifact_path
) e ON e.artifact_path = d.artifact_path
LEFT JOIN ker_context_registry k ON k.context_type = 'KER_TARGET'
ORDER BY d.criticality_level DESC, d.updated_utc DESC;
