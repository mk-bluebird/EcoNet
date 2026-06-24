// filename: src/lib.rs
// destination: eco_restoration_shard/src/lib.rs
// crate-type: cdylib (configure in Cargo.toml)

#![forbid(unsafe_code)]

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

use rusqlite::{Connection, OpenFlags};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct KerTargets {
    pub reponame: String,
    pub roleband: String,
    pub kertargetk: f64,
    pub kertargete: f64,
    pub kertargetr: f64,
}

#[derive(Debug, Serialize)]
pub struct BlastRadiusEntry {
    pub sourcetype: String,
    pub sourceid: String,
    pub targettype: String,
    pub targetid: String,
    pub impacttype: String,
    pub impactscore: f64,
    pub vtsensitivity: f64,
    pub notes: String,
}

#[derive(Debug, Serialize)]
pub struct WorkloadTrendEntry {
    pub nodeid: String,
    pub channel: String,
    pub totalrequestsj: f64,
    pub totalsurplusj: f64,
    pub meanvtbefore: f64,
    pub meanvtafter: f64,
    pub meanrcarbon: Option<f64>,
    pub meanrbiodiv: Option<f64>,
}

// Internal: open read-only SQLite connection
fn open_ro_db(db_path: &str) -> rusqlite::Result<Connection> {
    let path = Path::new(db_path);
    Connection::open_with_flags(
        path,
        OpenFlags::SQLITE_OPEN_READONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
}

// Internal: query repo-level KER targets
fn query_ker_targets(conn: &Connection, reponame: &str) -> rusqlite::Result<KerTargets> {
    let mut stmt = conn.prepare(
        r#"SELECT reponame, roleband, kertargetk, kertargete, kertargetr
           FROM econetrepoindex
           WHERE reponame = ?1
           LIMIT 1"#,
    )?;
    stmt.query_row([reponame], |row| {
        Ok(KerTargets {
            reponame: row.get(0)?,
            roleband: row.get(1)?,
            kertargetk: row.get(2)?,
            kertargete: row.get(3)?,
            kertargetr: row.get(4)?,
        })
    })
}

// Internal: query blast-radius entries for a node
fn query_blast_radius(conn: &Connection, nodeid: &str) -> rusqlite::Result<Vec<BlastRadiusEntry>> {
    let mut stmt = conn.prepare(
        r#"SELECT sourcetype, sourceid, targettype, targetid,
                  impacttype, impactscore,
                  COALESCE(vtsensitivity, 0.0),
                  COALESCE(notes, '')
           FROM blastradiuslink
           WHERE sourcetype = 'NODE' AND sourceid = ?1
           ORDER BY impacttype, targettype, targetid"#,
    )?;

    let rows = stmt.query_map([nodeid], |row| {
        Ok(BlastRadiusEntry {
            sourcetype: row.get(0)?,
            sourceid: row.get(1)?,
            targettype: row.get(2)?,
            targetid: row.get(3)?,
            impacttype: row.get(4)?,
            impactscore: row.get(5)?,
            vtsensitivity: row.get(6)?,
            notes: row.get(7)?,
        })
    })?;

    let mut out = Vec::new();
    for r in rows {
        out.push(r?);
    }
    Ok(out)
}

// Internal: query workload trends for a node
fn query_workload_trends(
    conn: &Connection,
    nodeid: &str,
) -> rusqlite::Result<Vec<WorkloadTrendEntry>> {
    let mut stmt = conn.prepare(
        r#"SELECT nodeid, channel,
                  SUM(ereqj)       AS totalrequestsj,
                  SUM(esurplusj)   AS totalsurplusj,
                  AVG(vtbefore)    AS meanvtbefore,
                  AVG(vtafter)     AS meanvtafter,
                  AVG(rcarbon)     AS meanrcarbon,
                  AVG(rbiodiv)     AS meanrbiodiv
           FROM cyboworkloadledger
           WHERE nodeid = ?1
           GROUP BY nodeid, channel
           ORDER BY channel"#,
    )?;

    let rows = stmt.query_map([nodeid], |row| {
        Ok(WorkloadTrendEntry {
            nodeid: row.get(0)?,
            channel: row.get(1)?,
            totalrequestsj: row.get(2)?,
            totalsurplusj: row.get(3)?,
            meanvtbefore: row.get(4)?,
            meanvtafter: row.get(5)?,
            meanrcarbon: row.get(6)?,
            meanrbiodiv: row.get(7)?,
        })
    })?;

    let mut out = Vec::new();
    for r in rows {
        out.push(r?);
    }
    Ok(out)
}

// Helpers: C string <-> Rust string and JSON serialization

unsafe fn cstr_to_str(ptr: *const c_char) -> Result<&'static str, &'static str> {
    if ptr.is_null() {
        return Err("null pointer");
    }
    match CStr::from_ptr(ptr).to_str() {
        Ok(s) => Ok(s),
        Err(_) => Err("invalid UTF-8"),
    }
}

fn to_json_c_string<T: Serialize>(val: T) -> *mut c_char {
    match serde_json::to_string(&val) {
        Ok(json) => match CString::new(json) {
            Ok(c) => c.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

fn error_json(msg: &str) -> *mut c_char {
    let wrapper = serde_json::json!({ "error": msg });
    to_json_c_string(wrapper)
}

// C ABI: repo-level KER targets
#[no_mangle]
pub unsafe extern "C" fn econet_get_ker_targets(
    dbpath: *const c_char,
    reponame: *const c_char,
) -> *mut c_char {
    let db = match cstr_to_str(dbpath) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };
    let repo = match cstr_to_str(reponame) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };

    let conn = match open_ro_db(db) {
        Ok(c) => c,
        Err(_) => return error_json("failed to open SQLite index"),
    };

    match query_ker_targets(&conn, repo) {
        Ok(row) => to_json_c_string(row),
        Err(_) => error_json("repo not found"),
    }
}

// C ABI: blast-radius for a node
#[no_mangle]
pub unsafe extern "C" fn econet_get_blast_radius_for_node(
    dbpath: *const c_char,
    nodeid: *const c_char,
) -> *mut c_char {
    let db = match cstr_to_str(dbpath) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };
    let node = match cstr_to_str(nodeid) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };

    let conn = match open_ro_db(db) {
        Ok(c) => c,
        Err(_) => return error_json("failed to open SQLite index"),
    };

    match query_blast_radius(&conn, node) {
        Ok(rows) => to_json_c_string(rows),
        Err(_) => error_json("node not found or query failed"),
    }
}

// C ABI: workload trends for a node
#[no_mangle]
pub unsafe extern "C" fn econet_get_workload_trends_for_node(
    dbpath: *const c_char,
    nodeid: *const c_char,
) -> *mut c_char {
    let db = match cstr_to_str(dbpath) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };
    let node = match cstr_to_str(nodeid) {
        Ok(s) => s,
        Err(m) => return error_json(m),
    };

    let conn = match open_ro_db(db) {
        Ok(c) => c,
        Err(_) => return error_json("failed to open SQLite index"),
    };

    match query_workload_trends(&conn, node) {
        Ok(rows) => to_json_c_string(rows),
        Err(_) => error_json("node not found or query failed"),
    }
}

// C ABI: free JSON strings
#[no_mangle]
pub unsafe extern "C" fn econet_free_json(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = CString::from_raw(ptr);
}
