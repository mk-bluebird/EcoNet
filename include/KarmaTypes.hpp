#pragma once
#include <string>

namespace EcoKarma {

enum class KarmaToleranceLevel { LOW = 0, MEDIUM = 1, HIGH = 2 };
enum class IntrusionResponseLevel { NONE = 0, LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 };

struct KarmaProfile {
    std::string identityId;
    std::string identityType;   // e.g. "AugmentedCitizen"
    double ecoImpactScore;      // 0–1
    double contributionScore;   // 0–1
    double securityTrustScore;  // 0–1
    double currentKarma;        // 0–1
    KarmaToleranceLevel tolerance;
    IntrusionResponseLevel maxResponse;
};

struct IncidentContext {
    double anomalyScore;                // 0–1, from IDS
    IntrusionResponseLevel baseSuggestedResponse;
    bool insiderSuspected;
    bool crossPlatformCorrelation;
};

struct ResponseDecision {
    IntrusionResponseLevel appliedResponse;
    bool notifyHumanReview;
    bool freezeHighValueAssets;
};

} // namespace EcoKarma
