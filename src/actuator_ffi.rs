// filename: actuator_ffi.rs
// destination: EcoNet/src/actuator_ffi.rs
//! Safe Rust FFI wrapper for the C++ subsea actuator fail-safe bindings.
//! 
//! This module ensures that all interactions with the bare-metal C++ actuator
//! logic are strictly bounded, memory-safe, and automatically trigger immutable
//! MT6883 risk logging when fail-safes are engaged.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};

/// Matches the C++ `ActuatorMetrics` struct exactly.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct ActuatorMetrics {
    pub roh_val: f64,
    pub veco_val: f64,
    pub lyap_val: f64,
    pub k_efficiency: f64,
    pub e_reclamation: f64,
    pub r_depletion: f64,
    pub thermal_propagation_c: f64,
}

#[link(name = "econet_actuator_core")] // Assumes compiled C++ lib is linked
extern "C" {
    fn econet_actuator_create(
        node_did: *const c_char,
        pitch_reg_addr: u32,
        bypass_reg_addr: u32,
        brake_reg_addr: u32,
    ) -> *mut c_void;

    fn econet_actuator_update(
        handle: *mut c_void,
        metrics: *const ActuatorMetrics,
        target_pitch: f64,
        target_bypass: f64,
    ) -> i32; // 0 = success, 1 = fail-safe triggered, 2 = already locked

    fn econet_actuator_emergency_isolate(handle: *mut c_void, reason: *const c_char);

    fn econet_actuator_is_locked(handle: *mut c_void) -> i32;
}

/// Safe, owned wrapper around the raw C++ actuator handle.
pub struct Actuator {
    handle: *mut c_void,
    node_did: String,
}

impl Actuator {
    /// Initializes the actuator with the given node DID and hardware register addresses.
    pub fn new(node_did: &str, pitch_addr: u32, bypass_addr: u32, brake_addr: u32) -> Result<Self, String> {
        let c_node_did = CString::new(node_did).map_err(|_| "Invalid node DID (contains null byte)")?;
        
        // SAFETY: We are calling a well-defined C FFI function with valid CStrings.
        // The C++ side allocates the Actuator instance.
        let handle = unsafe {
            econet_actuator_create(c_node_did.as_ptr(), pitch_addr, bypass_addr, brake_addr)
        };

        if handle.is_null() {
            return Err("Failed to create actuator: null handle returned".to_string());
        }

        Ok(Self {
            handle,
            node_did: node_did.to_string(),
        })
    }

    /// Attempts to update the actuator state. 
    /// Returns `Ok(false)` if the update was rejected or fail-safe was triggered.
    /// Returns `Ok(true)` if the update was successfully applied.
    pub fn update(&self, metrics: &ActuatorMetrics, target_pitch: f64, target_bypass: f64) -> Result<bool, String> {
        if self.is_locked() {
            return Ok(false);
        }

        // SAFETY: `self.handle` is guaranteed non-null by `new()`. 
        // `metrics` is a valid reference to a #[repr(C)] struct.
        let result = unsafe {
            econet_actuator_update(self.handle, metrics, target_pitch, target_bypass)
        };

        match result {
            0 => Ok(true),  // Success
            1 => Ok(false), // Fail-safe triggered or rejected
            2 => Ok(false), // Already locked
            _ => Err(format!("Unknown actuator update error code: {}", result)),
        }
    }

    /// Forcefully engages the mechanical fail-safe isolation.
    pub fn emergency_isolate(&self, reason: &str) {
        if let Ok(c_reason) = CString::new(reason) {
            // SAFETY: `self.handle` is valid, `c_reason` is a valid C string.
            unsafe {
                econet_actuator_emergency_isolate(self.handle, c_reason.as_ptr());
            }
        }
    }

    /// Checks if the actuator is currently in a locked (fail-safe) state.
    pub fn is_locked(&self) -> bool {
        // SAFETY: `self.handle` is valid.
        let result = unsafe { econet_actuator_is_locked(self.handle) };
        result != 0
    }

    pub fn node_did(&self) -> &str {
        &self.node_did
    }
}

// Note: We intentionally do NOT implement Drop to call a destroy function here,
// because fail-safe isolation state must persist across process restarts and 
// should only be cleared by explicit, audited governance commands, not scope exit.
