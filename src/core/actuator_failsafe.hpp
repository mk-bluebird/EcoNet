// filename: actuator_failsafe.hpp
// destination: EcoNet/src/core/actuator_failsafe.hpp
#pragma once

#include <cstdint>
#include <string>
#include <functional>

namespace econet {
namespace hardware {

// 6D Convex Safety Corridor Limits (aligned with CyboquaticEcosafetyContinuity2026v1.aln)
struct SafetyCorridor {
    double max_roh_kelvin_per_hour = 0.30;   // Rate of Heating
    double max_veco_shear_index = 0.30;      // Velocity Ecosystem Disturbance
    double min_lyapunov_stability = 0.85;    // Lyapunov Stability
    double min_kinetic_efficiency = 0.90;    // Kinetic Capture Efficiency
    double min_eco_reclamation = 0.90;       // Ecological Reclamation Ratio
    double max_resource_depletion = 0.13;    // Resource Depletion Rate
};

// Real-time telemetry metrics fed from the edge orchestrator
struct ActuatorMetrics {
    double roh_val;
    double veco_val;
    double lyap_val;
    double k_efficiency;
    double e_reclamation;
    double r_depletion;
    double thermal_propagation_c;
};

// Hardware register mappings (example for ARM Cortex-M / MT6883 class SoC)
// In production, these addresses are provided by the board support package (BSP).
struct HardwareRegisters {
    volatile uint32_t* pitch_valve_register;
    volatile uint32_t* water_bypass_valve;
    volatile uint32_t* turbine_brake_register;
    volatile uint32_t* status_led_register;
};

// Callback type for reporting fail-safe events to the Rust/SQLite risk ledger
using RiskEventCallback = std::function<void(const std::string& node_did, const std::string& reason)>;

class SubseaActuator {
public:
    SubseaActuator(std::string node_did, HardwareRegisters regs, SafetyCorridor corridor, RiskEventCallback risk_cb);
    ~SubseaActuator();

    // Core control loop: validates metrics and applies adjustments, or triggers fail-safe
    void update_state(const ActuatorMetrics& metrics, double target_pitch_angle, double target_bypass_flow);

    // Immediate hardware lockdown (overrides all other commands)
    void engage_fail_safe_isolation(const std::string& reason);

    // Query current state
    bool is_locked() const { return hardware_locked_; }
    std::string get_node_did() const { return node_did_; }

private:
    std::string node_did_;
    HardwareRegisters regs_;
    SafetyCorridor corridor_;
    RiskEventCallback risk_cb_;
    
    bool hardware_locked_;
    double current_pitch_angle_;
    double current_bypass_flow_;

    // Internal safety check against the 6D convex corridor
    bool check_safety_corridor(const ActuatorMetrics& metrics) const;
    
    // Physical limits enforcement
    bool check_physical_limits(double pitch_angle, double bypass_flow) const;
};

} // namespace hardware
} // namespace econet

// ============================================================================
// C-ABI FFI Bindings for Rust Orchestrator / Virta-Sys Integration
// ============================================================================
extern "C" {
    // Opaque handle for the actuator instance
    typedef void* ActuatorHandle;

    ActuatorHandle econet_actuator_create(const char* node_did, uint32_t pitch_reg_addr, uint32_t bypass_reg_addr, uint32_t brake_reg_addr);
    void econet_actuator_destroy(ActuatorHandle handle);
    
    // Returns 0 on success, 1 if fail-safe was triggered, 2 if already locked
    int econet_actuator_update(ActuatorHandle handle, const ActuatorMetrics* metrics, double target_pitch, double target_bypass);
    
    // Force immediate isolation
    void econet_actuator_emergency_isolate(ActuatorHandle handle, const char* reason);
    
    // Query lock status
    int econet_actuator_is_locked(ActuatorHandle handle);
}
