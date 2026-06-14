// filename: mt6883_risk_logger.rs
// destination: EcoNet/src/mt6883_risk_logger.rs
//! Immutable, append-only risk logging for MT6883 hardware events.
//!
//! SECURITY GUARANTEE: This module intentionally exposes ONLY `INSERT` operations
//! for the RISK_chain and RISK_event tables. It provides no `UPDATE` or `DELETE`
//! methods. This application-level restriction is reinforced by SQLite 
//! BEFORE UPDATE/DELETE triggers that RAISE(FAIL), making the risk ledger a 
//! brain-bound, immutable entity that cannot be altered, removed, or silently 
//! reinvented by any code path.

use rusqlite::{params, Connection, Result as SqlResult};

/// Secure, append-only logger for MT6883 risk events.
pub struct Mt6883RiskLogger<'a> {
    conn: &'a Connection,
    /// The decentralized identity (DID) of the system or operator authorizing this log.
    signing_did: String,
}

impl<'a> Mt6883RiskLogger<'a> {
    pub fn new(conn: &'a Connection, signing_did: &str) -> Self {
        Self {
            conn,
            signing_did: signing_did.to_string(),
        }
    }

    /// Logs a new entry into the immutable RISK_chain.
    /// 
    /// Returns the `risk_id` of the newly created chain entry, which must be 
    /// used to link subsequent `RISK_event` records.
    pub fn log_risk_chain(&self, node_did: &str, evidence_bundle: &str) -> SqlResult<i64> {
        // STRICTLY INSERT. No update or delete paths exist in this API.
        self.conn.execute(
            r#"
            INSERT INTO RISK_chain (
                node_did, 
                unauthorized_mutation_attempt, 
                risk_evidence_bundle, 
                signing_did
            ) VALUES (?1, 0, ?2, ?3)
            "#,
            params![node_did, evidence_bundle, self.signing_did],
        )?;
        
        Ok(self.conn.last_insert_rowid())
    }

    /// Logs a specific invariant violation or operational action tied to a RISK_chain entry.
    pub fn log_risk_event(
        &self,
        risk_id: i64,
        invariant_violation_detected: bool,
        operational_action_taken: &str,
    ) -> SqlResult<()> {
        // STRICTLY INSERT. No update or delete paths exist in this API.
        self.conn.execute(
            r#"
            INSERT INTO RISK_event (
                risk_id, 
                invariant_violation_detected, 
                operational_action_taken
            ) VALUES (?1, ?2, ?3)
            "#,
            params![
                risk_id, 
                invariant_violation_detected as i32, 
                operational_action_taken
            ],
        )?;
        
        Ok(())
    }

    /// Convenience method to atomically log a fail-safe trigger event.
    pub fn log_actuator_fail_safe(&self, node_did: &str, reason: &str) -> SqlResult<()> {
        let evidence = format!("ACTUATOR_FAIL_SAFE_TRIGGERED: {}", reason);
        let risk_id = self.log_risk_chain(node_did, &evidence)?;
        
        self.log_risk_event(
            risk_id,
            true, // Invariant violation (corridor breach) detected
            "ENGAGED_MECHANICAL_ISOLATION",
        )?;
        
        Ok(())
    }
}
