#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

struct SurchargeInput {
    double flow_lps;
    double design_flow_lps;
    double depth_m;
    int duration_s;
    double fog_confidence;
    bool calibrated;
    bool sample_collected;
};

struct Assessment {
    double base_radius_m;
    double uncertainty_radius_m;
    double review_radius_m;
    std::string severity_band;
    std::string disposition;
    double knowledge_factor;
    double eco_impact_value;
    double harm_risk;
};

Assessment assess(const SurchargeInput& input) {
    if (!(input.flow_lps >= 0.0 && input.design_flow_lps > 0.0 &&
          input.depth_m >= 0.0 && input.duration_s > 0 &&
          input.fog_confidence >= 0.0 && input.fog_confidence <= 1.0)) {
        throw std::invalid_argument("input is outside bounded operating range");
    }

    const double flow_ratio = input.flow_lps / input.design_flow_lps;
    const double duration_factor = std::log1p(static_cast<double>(input.duration_s) / 60.0);
    const double base_radius = std::clamp(
        8.0 + 12.0 * std::sqrt(std::max(0.0, flow_ratio)) +
        25.0 * input.depth_m + 6.0 * duration_factor,
        0.0, 10000.0
    );

    const double uncertainty_multiplier =
        (1.0 - input.fog_confidence) +
        (input.calibrated ? 0.0 : 0.35) +
        (input.sample_collected ? 0.0 : 0.25);

    const double uncertainty_radius = std::clamp(
        base_radius * uncertainty_multiplier, 0.0, 10000.0
    );
    const double review_radius = std::clamp(
        base_radius + uncertainty_radius, base_radius, 20000.0
    );

    const double severity_score =
        0.45 * std::min(flow_ratio, 2.0) +
        0.35 * std::min(input.depth_m / 0.5, 2.0) +
        0.20 * std::min(static_cast<double>(input.duration_s) / 3600.0, 2.0);

    std::string severity = "low";
    std::string disposition = "monitor";
    if (severity_score >= 1.80) {
        severity = "critical";
        disposition = "isolate_and_escalate";
    } else if (severity_score >= 1.10) {
        severity = "high";
        disposition = "hold_for_human_review";
    } else if (severity_score >= 0.60 || input.fog_confidence < 0.70 ||
               !input.calibrated || !input.sample_collected) {
        severity = "moderate";
        disposition = "hold_for_human_review";
    }

    const double knowledge = std::clamp(
        0.45 * input.fog_confidence +
        0.30 * (input.calibrated ? 1.0 : 0.0) +
        0.25 * (input.sample_collected ? 1.0 : 0.0),
        0.0, 1.0
    );
    const double impact = std::clamp(
        0.90 - review_radius / 20000.0, 0.0, 1.0
    );
    const double harm = std::clamp(
        severity_score / 2.0 + (1.0 - knowledge) * 0.25, 0.0, 1.0
    );

    return {
        base_radius, uncertainty_radius, review_radius,
        severity, disposition, knowledge, impact, harm
    };
}

}  // namespace

int main() {
    try {
        const SurchargeInput input{
            .flow_lps = 96.0,
            .design_flow_lps = 70.0,
            .depth_m = 0.18,
            .duration_s = 540,
            .fog_confidence = 0.62,
            .calibrated = true,
            .sample_collected = false
        };

        const Assessment result = assess(input);

        std::cout << std::fixed << std::setprecision(3)
                  << "base_radius_m=" << result.base_radius_m << '\n'
                  << "uncertainty_radius_m=" << result.uncertainty_radius_m << '\n'
                  << "review_radius_m=" << result.review_radius_m << '\n'
                  << "severity_band=" << result.severity_band << '\n'
                  << "disposition=" << result.disposition << '\n'
                  << "knowledge_factor=" << result.knowledge_factor << '\n'
                  << "eco_impact_value=" << result.eco_impact_value << '\n'
                  << "harm_risk=" << result.harm_risk << '\n';

        return result.disposition == "monitor" ? 0 : 2;
    } catch (const std::exception& error) {
        std::cerr << "surcharge assessment failed: " << error.what() << '\n';
        return 1;
    }
}
