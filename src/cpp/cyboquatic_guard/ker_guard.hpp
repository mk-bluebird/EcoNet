// filename: src/cpp/cyboquatic_guard/ker_guard.hpp
// destination: Eco-Fort/src/cpp/cyboquatic_guard/ker_guard.hpp
#pragma once
#include <string>

namespace cyboquatic_guard {

struct KerState {
    double k_old;
    double e_old;
    double r_old;
    double vt_old;
    double k_new;
    double e_new;
    double r_new;
    double vt_new;
    double vt_epsilon;
};

struct KerGuardResult {
    bool monotone_ok;
    bool lyapunov_ok;
    std::string reason;
};

class KerGuard {
public:
    KerGuard() = default;
    KerGuardResult check_upgrade(const KerState& state) const;
};

} // namespace cyboquatic_guard
