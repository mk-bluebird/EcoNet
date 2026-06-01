-- filename: db/db_econet_constellation_research_spine.sql
-- destination: EcoNet/db/db_econet_constellation_research_spine.sql
-- purpose: Non‑actuating EcoNet research spine extensions:
--          - evidence-anchored blast radius links
--          - workload ledger for Lyapunov / KER history
--          - manifest-backed KER targets and repo wiring
--          - cross-repo index for EcoNet constellation orchestration

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Core lookup tables (reused patterns, minimal stubs if missing)
--    These are shaped to match the existing Eco-Fort / EcoNet spine
--    patterns so they can either:
--      a) reference already-existing tables, or
--      b) be created as thin, local mirrors in a research DB.
----------------------------------------------------------------------

-- Repository catalog (logical constellation members).
CREATE TABLE IF NOT EXISTS repo (
    repoid       INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL UNIQUE,
    role_band    TEXT NOT NULL,        -- SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP
    lane_default TEXT NOT NULL,        -- RESEARCH, EXPPROD, PROD
    region       TEXT,                 -- e.g. Phoenix-AZ
    created_utc  TEXT NOT NULL,
    updated_utc  TEXT NOT NULL,
    CHECK (role_band IN ('SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP'))
);

-- Individual files within a repo (paths used for manifests, DB shards, etc.).
CREATE TABLE IF NOT EXISTS repofile (
    fileid      INTEGER PRIMARY KEY AUTOINCREMENT,
    repoid      INTEGER NOT NULL REFERENCES repo(repoid) ON DELETE CASCADE,
    relpath     TEXT NOT NULL,
    filekind    TEXT NOT NULL,   -- SQL, DB, ALN, RUST, LUA, KOTLIN, DOC, OTHER
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    UNIQUE (repoid, relpath)
);

-- Node catalog (physical / virtual nodes in the constellation).
CREATE TABLE IF NOT EXISTS node (
    nodeid      TEXT PRIMARY KEY,
    region      TEXT NOT NULL,
    nodetype    TEXT NOT NULL,   -- CYBOQUATIC, HYDRO_NODE, SENSOR, ANDROID_UI, EDGE_LUA, OTHER
    description TEXT,
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL
);

-- Shard instances (logical workloads / kernels bound to nodes).
CREATE TABLE IF NOT EXISTS shardinstance (
    shard_id       TEXT PRIMARY KEY,
    nodeid         TEXT NOT NULL REFERENCES node(nodeid) ON DELETE CASCADE,
    repoid         INTEGER NOT NULL REFERENCES repo(repoid) ON DELETE CASCADE,
    kernel_name    TEXT NOT NULL,
    version_tag    TEXT NOT NULL,
    lane           TEXT NOT NULL,  -- RESEARCH, EXPPROD, PROD, DIAGNOSTIC
    vt_max         REAL,           -- cached Lyapunov residual snapshot if available
    k_score        REAL,           -- optional K snapshot
    e_score        REAL,           -- optional E snapshot
    r_score        REAL,           -- optional R snapshot
    created_utc    TEXT NOT NULL,
    updated_utc    TEXT NOT NULL,
    CHECK (lane IN ('RESEARCH','EXPPROD','PROD','DIAGNOSTIC'))
);

CREATE INDEX IF NOT EXISTS idx_shardinstance_node
    ON shardinstance(nodeid);

CREATE INDEX IF NOT EXISTS idx_shardinstance_repo
    ON shardinstance(repoid, lane);

