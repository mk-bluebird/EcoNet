// filename: crates/eco_research_spine/src/lib.rs
// destination: EcoNet/crates/eco_research_spine/src/lib.rs
// purpose: Non-actuating Rust cdylib-compatible helpers over the research
//          SQLite spine (blast radius links, workload ledger, KER targets).
//          All functions are read-only and return UTF‑8 JSON for Lua/Kotlin.

#![forbid(unsafe_code)]

use rusqlite::{params, Connection, Row};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct BlastRadiusLink {
    pub link_id: i64,
    pub source_kind: String,
    pub source_id: String,
    pub target_kind: String,
    pub target_id: String,
    pub impact_plane: String,
    pub impact_type: String,
    pub impact_score: f64,
    pub impact_band: String,
    pub impact_units: Option<String>,
    pub vt_sensitivity: Option<f64>,
    pub radius_meters: Option<i64>,
    pub radius_hops: Option<i64>,
    pub radius_hours: Option<i64>,
    pub evidence_tag: String,
    pub evidence_source: String,
    pub evidence_notes: Option<String>,
    pub region: String,
    pub created_utc: String,
    pub updated_utc: String,
}

fn map_blastradius_link(row: &Row<'_>) -> rusqlite::Result<BlastRadiusLink> {
    Ok(BlastRadiusLink {
        link_id: row.get(0)?,
        source_kind: row.get(1)?,
        source_id: row.get(2)?,
        target_kind: row.get(3)?,
        target_id: row.get(4)?,
        impact_plane: row.get(5)?,
        impact_type: row.get(6)?,
        impact_score: row.get(7)?,
        impact_band: row.get(8)?,
        impact_units: row.get(9)?,
        vt_sensitivity: row.get(10)?,
        radius_meters: row.get(11)?,
        radius_hops: row.get(12)?,
        radius_hours: row.get(13)?,
        evidence_tag: row.get(14)?,
        evidence_source: row.get(15)?,
        evidence_notes: row.get(16)?,
        region: row.get(17)?,
        created_utc: row.get(18)?,
        updated_utc: row.get(19)?,
    })
}

#[derive(Debug, Serialize)]
pub struct WorkloadWindowSummary {
    pub nodeid: String,
    pub region: String,
    pub window_start_ms: i64,
    pub window_end_ms: i64,
    pub event_count: i64,
    pub mean_e_req_j: f64,
    pub mean_e_surplus_j: f64,
    pub mean_vt_before: f64,
    pub mean_vt_after: f64,
    pub mean_delta_vt: f64,
    pub mean_k: f64,
    pub mean_e: f64,
    pub mean_r: f64,
    pub fraction_kerdeployable: f64,
    pub fraction_corridor_ok: f64,
}

fn map_workload_window(row: &Row<'_>) -> rusqlite::Result<WorkloadWindowSummary> {
    Ok(WorkloadWindowSummary {
        nodeid: row.get(0)?,
        region: row.get(1)?,
        window_start_ms: row.get(2)?,
        window_end_ms: row.get(3)?,
        event_count: row.get(4)?,
        mean_e_req_j: row.get(5)?,
        mean_e_surplus_j: row.get(6)?,
        mean_vt_before: row.get(7)?,
        mean_vt_after: row.get(8)?,
        mean_delta_vt: row.get(9)?,
        mean_k: row.get(10)?,
        mean_e: row.get(11)?,
        mean_r: row.get(12)?,
        fraction_kerdeployable: row.get(13)?,
        fraction_corridor_ok: row.get(14)?,
    })
}

#[derive(Debug, Serialize)]
pub struct KerTargets {
    pub repo_name: String,
    pub role_band: String,
    pub lane_default: String,
    pub ker_target_k: f64,
    pub ker_target_e: f64,
    pub ker_target_r: f64,
    pub primary_plane: String,
    pub nonactuating: bool,
    pub manifest_path: String,
    pub domain_hint: Option<String>,
    pub pilot_region: Option<String>,
    pub primary_particles: Option<String>,
}

fn map_ker_targets(row: &Row<'_>) -> rusqlite::Result<KerTargets> {
    let nonactuating_int: i64 = row.get(7)?;
    Ok(KerTargets {
        repo_name: row.get(0)?,
        role_band: row.get(1)?,
        lane_default: row.get(2)?,
        ker_target_k: row.get(3)?,
        ker_target_e: row.get(4)?,
        ker_target_r: row.get(5)?,
        primary_plane: row.get(6)?,
        nonactuating: nonactuating_int != 0,
        manifest_path: row.get(8)?,
        domain_hint: row.get(9)?,
        pilot_region: row.get(10)?,
        primary_particles: row.get(11)?,
    })
}

