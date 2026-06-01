-- filename: db/db_econet_file_index.sql
-- destination: EcoNet/db/db_econet_file_index.sql
-- purpose: Minimal, GitHub-ready index table guiding AI agents and
--          coding tools to where files belong in the EcoNet constellation.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS econet_file_index (
    file_index_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    filename        TEXT NOT NULL,
    destination     TEXT NOT NULL,
    repo_target     TEXT NOT NULL,    -- e.g. EcoNet, Eco-Fort, eco_restoration_shard
    role_band       TEXT NOT NULL,    -- SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP
    lane_default    TEXT NOT NULL,    -- RESEARCH, EXPPROD, PROD
    description     TEXT NOT NULL,
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL,
    CHECK (role_band IN ('SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP')),
    CHECK (lane_default IN ('RESEARCH','EXPPROD','PROD')),
    UNIQUE (filename, destination, repo_target)
);

-- Seed rows for the artifacts defined in this answer (commented).
/*
INSERT OR IGNORE INTO econet_file_index (
    filename, destination, repo_target, role_band, lane_default,
    description, created_utc, updated_utc
) VALUES
(
    'db_econet_constellation_research_spine.sql',
    'EcoNet/db/db_econet_constellation_research_spine.sql',
    'EcoNet',
    'SPINE',
    'RESEARCH',
    'Non-actuating research spine schema for blast radius links, workload ledger, and KER targets.',
    datetime('now'), datetime('now')
),
(
    'lib.rs',
    'EcoNet/crates/eco_research_spine/src/lib.rs',
    'EcoNet',
    'SPINE',
    'RESEARCH',
    'Rust non-actuating research spine helper crate exposing JSON cdylib-style functions.',
    datetime('now'), datetime('now')
),
(
    'db_econet_file_index.sql',
    'EcoNet/db/db_econet_file_index.sql',
    'EcoNet',
    'SPINE',
    'RESEARCH',
    'Constellation-wide file index for AI agents and orchestration.',
    datetime('now'), datetime('now')
);
*/