----------------------------------------------------------------------
-- 2. Evidence-anchored blast radius links (research-only, non-actuating)
--    This extends the existing blast-radius grammar described in the
--    Eco-Fort / EcoNet spine so that Phoenix hydrology, MAR, and
--    biodegradable substrate evidence can be expressed as links between
--    sources and targets, per ecological plane, with Lyapunov sensitivity.
--
--    This is explicitly NON-ACTUATING: no command, no routing decision.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS blastradius_link (
    link_id          INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Source / target identifiers: may point at nodes, shards, materials, regions, etc.
    source_kind      TEXT NOT NULL,    -- NODE, SHARD, REGION, MATERIAL, ROUTE, OTHER
    source_id        TEXT NOT NULL,    -- nodeid, shard_id, region code, material key

    target_kind      TEXT NOT NULL,    -- NODE, SHARD, REGION, MATERIAL, ROUTE, OTHER
    target_id        TEXT NOT NULL,

    -- Ecological plane and impact semantics.
    impact_plane     TEXT NOT NULL,    -- HYDRAULIC, ENERGY, CARBON, BIODIVERSITY, DATA_QUALITY, TOPOLOGY, MATERIALS, RESTORATION
    impact_type      TEXT NOT NULL,    -- LOAD, BUFFER, MAR, SUBSTRATE, SURCHARGE, FOOTPRINT, CONNECTIVITY, OTHER

    -- Normalized impact score, 0..1, usually "fraction of corridor width affected".
    impact_score     REAL NOT NULL,    -- 0 <= impact_score <= 1
    impact_band      TEXT NOT NULL,    -- SAFE, GOLD, HARD, EXCEEDED
    impact_units     TEXT,             -- e.g. "fraction_of_corridor", "m^3/s", "kgCO2e", "index"

    -- Optional Lyapunov residual partial derivative dV_t / d(state_source)
    vt_sensitivity   REAL,             -- diagnostic only, sign indicates stabilizing vs destabilizing

    -- Approximate radius semantics mapped to EcoNet blast-radius grammar.
    radius_meters    INTEGER,          -- spatial envelope for the impact
    radius_hops      INTEGER,          -- graph hops along adjacencygraph
    radius_hours     INTEGER,          -- temporal envelope

    -- Evidence linkage: hydrological models, MAR studies, materials science.
    evidence_tag     TEXT NOT NULL,    -- short code, e.g. "PHX_HYDRO_BUFFER_2026V1"
    evidence_source  TEXT NOT NULL,    -- URL, DOI, or internal document key
    evidence_notes   TEXT,             -- short free-text summary of the evidence

    -- Governance and audit fields.
    region           TEXT NOT NULL,    -- e.g. Phoenix-AZ
    created_by       TEXT NOT NULL,    -- user or agent id
    created_utc      TEXT NOT NULL,
    updated_utc      TEXT NOT NULL,

    CHECK (impact_score >= 0.0 AND impact_score <= 1.0),
    CHECK (impact_band IN ('SAFE','GOLD','HARD','EXCEEDED')),
    CHECK (source_kind IN ('NODE','SHARD','REGION','MATERIAL','ROUTE','OTHER')),
    CHECK (target_kind IN ('NODE','SHARD','REGION','MATERIAL','ROUTE','OTHER'))
);

CREATE INDEX IF NOT EXISTS idx_blastradius_link_source
    ON blastradius_link(source_kind, source_id, impact_plane);

CREATE INDEX IF NOT EXISTS idx_blastradius_link_target
    ON blastradius_link(target_kind, target_id, impact_plane);

CREATE INDEX IF NOT EXISTS idx_blastradius_link_region_plane
    ON blastradius_link(region, impact_plane, impact_band);

-- View: shard-centric blast radius summary, for cdylib / clients.
DROP VIEW IF EXISTS v_shard_blastradius;

CREATE VIEW v_shard_blastradius AS
SELECT
    l.source_id              AS shard_id,
    l.impact_plane,
    l.impact_type,
    AVG(l.impact_score)      AS mean_impact_score,
    MAX(l.impact_score)      AS max_impact_score,
    MIN(l.radius_meters)     AS min_radius_m,
    MAX(l.radius_meters)     AS max_radius_m,
    MIN(l.radius_hours)      AS min_radius_h,
    MAX(l.radius_hours)      AS max_radius_h,
    MIN(l.vt_sensitivity)    AS min_vt_sensitivity,
    MAX(l.vt_sensitivity)    AS max_vt_sensitivity,
    COUNT(*)                 AS link_count
FROM blastradius_link AS l
WHERE l.source_kind = 'SHARD'
GROUP BY l.source_id, l.impact_plane, l.impact_type;

