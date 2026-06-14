// filename: actuator_orchestrator.rs
// destination: EcoNet/src/actuator_orchestrator.rs
//! High-level orchestrator that binds the safe FFI wrapper to the immutable 
//! risk logger, ensuring that any hardware fail-safe engagement is instantly 
//! and permanently recorded in the MT6883 ledger.

use crate::actuator_ffi::{Actuator, ActuatorMetrics};
use crate::mt6883_risk_logger::Mt6883RiskLogger;
use rusqlite::Connection;

pub struct ActuatorOrchestrator<'a> {
    actuator: Actuator,
    risk_logger: Mt6883RiskLogger<'a>,
}

impl<'a> ActuatorOrchestrator<'a> {
    pub fn new(
        node_did: &str,
        pitch_addr: u32,
        bypass_addr: u32,
        brake_addr: u32,
        db_conn: &'a Connection,
        signing_did: &str,
    ) -> Result<Self, String> {
        let actuator = Actuator::new(node_did, pitch_addr, bypass_addr, brake_addr)?;
        let risk_logger = Mt6883RiskLogger::new(db_conn, signing_did);

        Ok(Self { actuator, risk_logger })
    }

    /// Safely attempts to update the actuator. If the C++ layer rejects the 
    /// command or triggers a fail-safe due to Lyapunov/corridor violations, 
    /// this method automatically and immutably logs the event to the MT6883 
    /// risk ledger before returning.
    pub fn safe_update(
        &self,
        metrics: &ActuatorMetrics,
        target_pitch: f64,
        target_bypass: f64,
    ) -> Result<bool, String> {
        let success = self.actuator.update(metrics, target_pitch, target_bypass)?;

        if !success {
            // The C++ layer rejected the update or engaged fail-safe.
            // We must permanently record this in the immutable ledger.
            let reason = if self.actuator.is_locked() {
                "CORRIDOR_VIOLATION_OR_MANUAL_ISOLATION"
            } else {
                "UPDATE_REJECTED_BY_HARDWARE_LIMITS"
            };

            // This log is append-only and cannot be altered or deleted.
            self.risk_logger
                .log_actuator_fail_safe(self.actuator.node_did(), reason)
                .map_err(|e| format!("CRITICAL: Failed to log immutable risk event: {}", e))?;
            
            return Ok(false);
        }

        Ok(true)
    }

    /// Explicitly triggers emergency isolation and logs it immutably.
    pub fn force_isolate(&self, reason: &str) {
        self.actuator.emergency_isolate(reason);
        
        // Best-effort logging. If the DB is somehow unavailable, we still 
        // isolate the hardware, but we log the failure to isolate the *log*.
        if let Err(e) = self.risk_logger.log_actuator_fail_safe(self.actuator.node_did(), reason) {
            eprintln!("CRITICAL GOVERNANCE FAILURE: Hardware isolated, but risk ledger write failed: {}", e);
        }
    }

    pub fn is_locked(&self) -> bool {
        self.actuator.is_locked()
    }
}
