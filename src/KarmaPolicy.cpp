#include "KarmaPolicy.hpp"

namespace EcoKarma {

IntrusionResponseLevel KarmaPolicy::clampResponse(IntrusionResponseLevel suggested,
                                                  IntrusionResponseLevel maxAllowed) {
    if (static_cast<int>(suggested) > static_cast<int>(maxAllowed)) {
        return maxAllowed;
    }
    return suggested;
}

ResponseDecision KarmaPolicy::evaluateKarmaTolerance(const KarmaProfile& profile,
                                                     const IncidentContext& ctx) {
    ResponseDecision decision;
    decision.notifyHumanReview = false;
    decision.freezeHighValueAssets = false;

    IntrusionResponseLevel resp = ctx.baseSuggestedResponse;

    // 1. Boost for high-karma eco identities (e.g., augmented-citizen)
    if (profile.currentKarma >= 0.8 &&
        profile.tolerance == KarmaToleranceLevel::HIGH &&
        ctx.anomalyScore >= 0.7) {
        int r = static_cast<int>(resp);
        int low = static_cast<int>(IntrusionResponseLevel::LOW);
        if (r > low) {
            resp = static_cast<IntrusionResponseLevel>(r - 1); // reduce one level
        }
        decision.notifyHumanReview = true;
    }

    // 2. Harden for low-karma and correlated insider threats
    if (profile.currentKarma <= 0.3 &&
        (ctx.insiderSuspected || ctx.crossPlatformCorrelation)) {
        int high = static_cast<int>(IntrusionResponseLevel::HIGH);
        if (static_cast<int>(resp) < high) {
            resp = IntrusionResponseLevel::HIGH;
        }
        decision.freezeHighValueAssets = true;
    }

    // 3. Enforce per-identity cap
    resp = clampResponse(resp, profile.maxResponse);
    decision.appliedResponse = resp;
    return decision;
}

} // namespace EcoKarma
