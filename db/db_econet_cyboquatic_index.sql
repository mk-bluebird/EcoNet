-- filename: db_econet_cyboquatic_index.sql
-- destination: EcoNet/db/db_econet_cyboquatic_index.sql

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Constellation file index (you already use this pattern)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS econetfileindex (
    fileindexid   INTEGER PRIMARY KEY AUTOINCREMENT,
    filename      TEXT NOT NULL,
    destination   TEXT NOT NULL,
    repotarget    TEXT NOT NULL,  -- e.g. EcoNet, eco_restoration_shard, Cyboquatics
    roleband      TEXT NOT NULL,  -- SPINE, RESEARCH, ENGINE, MATERIAL, GOV, APP
    lanedefault   TEXT NOT NULL,  -- RESEARCH, EXPPROD, PROD
    description   TEXT NOT NULL,
    createdutc    TEXT NOT NULL,
    updatedutc    TEXT NOT NULL,
    CHECK (roleband IN ('SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP')),
    CHECK (lanedefault IN ('RESEARCH','EXPPROD','PROD')),
    UNIQUE (filename, destination, repotarget)
);

----------------------------------------------------------------------
-- 2. Blast-radius links for Cyboquatic machinery
--    (you already have this exact table; here we keep it consistent)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS blastradiuslink (
    linkid        INTEGER PRIMARY KEY AUTOINCREMENT,
    sourcetype    TEXT NOT NULL CHECK (sourcetype IN ('REPO','SCHEMA','PARTICLE','SHARD','NODE')),
    sourceid      TEXT NOT NULL,
    targettype    TEXT NOT NULL CHECK (targettype IN ('NODE','SHARD','MACHINE','MATERIAL','REGION')),
    targetid      TEXT NOT NULL,
    impacttype    TEXT NOT NULL,  -- ENERGY, CARBON, MATERIALS, BIODIVERSITY, DATAQUALITY, HYDRAULICS
    impactscore   REAL NOT NULL,  -- 0..1
    vtsensitivity REAL,           -- optional Lyapunov sensitivity scalar
    notes         TEXT,
    createdutc    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_blast_radius_source
    ON blastradiuslink (sourcetype, sourceid, impacttype);

CREATE INDEX IF NOT EXISTS idx_blast_radius_target
    ON blastradiuslink (targettype, targetid, impacttype);

----------------------------------------------------------------------
-- 3. Cyboquatic workload ledger for energy/carbon/materials/biodiversity
--    (kept non-actuating; records evidence only)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cyboworkloadledger (
    ledgerid      INTEGER PRIMARY KEY AUTOINCREMENT,
    shardid       TEXT NOT NULL,
    variantid     TEXT NOT NULL,
    nodeid        TEXT NOT NULL,
    channel       TEXT NOT NULL CHECK (channel IN ('energy','carbon','materials','biodiversity')),
    ereqj         REAL NOT NULL,  -- requested energy J
    esurplusj     REAL NOT NULL,  -- surplus or recuperated energy J
    rcarbon       REAL,           -- risk coordinate for carbon plane 0..1
    rbiodiv       REAL,           -- risk coordinate for biodiversity plane 0..1
    vtbefore      REAL NOT NULL,  -- Lyapunov residual before decision
    vtafter       REAL NOT NULL,  -- Lyapunov residual after decision
    decision      TEXT NOT NULL CHECK (decision IN ('ACCEPT','REJECT','REROUTE')),
    timestamputc  TEXT NOT NULL,
    createdutc    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_cyboworkload_node_time
    ON cyboworkloadledger (nodeid, timestamputc);

CREATE INDEX IF NOT EXISTS idx_cyboworkload_shard_channel
    ON cyboworkloadledger (shardid, channel);

----------------------------------------------------------------------
-- 4. View for workload trends (energy and residuals per node/channel)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_cybo_workload_trends AS
SELECT
    nodeid,
    channel,
    SUM(ereqj)       AS totalrequestsj,
    SUM(esurplusj)   AS totalsurplusj,
    AVG(vtbefore)    AS meanvtbefore,
    AVG(vtafter)     AS meanvtafter,
    AVG(rcarbon)     AS meanrcarbon,
    AVG(rbiodiv)     AS meanrbiodiv
FROM cyboworkloadledger
GROUP BY nodeid, channel;

----------------------------------------------------------------------
-- 5. Seed econetfileindex rows for AI/agent discovery
----------------------------------------------------------------------

INSERT OR IGNORE INTO econetfileindex
    (filename, destination, repotarget, roleband, lanedefault, description,
     createdutc, updatedutc)
VALUES
    ('db_econet_cyboquatic_index.sql',
     'EcoNet/db/db_econet_cyboquatic_index.sql',
     'EcoNet',
     'SPINE',
     'RESEARCH',
     'Non-actuating Cyboquatic blast-radius and workload evidence index for Phoenix and related nodes.',
     strftime('%Y-%m-%dT%H:%M:%SZ','now'),
     strftime('%Y-%m-%dT%H:%M:%SZ','now'));
