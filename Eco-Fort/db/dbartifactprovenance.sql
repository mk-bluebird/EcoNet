-- filename: dbartifactprovenance.sql
-- destination: Eco-Fort/db/dbartifactprovenance.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS artifactprovenance (
    provenanceid      INTEGER PRIMARY KEY AUTOINCREMENT,

    artifactid        INTEGER NOT NULL
                         REFERENCES artifactregistry(artifactid)
                         ON DELETE CASCADE,

    cirunid           TEXT    NOT NULL,
    workflowfile      TEXT    NOT NULL,
    reposlug          TEXT    NOT NULL,

    energymode        TEXT    NOT NULL, -- LOWPOWER,BALANCED,HIGHTHROUGHPUT
    status            TEXT    NOT NULL CHECK (status IN ('COMPLETED','FAILED','CANCELLED')),

    lane              TEXT    NOT NULL CHECK (lane IN ('RESEARCH','EXPPROD','PROD')),
    kmetric           REAL    NOT NULL,
    emetric           REAL    NOT NULL,
    rmetric           REAL    NOT NULL,
    vtmax             REAL    NOT NULL,
    kerdeployable     INTEGER NOT NULL CHECK (kerdeployable IN (0,1)),

    rohanchorhex      TEXT,
    planecontractid   INTEGER REFERENCES planeweightscontract(contractid) ON DELETE SET NULL,

    lanestatusid      INTEGER REFERENCES lanestatusverdict(verdictid) ON DELETE SET NULL,

    createdutc        TEXT    NOT NULL,
    updatedutc        TEXT    NOT NULL,

    UNIQUE (artifactid, cirunid)
);

CREATE INDEX IF NOT EXISTS idx_prov_artifact
    ON artifactprovenance (artifactid);

CREATE INDEX IF NOT EXISTS idx_prov_cirun
    ON artifactprovenance (cirunid);

CREATE INDEX IF NOT EXISTS idx_prov_repo_lane
    ON artifactprovenance (reposlug, lane, status);
