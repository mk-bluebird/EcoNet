-- filename: .econet/econet_repo_index.sql
-- destination: EcoNet/.econet/econet_repo_index.sql
-- Purpose:
-- - Ensure EcoNet’s own manifest is aligned with the same grammar.
-- - Declare KER targets for governance SPINE and Cyboquatic machinery coordination.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS econet_repo_index (
    repo_name            TEXT PRIMARY KEY,
    github_slug          TEXT NOT NULL,
    role_band            TEXT NOT NULL,
    visibility           TEXT NOT NULL,
    language_primary     TEXT NOT NULL,
    description          TEXT,
    ecosafety_binding    TEXT NOT NULL,
    shard_protocol       TEXT NOT NULL,
    lane_default         TEXT NOT NULL,
    ker_target_k         REAL NOT NULL CHECK (ker_target_k BETWEEN 0.0 AND 1.0 AND ker_target_k >= 0.95),
    ker_target_e         REAL NOT NULL CHECK (ker_target_e BETWEEN 0.0 AND 1.0 AND ker_target_e >= 0.92),
    ker_target_r         REAL NOT NULL CHECK (ker_target_r BETWEEN 0.0 AND 1.0 AND ker_target_r <= 0.12),
    non_actuating_only   INTEGER NOT NULL CHECK (non_actuating_only IN (0,1)),
    manifest_schema_ver  INTEGER NOT NULL DEFAULT 1,
    did_owner            TEXT NOT NULL,
    signing_did          TEXT,
    evidence_hex         TEXT
);

CREATE TABLE IF NOT EXISTS econet_layer (
    layer_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name   TEXT NOT NULL REFERENCES econet_repo_index(repo_name) ON DELETE CASCADE,
    layer_name  TEXT NOT NULL,
    layer_tier  TEXT NOT NULL,
    languages   TEXT NOT NULL,
    description TEXT,
    contracts   TEXT
);

CREATE TABLE IF NOT EXISTS econet_role_hint (
    hint_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name TEXT NOT NULL REFERENCES econet_repo_index(repo_name) ON DELETE CASCADE,
    hint_key  TEXT NOT NULL,
    hint_val  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_econet_repo_index_role
    ON econet_repo_index (role_band, visibility);
CREATE INDEX IF NOT EXISTS idx_econet_layer_repo
    ON econet_layer (repo_name, layer_tier);
CREATE INDEX IF NOT EXISTS idx_econet_role_hint_repo
    ON econet_role_hint (repo_name, hint_key);

INSERT OR REPLACE INTO econet_repo_index (
    repo_name,
    github_slug,
    role_band,
    visibility,
    language_primary,
    description,
    ecosafety_binding,
    shard_protocol,
    lane_default,
    ker_target_k,
    ker_target_e,
    ker_target_r,
    non_actuating_only,
    manifest_schema_ver,
    did_owner,
    signing_did,
    evidence_hex
) VALUES (
    'EcoNet',
    'mk-bluebird/EcoNet',
    'SPINE',
    'Public',
    'Rust',
    'Ecosafety spine and Cyboquatic governance kernel for the EcoNet constellation.',
    'ecosafety.corridors.v2',
    'EcoNetSchemaShard2026v1',
    'PROD',
    0.95,
    0.92,
    0.12,
    0,
    1,
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
    NULL,
    NULL
);

DELETE FROM econet_layer WHERE repo_name = 'EcoNet';
INSERT INTO econet_layer (
    repo_name, layer_name, layer_tier, languages, description, contracts
) VALUES
    (
        'EcoNet',
        'Ecosafety core',
        'GRAMMAR',
        'Rust',
        'Core Lyapunov residuals, risk vectors, corridor enforcement, and KER scoring.',
        'SpineKernel; acts as reference implementation of residual and KER; no hardware handles.'
    ),
    (
        'EcoNet',
        'Discovery spine',
        'KERNEL',
        'Rust',
        'SQLite-based discovery spine for repos, shards, workloads, and KER evidence.',
        'NonActuatingWorkload; may index workloads and manifests only; no actuator bindings.'
    ),
    (
        'EcoNet',
        'FFI JSON APIs',
        'EDGESCRIPT',
        'Rust,Lua,Kotlin',
        'Read-only JSON APIs that expose manifests and KER summaries to Lua edge harnesses and Kotlin visualizers.',
        'ReadOnlyClient; must not provide actuator or lane-change endpoints.'
    );

DELETE FROM econet_role_hint WHERE repo_name = 'EcoNet';
INSERT INTO econet_role_hint (repo_name, hint_key, hint_val) VALUES
    ('EcoNet', 'domain', 'ecosafety-governance'),
    ('EcoNet', 'ecoplane', 'energy,hydraulics,materials,carbon,biodiversity,dataquality,topology'),
    ('EcoNet', 'lanes', 'RESEARCH,EXPPROD,PROD'),
    ('EcoNet', 'non_actuating', 'false'),
    ('EcoNet', 'bostrom_did_primary', 'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7');
