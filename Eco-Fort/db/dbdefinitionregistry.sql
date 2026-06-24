-- filename: dbdefinitionregistry.sql
-- destination: Eco-Fort/db/dbdefinitionregistry.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS definitionregistry (
    definitionid   INTEGER PRIMARY KEY AUTOINCREMENT,
    logicalname    TEXT    NOT NULL,  -- e.g. 'artifact.registry.core.2026v1'
    repopath      TEXT    NOT NULL,   -- 'Eco-Fort/aln/ArtifactRegistryShard2026v1.aln'
    kind          TEXT    NOT NULL,   -- 'ALN'
    frozen        INTEGER NOT NULL DEFAULT 1 CHECK (frozen IN (0,1)),
    createdutc    TEXT    NOT NULL,
    updatedutc    TEXT    NOT NULL,
    UNIQUE (logicalname)
);

INSERT OR IGNORE INTO definitionregistry
    (logicalname, repopath, kind, frozen, createdutc, updatedutc)
VALUES
    ('artifact.registry.core.2026v1',
     'Eco-Fort/aln/ArtifactRegistryShard2026v1.aln',
     'ALN', 1, datetime('now'), datetime('now')),
    ('artifact.provenance.run.2026v1',
     'Eco-Fort/aln/ArtifactProvenanceRun2026v1.aln',
     'ALN', 1, datetime('now'), datetime('now'));
