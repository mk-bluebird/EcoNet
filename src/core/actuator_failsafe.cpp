// filename: actuator_failsafe.cpp
// destination: EcoNet/src/core/actuator_failsafe.cpp
#include "actuator_failsafe.hpp"
#include <cmath>
#include <iostream>

namespace econet {
namespace hardware {

SubseaActuator::SubseaActuator(std::string node_did, HardwareRegisters regs, SafetyCorridor corridor, RiskEventCallback risk_cb)
    : node_did_(std::move(node_did))
    , regs_(regs)
    , corridor_(corridor)
    , risk_cb_(std::move(risk_cb))
    , hardware_locked_(false)
    , current_pitch_angle_(0.0)
    , current_bypass_flow_(0.0) 
{
    // Initialize hardware to a known safe state on boot
    engage_fail_safe_isolation("INITIALIZATION_SAFE_STATE");
}

SubseaActuator::~SubseaActuator() {
    if (!hardware_locked_) {
        engage_fail_safe_isolation("SHUTDOWN_SAFE_STATE");
    }
}

bool SubseaActuator::check_safety_corridor(const ActuatorMetrics& metrics) const {
    // Enforce the 6D convex safety corridor. 
    // Any violation immediately invalidates the operational envelope.
    if (metrics.roh_val > corridor_.max_roh_kelvin_per_hour) return false;
    if (metrics.veco_val > corridor_.max_veco_shear_index) return false;
    if (metrics.lyap_val < corridor_.min_lyapunov_stability) return false;
    if (metrics.k_efficiency < corridor_.min_kinetic_efficiency) return false;
    if (metrics.e_reclamation < corridor_.min_eco_reclamation) return false;
    if (metrics.r_depletion > corridor_.max_resource_depletion) return false;
    
    return true;
}

bool SubseaActuator::check_physical_limits(double pitch_angle, double bypass_flow) const {
    // Prevent mechanical damage from extreme actuation commands
    if (pitch_angle < 0.0 || pitch_angle > 45.0) return false;
    if (bypass_flow < 0.0 || bypass_flow > 10.0) return false;
    return true;
}

void SubseaActuator::engage_fail_safe_isolation(const std::string& reason) {
    if (hardware_locked_) return;

    hardware_locked_ = true;

    // 1. Feather turbine blades to stop rotational kinetic force (pitch to 0 or safe angle)
    if (regs_.pitch_valve_register) {
        *regs_.pitch_valve_register = 0; 
    }

    // 2. Divert hydro-flow through the bypass channel to relieve pressure
    if (regs_.water_bypass_valve) {
        *regs_.water_bypass_valve = 1; 
    }

    // 3. Engage mechanical brake if available
    if (regs_.turbine_brake_register) {
        *regs_.turbine_brake_register = 1;
    }

    // 4. Log the MT6883 risk event to the higher-level ledger via callback
    if (risk_cb_) {
        risk_cb_(node_did_, "FAIL_SAFE_TRIGGERED: " + reason);
    }

    // 5. Visual/Telemetry indicator of lockdown
    if (regs_.status_led_register) {
        *regs_.status_led_register = 0xFF; // Red alert state
    }
}

void SubseaActuator::update_state(const ActuatorMetrics& metrics, double target_pitch_angle, double target_bypass_flow) {
    if (hardware_locked_) {
        return; // Absolute override: no actuation allowed once locked
    }

    // Step 1: Validate against the Lyapunov / Ecosafety corridor
    if (!check_safety_corridor(metrics)) {
        engage_fail_safe_isolation("CORRIDOR_VIOLATION");
        return;
 “target_pitch_angle=" + std::to_string(target_pitch_angle) + 
                   " target_bypass=" + std::to_string(target_bypass_flow));
        return;
    }

    // Step 3: Apply the actuation (write to memory-mapped hardware registers)
    current_pitch_angle_ = target_pitch_angle;
    current_bypass_flow_ = target_bypass_flow;

    if (regs_.pitch_valve_register) {
        // Scale angle to hardware-specific fixed-point or PWM register value
        *regs_.pitch_valve_register = static_cast<uint32_t>(target_pitch_angle * 100.0);
    }

    if (regs_.water_bypass_valve) {
        *regs_.water_bypass_valve = static_cast<uint32_t>(target_bypass_flow * 10.0);
    }
}

} // namespace hardware
} // namespace econet

// ============================================================================
// C-ABI FFI Implementations
// ============================================================================
extern "C" {

// Global registry for FFI handles (in production, use a thread-safe map or object pool)
static econet::hardware::SubseaActuator* g_actuator_instance = nullptr;

ActuatorHandle econet_actuator_create(const char* node_did, uint32_t pitch_reg_addr, uint32_t bypass_reg_addr, uint32_t brake_reg_addr) {
    if (g_actuator_instance != nullptr) {
        return nullptr; // Singleton for this example; expand to map for multi-node
    }

    econet::hardware::HardwareRegisters regs;
    regs.pitch_valve_register = reinterpret_cast<volatile uint32_t*>(pitch_reg_addr);
    regs.water_bypass_valve = reinterpret_cast<volatile uint32_t*>(bypass_reg_addr);
    regs.turbine_brake_register = reinterpret_cast< volatile uint32_t*>(brake_reg_addr);
    regs.status_led_register = nullptr; // Optional

    econet::hardware::SafetyCorridor corridor; // Defaults to ALN-specified 2026v1 limits

    // Risk callback that would interface with the Rust MT6883 risk chain ledger
    auto risk_callback = [](const std::string& did, const std::string& reason) {
        // In production, this calls into the Rust FFI to append to RISK_chain
        // e.g., rust_log_risk_event(did.c_str(), reason.c_str());
    };

    g_actuator_instance = new econet::hardware::SubseaActuator(std::string(node_did), regs, corridor, risk_callback);
    return g_actuator_instance;
}

void econet_actuator_destroy(ActuatorHandle handle) {
    auto* actuator = static_cast<econet::hardware::SubseaActuator*>(handle);
    if (actuator) {
        delete actuator;
        g_actuator_instance = nullptr;
    }
}

int econet_actuator_update(ActuatorHandle handle, const econet::hardware::ActuatorMetrics* metrics, double target_pitch, double target_bypass) {
    auto* actuator = static_cast<econet::hardware::SubseaActuator*>(handle);
    if (!actuator || !metrics) return 2;

    if (actuator->is_locked()) return 1;

    // We use a pre/post lock check to determine if the update triggered a fail-safe
    actuator->update_state(*metrics, target_pitch, target_bypass);
    
    return actuator->is_locked() ? 1 : 0;
}

void econet_actuator_emergency_isolate(ActuatorHandle handle, const char* reason) {
    auto* actuator = static_cast<econet::hardware::SubseaActuator*>(handle);
    if (actuator && reason) {
        actuator->engage_fail_safe_isolation(std::string(reason));
    }
}

int econet_actuator_is_locked(ActuatorHandle handle) {
    auto* actuator = static_cast<econet::hardware::SubseaActuator*>(handle);
    return actuator ? (actuator->is_locked() ? 1 : 0) : 1;
}

} // extern "C"
