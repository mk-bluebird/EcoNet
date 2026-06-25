-- filename: dbmt6883coursewindow.sql
-- destination: Eco-Fort/db/dbmt6883coursewindow.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS mt6883_course_window_2026 (
  courseid              TEXT PRIMARY KEY,
  citizenid             TEXT NOT NULL,
  hardwarefamily        TEXT NOT NULL,
  hardwareprofile       TEXT NOT NULL,

  twindow_start_utc     TEXT NOT NULL,
  twindow_end_utc       TEXT NOT NULL,

  roh_scalar_norm       REAL NOT NULL, -- 0..1
  roh_ceiling_norm      REAL NOT NULL, -- usually 0.30
  pain_debt_norm        REAL NOT NULL,
  eco_stress_norm       REAL NOT NULL,
  nanoswarm_burden_norm REAL NOT NULL,

  continuity_grade      TEXT NOT NULL CHECK (continuity_grade IN ('A','B','C')),
  continuity_ab_share   REAL NOT NULL, -- 0..1
  psych_continuity_pressure REAL NOT NULL, -- 0..1

  Ei_course             REAL NOT NULL,
  Ci_course             REAL NOT NULL,
  Si_course             REAL NOT NULL,
  Ki_course             REAL NOT NULL,

  reward_ker_sum        REAL,
  reward_unit           TEXT,
  reward_ledger_batchid TEXT,

  continuity_proofhex   TEXT NOT NULL,
  rohchainhex           TEXT NOT NULL,
  nonrollback_anchorid  TEXT NOT NULL,

  mt6883registryid      INTEGER,
  createdutc            TEXT NOT NULL,
  updatedutc            TEXT NOT NULL,

  FOREIGN KEY (mt6883registryid)
    REFERENCES mt6883registry(registryid)
    ON DELETE SET NULL
);

-- RoH must respect its ceiling.
CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_roh_ceiling_ins
BEFORE INSERT ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.roh_scalar_norm > NEW.roh_ceiling_norm
      THEN RAISE(ABORT, 'roh_scalar_norm exceeds roh_ceiling_norm for mt6883 course window')
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_roh_ceiling_upd
BEFORE UPDATE ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.roh_scalar_norm > NEW.roh_ceiling_norm
      THEN RAISE(ABORT, 'roh_scalar_norm exceeds roh_ceiling_norm for mt6883 course window')
    END;
END;

-- Continuity AB share and psych pressure must be within [0,1].
CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_bounds_ins
BEFORE INSERT ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.continuity_ab_share < 0.0 OR NEW.continuity_ab_share > 1.0
      THEN RAISE(ABORT, 'continuity_ab_share must be in [0,1]')
      WHEN NEW.psych_continuity_pressure < 0.0 OR NEW.psych_continuity_pressure > 1.0
      THEN RAISE(ABORT, 'psych_continuity_pressure must be in [0,1]')
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_bounds_upd
BEFORE UPDATE ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.continuity_ab_share < 0.0 OR NEW.continuity_ab_share > 1.0
      THEN RAISE(ABORT, 'continuity_ab_share must be in [0,1]')
      WHEN NEW.psych_continuity_pressure < 0.0 OR NEW.psych_continuity_pressure > 1.0
      THEN RAISE(ABORT, 'psych_continuity_pressure must be in [0,1]')
    END;
END;

-- Psych continuity pressure must be at least max(rohrisk, pain, eco_stress).
CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_psych_pressure_ins
BEFORE INSERT ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.psych_continuity_pressure < MAX(NEW.roh_scalar_norm, NEW.pain_debt_norm, NEW.eco_stress_norm)
      THEN RAISE(ABORT, 'psych_continuity_pressure must be >= max(rohrisk, pain, eco_stress)')
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_mt6883_course_psych_pressure_upd
BEFORE UPDATE ON mt6883_course_window_2026
BEGIN
  SELECT
    CASE
      WHEN NEW.psych_continuity_pressure < MAX(NEW.roh_scalar_norm, NEW.pain_debt_norm, NEW.eco_stress_norm)
      THEN RAISE(ABORT, 'psych_continuity_pressure must be >= max(rohrisk, pain, eco_stress)')
    END;
END;

-- Non-rollback anchor must be non-empty; coupling to NonRollbackProvenanceAnchor is enforced via FK if present.
-- We assume a nonrollbackprovenanceanchor table exists with primary key anchorid.
CREATE TABLE IF NOT EXISTS nonrollbackprovenanceanchor (
  anchorid        TEXT PRIMARY KEY,
  objecttype      TEXT NOT NULL,
  objectid        TEXT NOT NULL,
  contenthashhex  TEXT NOT NULL,
  rohanchorhex    TEXT NOT NULL,
  timestamputc    TEXT NOT NULL,
  active          INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

-- Soft link from course window to anchor; cannot delete anchor rows.
CREATE TRIGGER IF NOT EXISTS trg_nonrollback_anchor_nodelete
BEFORE DELETE ON nonrollbackprovenanceanchor
BEGIN
  SELECT RAISE(ABORT, 'DELETE forbidden on nonrollbackprovenanceanchor; use compensating events');
END;

-- Optional helper view: join MT6883 course windows into shardinstance and mt6883registry for continuity checks.
CREATE VIEW IF NOT EXISTS v_mt6883_course_with_spine_2026 AS
SELECT
  cw.courseid,
  cw.citizenid,
  cw.hardwarefamily,
  cw.hardwareprofile,
  cw.twindow_start_utc,
  cw.twindow_end_utc,
  cw.roh_scalar_norm,
  cw.roh_ceiling_norm,
  cw.pain_debt_norm,
  cw.eco_stress_norm,
  cw.nanoswarm_burden_norm,
  cw.continuity_grade,
  cw.continuity_ab_share,
  cw.psych_continuity_pressure,
  cw.Ei_course,
  cw.Ci_course,
  cw.Si_course,
  cw.Ki_course,
  cw.reward_ker_sum,
  cw.reward_unit,
  cw.reward_ledger_batchid,
  cw.continuity_proofhex,
  cw.rohchainhex,
  cw.nonrollback_anchorid,
  cw.mt6883registryid,
  m.rohrisk         AS rohrisk_registry,
  m.kerband         AS kerband_registry,
  m.continuitygrade AS continuitygrade_registry,
  m.lane            AS lane_registry,
  m.vtresidualest   AS vt_registry
FROM mt6883_course_window_2026 cw
LEFT JOIN mt6883registry m
  ON cw.mt6883registryid = m.registryid;
