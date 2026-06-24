-- filename: dblanestatusverdict.sql
-- destination: Eco-Fort/db/dblanestatusverdict.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS lanestatusverdict (
    verdictid        INTEGER PRIMARY KEY AUTOINCREMENT,
    shardid          INTEGER REFERENCES shardinstance(shardid) ON DELETE CASCADE,
    artifactid       INTEGER REFERENCES artifactregistry(artifactid) ON DELETE SET NULL,
    region           TEXT    NOT NULL,
    lane_prev        TEXT    NOT NULL CHECK (lane_prev IN ('RESEARCH','EXPPROD','PROD')),
    lane_next        TEXT    NOT NULL CHECK (lane_next IN ('RESEARCH','EXPPROD','PROD')),
    kmetric_prev     REAL    NOT NULL,
    emetric_prev     REAL    NOT NULL,
    rmetric_prev     REAL    NOT NULL,
    vtmax_prev       REAL    NOT NULL,
    kmetric_next     REAL    NOT NULL,
    emetric_next     REAL    NOT NULL,
    rmetric_next     REAL    NOT NULL,
    vtmax_next       REAL    NOT NULL,
    verdict          TEXT    NOT NULL CHECK (verdict IN ('APPROVE','REJECT')),
    reasonhex        TEXT    NOT NULL,
    routingspechex   TEXT,
    createdutc       TEXT    NOT NULL,
    UNIQUE (artifactid, lane_next, createdutc)
);

CREATE INDEX IF NOT EXISTS idx_lanestatus_artifact_lane
    ON lanestatusverdict (artifactid, lane_next, verdict);
