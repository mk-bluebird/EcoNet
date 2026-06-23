// filename: crates/non_actuating_core/src/lib.rs
// repo: mk-bluebird/eco_restoration_shard
// destination: Eco-Fort/crates/non_actuating_core/src/lib.rs

#![forbid(unsafe_code)]
#![warn(missing_docs)]

use serde::{Deserialize, Serialize};

/// Lane in which a workload is allowed to run.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum Lane {
    Research,
    ExpProd,
    Prod,
}

/// Eco-impact annotation for a workload (static, not computed at runtime).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EcoImpactAnnotation {
    pub primary_plane: String,   // e.g. "CARBON", "HYDRO", "CYBOQUATIC"
    pub expected_k: f64,         // 0..1, knowledge factor
    pub expected_e: f64,         // 0..1, eco-impact factor
    pub expected_r: f64,         // 0..1, residual risk
}

/// Immutable, read-only DB handle (e.g., SQLite in RO mode).
pub trait ReadOnlyStore {
    /// Executes a parameterized SELECT query, returns rows as JSON.
    fn select_json(&self, sql: &str, params: &[(&str, &str)]) -> Result<String, String>;
}

/// Marker trait for pure, non-actuating workloads.
pub trait NonActuatingWorkload {
    /// Static name (used in DefinitionRegistry / MCP index).
    fn workload_name(&self) -> &'static str;

    /// Lane in which this workload is allowed to execute.
    fn allowed_lane(&self) -> Lane;

    /// Static eco-impact annotation for this workload.
    fn eco_annotation(&self) -> EcoImpactAnnotation;

    /// Main entrypoint: pure computation over immutable state.
    ///
    /// Inputs:
    /// - `store`: read-only store; implementation MUST guarantee no writes.
    /// - `input`: JSON representing workload-specific parameters.
    ///
    /// Output:
    /// - JSON advisory result (no actuation).
    fn run(&self, store: &dyn ReadOnlyStore, input: &str) -> Result<String, String>;
}
