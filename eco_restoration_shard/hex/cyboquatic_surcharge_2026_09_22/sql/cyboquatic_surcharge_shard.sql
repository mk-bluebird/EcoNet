PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;

CREATE TABLE IF NOT EXISTS canal_node (
    canal_node_id TEXT PRIMARY KEY,
    hex_cell_ref TEXT NOT NULL,
    node_kind TEXT NOT NULL CHECK (node_kind IN ('inlet', 'junction', 'outfall', 'wetland_cell')),
    design_flow_lps REAL NOT NULL CHECK (design_flow_lps > 0.0),
    ecological_buffer_m REAL NOT NULL CHECK (ecological_buffer_m >= 0.0 AND ecological_buffer_m <= 10000.0),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
    created_at_utc TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS ker_triad (
    ker_id TEXT PRIMARY KEY,
    knowledge_k REAL NOT NULL CHECK (knowledge_k BETWEEN 0.0 AND 1.0),
    ethics_e REAL NOT NULL CHECK (ethics_e BETWEEN 0.0 AND 1.0),
    resource_r REAL NOT NULL CHECK (resource_r BETWEEN 0.0 AND 1.0),
    review_status TEXT NOT NULL CHECK (review_status IN ('draft', 'reviewed', 'approved', 'expired')),
    reviewed_at_utc TEXT,
    CHECK (
        (review_status = 'approved' AND reviewed_at_utc IS NOT NULL)
        OR review_status <> 'approved'
    )
);

CREATE TABLE IF NOT EXISTS fog_predicate (
    fog_id TEXT PRIMARY KEY,
    media_type TEXT NOT NULL CHECK (
        media_type IN ('aqueous', 'sediment', 'biosolids', 'unmodeled')
    ),
    confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
    routing_action TEXT NOT NULL CHECK (
        routing_action IN ('accept_with_monitoring', 'hold_for_human_review', 'reject_isolate')
    ),
    requires_sample INTEGER NOT NULL CHECK (requires_sample IN (0, 1)),
    valid_until_utc TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS surcharge_observation (
    observation_id TEXT PRIMARY KEY,
    canal_node_id TEXT NOT NULL REFERENCES canal_node(canal_node_id) ON DELETE RESTRICT,
    ker_id TEXT NOT NULL REFERENCES ker_triad(ker_id) ON DELETE RESTRICT,
    fog_id TEXT NOT NULL REFERENCES fog_predicate(fog_id) ON DELETE RESTRICT,
    observed_at_utc TEXT NOT NULL,
    flow_lps REAL NOT NULL CHECK (flow_lps >= 0.0 AND flow_lps <= 1000000.0),
    surcharge_depth_m REAL NOT NULL CHECK (surcharge_depth_m >= 0.0 AND surcharge_depth_m <= 100.0),
    duration_s INTEGER NOT NULL CHECK (duration_s > 0 AND duration_s <= 604800),
    conductivity_us_cm REAL CHECK (conductivity_us_cm >= 0.0 AND conductivity_us_cm <= 200000.0),
    ph REAL CHECK (ph >= 0.0 AND ph <= 14.0),
    field_sensor_calibrated INTEGER NOT NULL CHECK (field_sensor_calibrated IN (0, 1)),
    sample_collected INTEGER NOT NULL CHECK (sample_collected IN (0, 1)),
    operator_note TEXT NOT NULL DEFAULT '',
    CHECK (length(operator_note) <= 1000)
);

CREATE TABLE IF NOT EXISTS surcharge_blast_radius (
    observation_id TEXT PRIMARY KEY REFERENCES surcharge_observation(observation_id) ON DELETE RESTRICT,
    base_radius_m REAL NOT NULL CHECK (base_radius_m >= 0.0 AND base_radius_m <= 10000.0),
    uncertainty_radius_m REAL NOT NULL CHECK (uncertainty_radius_m >= 0.0 AND uncertainty_radius_m <= 10000.0),
    review_radius_m REAL NOT NULL CHECK (review_radius_m >= base_radius_m AND review_radius_m <= 20000.0),
    severity_band TEXT NOT NULL CHECK (severity_band IN ('low', 'moderate', 'high', 'critical')),
    disposition TEXT NOT NULL CHECK (
        disposition IN ('monitor', 'hold_for_human_review', 'isolate_and_escalate')
    ),
    calculated_at_utc TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    CHECK (
        (severity_band = 'low' AND disposition = 'monitor')
        OR (severity_band IN ('moderate', 'high') AND disposition = 'hold_for_human_review')
        OR (severity_band = 'critical' AND disposition = 'isolate_and_escalate')
    )
);

CREATE INDEX IF NOT EXISTS idx_surcharge_observation_node_time
    ON surcharge_observation(canal_node_id, observed_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_surcharge_observation_fog_time
    ON surcharge_observation(fog_id, observed_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_surcharge_blast_radius_review
    ON surcharge_blast_radius(review_radius_m DESC, severity_band);

CREATE VIEW IF NOT EXISTS v_surcharge_review_queue AS
SELECT
    o.observation_id,
    o.observed_at_utc,
    n.hex_cell_ref,
    n.canal_node_id,
    o.flow_lps,
    o.surcharge_depth_m,
    o.duration_s,
    f.media_type,
    f.confidence AS fog_confidence,
    b.review_radius_m,
    b.severity_band,
    b.disposition
FROM surcharge_observation AS o
JOIN canal_node AS n ON n.canal_node_id = o.canal_node_id
JOIN fog_predicate AS f ON f.fog_id = o.fog_id
JOIN surcharge_blast_radius AS b ON b.observation_id = o.observation_id
WHERE b.disposition <> 'monitor'
ORDER BY
    CASE b.severity_band
        WHEN 'critical' THEN 4
        WHEN 'high' THEN 3
        WHEN 'moderate' THEN 2
        ELSE 1
    END DESC,
    b.review_radius_m DESC,
    o.observed_at_utc ASC;
