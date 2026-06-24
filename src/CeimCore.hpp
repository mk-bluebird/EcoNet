#pragma once
#include <string>

namespace ceim {

struct NodeWindow {
    std::string nodeId;
    std::string stakeholderId;
    std::string contaminant;
    double cin;          // inflow concentration
    double cout;         // outflow concentration
    double flow;         // m3/s (average over window)
    double cref;         // reference concentration
    double hazardWeight; // alpha_x
    // horizon and units kept as strings for shard
    std::string windowStart;
    std::string windowEnd;
    std::string unitsC;
    std::string unitsQ;
};

inline double massLoad(const NodeWindow& w, double durationSeconds) {
    // M_x = (Cin - Cout) * Q * t
    return (w.cin - w.cout) * w.flow * durationSeconds;
}

inline double nodeImpactKn(const NodeWindow& w, double durationSeconds) {
    if (w.cref <= 0.0 || durationSeconds <= 0.0) return 0.0;
    double Mx = massLoad(w, durationSeconds);
    // K_n(x) = alpha_x * (Cin - Cout)/C_ref * Q * t
    double deltaC = (w.cin - w.cout) / w.cref;
    return w.hazardWeight * deltaC * w.flow * durationSeconds;
}

inline double ecoImpactScore(const NodeWindow& w, double durationSeconds,
                             double maxKnForScaling) {
    double Kn = nodeImpactKn(w, durationSeconds);
    if (maxKnForScaling <= 0.0) return 0.0;
    double E = Kn / maxKnForScaling; // normalize to [0,1] by corridor or basin
    if (E < 0.0) E = 0.0;
    if (E > 1.0) E = 1.0;
    return E;
}

} // namespace ceim
