-- filename: sql/econetrepoindex_cyboquatic_blastradius.sql
-- destination: eco_restoration_shard/sql/econetrepoindex_cyboquatic_blastradius.sql

PRAGMA foreign_keys = ON;

INSERT OR IGNORE INTO econetrepoindex (
    artifacttype,
    artifactpath,
    contenthashhex,
    signingdid,
    createdutc,
    evidencehex
)
VALUES (
    'ALN',
    'qpudatashards/CyboquaticBlastRadiusIndex2026v1.aln',
    '<ALNSPECHASHHEX_FROM_PROVENANCEKERNEL>',
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
    '2026-06-24T00:00:00Z',
    '<EVIDENCEHEX_FROM_PROVENANCEKERNEL>'
);