----------------------------------------------------------------------
-- 3. Cybo workload ledger (pure time-series, diagnostic only)
--    This is the research band log of node / shard workloads and their
--    Lyapunov / KER behaviour over time. It is deliberately restricted
--    to read-only consumers and CI, with no routing or actuation fields.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cybo_workload_ledger (
    event_id        INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Identity / scoping.
    nodeid          TEXT NOT NULL REFERENCES node(nodeid) ON DELETE CASCADE,
    shard_id        TEXT NOT NULL REFERENCES shardinstance(shard_id) ON DELETE CASCADE,
    region          TEXT NOT NULL,
    channel         TEXT NOT NULL,      -- ENERGY, HYDRAULIC, CARBON, BIODIVERSITY, MATERIALS, DATA_QUALITY, TOPOLOGY, OTHER

    -- Time window for the measurement / decision.
    t_start_ms      INTEGER NOT NULL,
    t_end_ms        INTEGER NOT NULL,

    -- Workload and energy fields (research, non-actuating).
    e_req_j         REAL,              -- requested energy in joules
    e_surplus_j     REAL,              -- surplus energy in joules
    workload_tag    TEXT,              -- optional label, e.g. "MAR_PILOT_PUMP_1"

    -- Normalized per-plane risks in [0,1] at decision time.
    r_energy        REAL,
    r_hydraulic     REAL,
    r_carbon        REAL,
    r_biodiv        REAL,
    r_materials     REAL,
    r_dataquality   REAL,
    r_topology      REAL,

    -- Lyapunov residual and safestep deltas.
    vt_before       REAL,              -- V_t before the step
    vt_after        REAL,              -- V_{t+1} after the step
    delta_vt        REAL,              -- vt_after - vt_before (redundant but handy)

    -- KER snapshot for this window (K,E,R in [0,1]).
    k_score         REAL,
    e_score         REAL,
    r_score         REAL,

    -- Verdict fields: these are DIAGNOSTIC ONLY and never interpreted
    -- as routing or actuation decisions; they mirror the governance grammar.
    kerdeployable   INTEGER NOT NULL DEFAULT 0,  -- 0 / 1, read-only diagnostic
    corridor_ok     INTEGER NOT NULL DEFAULT 0,  -- 0 / 1, all planes inside gate?
    notes           TEXT,

    created_by      TEXT NOT NULL,
    created_utc     TEXT NOT NULL,

    CHECK (t_end_ms >= t_start_ms),
    CHECK (kerdeployable IN (0,1)),
    CHECK (corridor_ok IN (0,1)),
    CHECK (r_energy      IS NULL OR (r_energy      >= 0.0 AND r_energy      <= 1.0)),
    CHECK (r_hydraulic   IS NULL OR (r_hydraulic   >= 0.0 AND r_hydraulic   <= 1.0)),
    CHECK (r_carbon      IS NULL OR (r_carbon      >= 0.0 AND r_carbon      <= 1.0)),
    CHECK (r_biodiv      IS NULL OR (r_biodiv      >= 0.0 AND r_biodiv      <= 1.0)),
    CHECK (r_materials   IS NULL OR (r_materials   >= 0.0 AND r_materials   <= 1.0)),
    CHECK (r_dataquality IS NULL OR (r_dataquality >= 0.0 AND r_dataquality <= 1.0)),
    CHECK (r_topology    IS NULL OR (r_topology    >= 0.0 AND r_topology    <= 1.0))
);

CREATE INDEX IF NOT EXISTS idx_cybo_ledger_node_time
    ON cybo_workload_ledger(nodeid, t_start_ms, t_end_ms);

CREATE INDEX IF NOT EXISTS idx_cybo_ledger_shard_time
    ON cybo_workload_ledger(shard_id, t_start_ms, t_end_ms);

CREATE INDEX IF NOT EXISTS idx_cybo_ledger_channel
    ON cybo_workload_ledger(channel);

-- View: rolling window summary per node, used by cdylib helpers.
DROP VIEW IF EXISTS v_cybo_workload_window;

CREATE VIEW v_cybo_workload_window AS
SELECT
    nodeid,
    region,
    MIN(t_start_ms)                         AS window_start_ms,
    MAX(t_end_ms)                           AS window_end_ms,
    COUNT(*)                                AS event_count,
    AVG(e_req_j)                            AS mean_e_req_j,
    AVG(e_surplus_j)                        AS mean_e_surplus_j,
    AVG(vt_before)                          AS mean_vt_before,
    AVG(vt_after)                           AS mean_vt_after,
    AVG(delta_vt)                           AS mean_delta_vt,
    AVG(k_score)                            AS mean_k,
    AVG(e_score)                            AS mean_e,
    AVG(r_score)                            AS mean_r,
    SUM(CASE WHEN kerdeployable = 1 THEN 1 ELSE 0 END) * 1.0
      / MAX(COUNT(*), 1)                    AS fraction_kerdeployable,
    SUM(CASE WHEN corridor_ok = 1 THEN 1 ELSE 0 END) * 1.0
      / MAX(COUNT(*), 1)                    AS fraction_corridor_ok
