-- filename: dbhealthcareriskplanes.sql
-- destination: Eco-Fort/db/dbhealthcareriskplanes.sql

PRAGMA foreign_keys = ON;

-- Plane-level metadata, linked to ecosafety grammar plane registry.
CREATE TABLE IF NOT EXISTS healthcareriskplane_meta_2026 (
  defid              TEXT PRIMARY KEY,                -- "HealthcareRiskPlane2026v1"
  description        TEXT NOT NULL,
  contractid         TEXT NOT NULL,                   -- "RoH.Healthcare.2026v1"
  primaryplane       TEXT NOT NULL CHECK (primaryplane = 'healthcare'),
  baserange_min      REAL NOT NULL,
  baserange_max      REAL NOT NULL,
  roh_global_ceiling REAL NOT NULL,                  -- 0.30
  nonoffsettable     INTEGER NOT NULL CHECK (nonoffsettable IN (0,1)),
  proofrefhex        TEXT NOT NULL,
  createdutc         TEXT NOT NULL,
  updatedutc         TEXT NOT NULL
);

-- Coordinate definitions mapping into the healthcare plane.
CREATE TABLE IF NOT EXISTS healthcareriskcoordinate_2026 (
  coordid        TEXT PRIMARY KEY,
  description    TEXT NOT NULL,
  valuemin       REAL NOT NULL,
  valuemax       REAL NOT NULL,
  nonoffsettable INTEGER NOT NULL CHECK (nonoffsettable IN (0,1)),
  band_green_max REAL,
  band_amber_max REAL,
  band_red_max   REAL,
  raw_source     TEXT NOT NULL,
  contributes_to TEXT NOT NULL CHECK (contributes_to IN ('K','E','R')),
  createdutc     TEXT NOT NULL,
  updatedutc     TEXT NOT NULL
);

-- Invariant: non-offsettable coordinates must contribute to R.
CREATE TRIGGER IF NOT EXISTS trg_healthcare_coord_nonoffsettable_r
BEFORE INSERT ON healthcareriskcoordinate_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.nonoffsettable = 1 AND NEW.contributes_to <> 'R'
      THEN RAISE(ABORT, 'nonoffsettable healthcare coordinates must contribute to R') 
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_healthcare_coord_nonoffsettable_r_update
BEFORE UPDATE ON healthcareriskcoordinate_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.nonoffsettable = 1 AND NEW.contributes_to <> 'R'
      THEN RAISE(ABORT, 'nonoffsettable healthcare coordinates must contribute to R')
    END;
END;

-- Optional: view binding this plane into the generic ecosafety plane registry, if present.
-- Assumes ecosafety plane table is named 'plane' with 'planeid' and 'nonoffsettable' columns.
CREATE VIEW IF NOT EXISTS v_healthcareriskplane_2026 AS
SELECT
  p.planeid,
  p.name            AS planename,
  hp.defid          AS healthplane_defid,
  hp.contractid,
  hp.roh_global_ceiling,
  hp.nonoffsettable AS plane_nonoffsettable
FROM plane p
JOIN healthcareriskplane_meta_2026 hp
  ON p.name = hp.primaryplane
WHERE hp.defid = 'HealthcareRiskPlane2026v1';
