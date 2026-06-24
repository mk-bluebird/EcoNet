-- filename: dbartifactregistry.sql
-- destination: Eco-Fort/db/dbartifactregistry.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS artifactregistry (
    artifactid        INTEGER PRIMARY KEY AUTOINCREMENT,
    repoid            INTEGER NOT NULL REFERENCES repo(repoid) ON DELETE CASCADE,
    repofileid        INTEGER NOT NULL REFERENCES repofile(fileid) ON DELETE CASCADE,
    shardid           INTEGER REFERENCES shardinstance(shardid) ON DELETE SET NULL,
    catalogid         INTEGER REFERENCES qpushardcatalog(shardid) ON DELETE SET NULL,
    mt6883registryid  INTEGER REFERENCES mt6883registry(registryid) ON DELETE SET NULL,

    repotarget        TEXT    NOT NULL,
    destinationpath   TEXT    NOT NULL,
    filename          TEXT    NOT NULL,
    fileext           TEXT    NOT NULL,
    artifactkind      TEXT    NOT NULL,

    contenthash       TEXT    NOT NULL,
    sizebytes         INTEGER,

    primaryplane      TEXT    NOT NULL,
    secondaryplanes   TEXT,
    lane              TEXT    NOT NULL CHECK (lane IN ('RESEARCH','EXPPROD','PROD')),
    kerband           TEXT    NOT NULL CHECK (kerband IN ('SAFE','GUARDED','BLOCKED')),
    planecontractid   INTEGER REFERENCES planeweightscontract(contractid) ON DELETE SET NULL,
    blastradiusid     INTEGER REFERENCES blastradiusobject(broid)       ON DELETE SET NULL,

    kmetric           REAL,
    emetric           REAL,
    rmetric           REAL,
    vtmax             REAL,
    kerdeployable     INTEGER NOT NULL DEFAULT 0 CHECK (kerdeployable IN (0,1)),

    evidencehex       TEXT    NOT NULL,
    rohanchorhex      TEXT,
    signingdid        TEXT    NOT NULL,
    provenancehex     TEXT,

    createdutc        TEXT    NOT NULL,
    updatedutc        TEXT    NOT NULL,

    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),

    UNIQUE (repoid, destinationpath, filename, contenthash)
);

CREATE INDEX IF NOT EXISTS idx_artifact_repo_file
    ON artifactregistry (repoid, repofileid);

CREATE INDEX IF NOT EXISTS idx_artifact_lane_plane
    ON artifactregistry (lane, primaryplane, kerband);

CREATE INDEX IF NOT EXISTS idx_artifact_hash
    ON artifactregistry (contenthash);

CREATE INDEX IF NOT EXISTS idx_artifact_active
    ON artifactregistry (active);

-- Trigger: forbid repoid/contenthash changes after insert.
CREATE TRIGGER IF NOT EXISTS trg_artifactregistry_no_repoid_update
BEFORE UPDATE OF repoid ON artifactregistry
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'artifactregistry.repoid is immutable');
END;

CREATE TRIGGER IF NOT EXISTS trg_artifactregistry_no_contenthash_update
BEFORE UPDATE OF contenthash ON artifactregistry
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'artifactregistry.contenthash is immutable');
END;
