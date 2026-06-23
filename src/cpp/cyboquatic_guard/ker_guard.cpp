// filename: src/cpp/cyboquatic_guard/ker_guard.cpp
// destination: Eco-Fort/src/cpp/cyboquatic_guard/ker_guard.cpp
#include "ker_guard.hpp"

namespace cyboquatic_guard {

KerGuardResult KerGuard::check_upgrade(const KerState& s) const {
    KerGuardResult result{true, true, ""};

    if (s.k_new < s.k_old) {
        result.monotone_ok = false;
        result.reason += "K_new < K_old; ";
    }
    if (s.e_new < s.e_old) {
        result.monotone_ok = false;
        result.reason += "E_new < E_old; ";
    }
    if (s.r_new > s.r_old) {
        result.monotone_ok = false;
        result.reason += "R_new > R_old; ";
    }
    if (s.vt_new > s.vt_old + s.vt_epsilon) {
        result.lyapunov_ok = false;
        result.reason += "V_t_new > V_t_old + epsilon; ";
    }
    if (result.reason.empty()) {
        result.reason = "KER upgrade monotone and Lyapunov-safe";
    }
    return result;
}

} // namespace cyboquatic_guard
