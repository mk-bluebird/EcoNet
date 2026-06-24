#pragma once
#include "KarmaTypes.hpp"

namespace EcoKarma {

class KarmaPolicy {
public:
    static ResponseDecision evaluateKarmaTolerance(const KarmaProfile& profile,
                                                   const IncidentContext& ctx);

private:
    static IntrusionResponseLevel clampResponse(IntrusionResponseLevel suggested,
                                                IntrusionResponseLevel maxAllowed);
};

} // namespace EcoKarma
