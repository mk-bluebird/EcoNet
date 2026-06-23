// filename: crates/econet_ffi/src/lib.rs
// destination: Eco-Fort/crates/econet_ffi/src/lib.rs

#![forbid(unsafe_code)]

use non_actuating_core::{EcoImpactAnnotation, Lane, NonActuatingWorkload, ReadOnlySqlite};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Simple workload that reports node eco scores (advisory only).
pub struct NodeEcoScoreWorkload;

impl NonActuatingWorkload for NodeEcoScoreWorkload {
    fn workload_name(&self) -> &'static str {
        "econet_get_node_eco_scores"
    }

    fn allowed_lane(&self) -> Lane {
        Lane::Research
    }

    fn eco_annotation(&self) -> EcoImpactAnnotation {
        EcoImpactAnnotation {
            primary_plane: "CARBON".to_string(),
            expected_k: 0.9,
            expected_e: 0.9,
            expected_r: 0.12,
        }
    }

    fn run(&self, store: &dyn non_actuating_core::ReadOnlyStore, input: &str) -> Result<String, String> {
        #[derive(serde::Deserialize)]
        struct Input {
            region: String,
        }

        let parsed: Input = serde_json::from_str(input).map_err(|e| e.to_string())?;
        let sql = r#"
            SELECT nodeid, kscore, escore, rscore, vtmax, region
            FROM cybo_node_eco_score
            WHERE region = :region
        "#;

        store.select_json(sql, &[(":region", &parsed.region)])
    }
}

#[no_mangle]
pub extern "C" fn econet_get_node_eco_scores(
    db_path: *const c_char,
    input_json: *const c_char,
) -> *mut c_char {
    let c_db = unsafe { CStr::from_ptr(db_path) };
    let c_input = unsafe { CStr::from_ptr(input_json) };

    let path = match c_db.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };
    let input = match c_input.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let store = match ReadOnlySqlite::open(path) {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let workload = NodeEcoScoreWorkload;
    match workload.run(&store, input) {
        Ok(json) => CString::new(json).unwrap().into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn econet_free_json(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