/// Open a read-only connection to the given SQLite DB.
fn open_readonly(db_path: &str) -> rusqlite::Result<Connection> {
    let mut flags = rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY;
    flags.insert(rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX);
    Connection::open_with_flags(db_path, flags)
}

/// Return all blast-radius links for a given shard as JSON (UTF‑8).
pub fn cybo_list_blastradius_for_shard_json(db_path: &str, shard_id: &str) -> Result<String, String> {
    let conn = open_readonly(db_path).map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT
                link_id, source_kind, source_id,
                target_kind, target_id,
                impact_plane, impact_type,
                impact_score, impact_band, impact_units,
                vt_sensitivity,
                radius_meters, radius_hops, radius_hours,
                evidence_tag, evidence_source, evidence_notes,
                region, created_utc, updated_utc
             FROM blastradius_link
             WHERE source_kind = 'SHARD' AND source_id = ?1
             ORDER BY impact_plane, impact_type, link_id",
        )
        .map_err(|e| e.to_string())?;

    let rows = stmt
        .query_map(params![shard_id], map_blastradius_link)
        .map_err(|e| e.to_string())?;

    let mut out = Vec::new();
    for r in rows {
        out.push(r.map_err(|e| e.to_string())?);
    }

    serde_json::to_string(&out).map_err(|e| e.to_string())
}

/// Return workload window summary for a node over a time range as JSON.
pub fn cybo_summarize_workload_window_json(
    db_path: &str,
    node_id: &str,
    t_start_ms: i64,
    t_end_ms: i64,
) -> Result<String, String> {
    let conn = open_readonly(db_path).map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT
                nodeid,
                region,
                MIN(t_start_ms) AS window_start_ms,
                MAX(t_end_ms)   AS window_end_ms,
                COUNT(*)        AS event_count,
                AVG(e_req_j),
                AVG(e_surplus_j),
                AVG(vt_before),
                AVG(vt_after),
                AVG(delta_vt),
                AVG(k_score),
                AVG(e_score),
                AVG(r_score),
                SUM(CASE WHEN kerdeployable = 1 THEN 1 ELSE 0 END) * 1.0
                  / MAX(COUNT(*), 1) AS fraction_kerdeployable,
                SUM(CASE WHEN corridor_ok = 1 THEN 1 ELSE 0 END) * 1.0
                  / MAX(COUNT(*), 1) AS fraction_corridor_ok
             FROM cybo_workload_ledger
             WHERE nodeid = ?1
               AND t_start_ms >= ?2
               AND t_end_ms   <= ?3
             GROUP BY nodeid, region",
        )
        .map_err(|e| e.to_string())?;

    let mut rows = stmt
        .query(params![node_id, t_start_ms, t_end_ms])
        .map_err(|e| e.to_string())?;

    if let Some(row) = rows.next().transpose().map_err(|e| e.to_string())? {
        let summary = map_workload_window(&row).map_err(|e| e.to_string())?;
        serde_json::to_string(&summary).map_err(|e| e.to_string())
    } else {
        // return empty JSON object when no data
        Ok("{}".to_string())
    }
}

/// Return manifest-backed KER targets for a repository as JSON.
pub fn econet_get_ker_targets_json(db_path: &str, repo_name: &str) -> Result<String, String> {
    let conn = open_readonly(db_path).map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT
                repo_name,
                role_band,
                lane_default,
                ker_target_k,
                ker_target_e,
                ker_target_r,
                primary_plane,
                nonactuating,
                manifest_path,
                domain_hint,
                pilot_region,
                primary_particles
             FROM v_econet_ker_targets
             WHERE repo_name = ?1
             LIMIT 1",
        )
        .map_err(|e| e.to_string())?;

    let mut rows = stmt.query(params![repo_name]).map_err(|e| e.to_string())?;
    if let Some(row) = rows.next().transpose().map_err(|e| e.to_string())? {
        let targets = map_ker_targets(&row).map_err(|e| e.to_string())?;
        serde_json::to_string(&targets).map_err(|e| e.to_string())
    } else {
        Ok("{}".to_string())
    }
}