FROM cybo_workload_ledger
GROUP BY nodeid, region;

----------------------------------------------------------------------
-- 4. Standardized manifest-backed KER targets
--    These rows mirror the econet_repo_index + KER target grammar,
--    but are explicitly non-actuating and designed for research band
--    monitoring and cdylib lookup.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS econet_repo_index (
    repo_name       TEXT PRIMARY KEY,          -- matches repo.name
    role_band       TEXT NOT NULL,             -- SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP
    lane_default    TEXT NOT NULL,             -- RESEARCH, EXPPROD, PROD
    ker_target_k    REAL NOT NULL,             -- target K for this repo
    ker_target_e    REAL NOT NULL,             -- target E for this repo
    ker_target_r    REAL NOT NULL,             -- upper bound R for this repo
    primary_plane   TEXT NOT NULL,             -- ENERGY, HYDRAULIC, CARBON, ...
    nonactuating    INTEGER NOT NULL DEFAULT 1,
    manifest_path   TEXT NOT NULL,             -- .econet/econet_repo_index.sql location
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL,
    CHECK (role_band IN ('SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP')),
    CHECK (lane_default IN ('RESEARCH','EXPPROD','PROD')),
    CHECK (ker_target_k >= 0.0 AND ker_target_k <= 1.0),
    CHECK (ker_target_e >= 0.0 AND ker_target_e <= 1.0),
    CHECK (ker_target_r >= 0.0 AND ker_target_r <= 1.0),
    CHECK (nonactuating IN (0,1))
);

-- Hint table for AI agents and cdylib discovery.
CREATE TABLE IF NOT EXISTS econet_role_hint (
    repo_name       TEXT NOT NULL REFERENCES econet_repo_index(repo_name) ON DELETE CASCADE,
    domain_hint     TEXT NOT NULL,     -- e.g. HYDROLOGY, MAR, CYBOQUATIC, SUBSTRATE, ANDROID_UI, EDGE_LUA
    pilot_region    TEXT,              -- e.g. Phoenix-AZ
    primary_particles TEXT,            -- e.g. "CyboquaticEcoPlot, MAR buffers"
    notes           TEXT,
    PRIMARY KEY (repo_name, domain_hint)
);

-- Layer table describes internal architectural layers and contracts.
CREATE TABLE IF NOT EXISTS econet_layer (
    layer_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name       TEXT NOT NULL REFERENCES econet_repo_index(repo_name) ON DELETE CASCADE,
    layer_name      TEXT NOT NULL,     -- GRAMMAR, KERNEL, EDGESCRIPT, UI, INDEXER, CDYLIB
    languages       TEXT NOT NULL,     -- CSV: "Rust,Lua,Kotlin,SQL"
    contracts       TEXT NOT NULL,     -- e.g. 'NonActuatingWorkload; V_t non-increasing; ResearchOnly'
    nonactuating    INTEGER NOT NULL DEFAULT 1,
    created_utc     TEXT NOT NULL,
    UNIQUE (repo_name, layer_name),
    CHECK (nonactuating IN (0,1))
);

-- View: succinct KER targets for cdylib econet_get_ker_targets.
DROP VIEW IF EXISTS v_econet_ker_targets;

CREATE VIEW v_econet_ker_targets AS
SELECT
    e.repo_name,
    e.role_band,
    e.lane_default,
    e.ker_target_k,
    e.ker_target_e,
    e.ker_target_r,
    e.primary_plane,
    e.nonactuating,
    e.manifest_path,
    r.domain_hint,
    r.pilot_region,
    r.primary_particles
FROM econet_repo_index AS e
LEFT JOIN econet_role_hint AS r
  ON r.repo_name = e.repo_name;

----------------------------------------------------------------------
-- 5. Constellation-wide file index for research and orchestration
--    This table guides AI agents and cdylib helpers to locate SQLite,
--    ALN, Rust, Lua, and Kotlin artifacts participating in the research
--    spine, including Phoenix hydrology, MAR, and biodegradable substrate
--    evidence DBs. This is read-only for tooling; upgrades go through
--    existing governance migrations.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS econet_constellation_file_index (
    index_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name       TEXT NOT NULL REFERENCES econet_repo_index(repo_name) ON DELETE CASCADE,
    fileid          INTEGER REFERENCES repofile(fileid) ON DELETE SET NULL,
    logical_name    TEXT NOT NULL,   -- e.g. "ecosafetyindex", "lanestatus", "phoenix_mar_evidence"
    role_band       TEXT NOT NULL,   -- SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP
    db_role         TEXT,            -- TELEMETRY, GOVERNANCE, INDEX, EVIDENCE
    scope           TEXT NOT NULL,   -- CONSTELLATION, REGION, NODE
    region          TEXT,            -- Phoenix-AZ, Global, etc.
    nodeid          TEXT,            -- optional direct binding to node.nodeid
    connection_str  TEXT NOT NULL,   -- e.g. "file:ecosafetyindex.sqlite3?mode=ro"
    readonly        INTEGER NOT NULL DEFAULT 1,
    active          INTEGER NOT NULL DEFAULT 1,
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL,
    CHECK (role_band IN ('SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP')),
    CHECK (scope IN ('CONSTELLATION','REGION','NODE')),
    CHECK (readonly IN (0,1)),
    CHECK (active IN (0,1)),
    UNIQUE (repo_name, logical_name, scope, region, nodeid)
);

CREATE INDEX IF NOT EXISTS idx_econet_constellation_file_region
    ON econet_constellation_file_index(region, db_role, active);

CREATE INDEX IF NOT EXISTS idx_econet_constellation_file_node
    ON econet_constellation_file_index(nodeid, active);

-- View: front door for agents to resolve DB shards for a region and role.
DROP VIEW IF EXISTS v_econet_db_for_region;

CREATE VIEW v_econet_db_for_region AS
SELECT
    repo_name,
    logical_name,
    role_band,
    db_role,
    scope,
    region,
    nodeid,
    connection_str,
    readonly,
    active
FROM econet_constellation_file_index
WHERE active = 1;

----------------------------------------------------------------------
-- 6. Seed examples (commented) illustrating Phoenix research wiring.
--    These are safe, non-actuating templates; deployers can copy, edit,
--    and run them in migrations for actual environments.
----------------------------------------------------------------------

/*
-- Example: register eco_restoration_shard as a RESEARCH repo with KER targets.
INSERT OR IGNORE INTO econet_repo_index (
    repo_name, role_band, lane_default,
    ker_target_k, ker_target_e, ker_target_r,
    primary_plane, nonactuating, manifest_path,
    created_utc, updated_utc
) VALUES (
    'eco_restoration_shard',
    'RESEARCH',
    'RESEARCH',
    0.95, 0.90, 0.20,
    'HYDRAULIC',
    1,
    '.econet/econet_repo_index.sql',
    datetime('now'), datetime('now')
);

INSERT OR IGNORE INTO econet_role_hint (
    repo_name, domain_hint, pilot_region, primary_particles, notes
) VALUES (
    'eco_restoration_shard',
    'MAR',
    'Phoenix-AZ',
    'Hydrological buffers, MAR basins, biodegradable substrates',
    'Non-actuating research kernels for MAR and substrate kinetics; all routing remains in ENGINE repos.'
);

-- Example: register a Phoenix ecosafety index DB shard for research-only access.
INSERT OR IGNORE INTO econet_constellation_file_index (
    repo_name, fileid, logical_name, role_band, db_role,
    scope, region, nodeid, connection_str,
    readonly, active, created_utc, updated_utc
) VALUES (
    'EcoNet',
    NULL,
    'ecosafetyindex_phoenix',
    'SPINE',
    'GOVERNANCE',
    'REGION',
    'Phoenix-AZ',
    NULL,
    'file:ecosafetyindex_phx.sqlite3?mode=ro',
    1,
    1,
    datetime('now'), datetime('now')
);
*/
