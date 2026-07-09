// filename: src/qpu_particles/QpuParticles.hpp
// Purpose: C++ interface for reading and parsing qpudatashards/particles CSV data
// Aligns with EcoNet Karma types and Cyboquatic guard structures

#pragma once

#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <map>
#include "../include/KarmaTypes.hpp"

namespace EcoKarma {
namespace QpuParticles {

// Water quality particle from ArizonaGilaLakePleasantWaterQuality2024-2026v1.csv
struct WaterQualityParticle {
    std::string nodeId;
    std::string region;
    std::string basin;
    std::string subCorridor;
    double latitude;
    double longitude;
    std::string windowStart;
    std::string windowEnd;
    std::string contaminant;
    std::string metric;
    std::string unit;
    double meanValue;
    double minValue;
    double maxValue;
    double stddev;
    int sampleCount;
    double kerK;      // Knowledge score
    double kerE;      // Energy score  
    double kerR;      // Risk score
    double kerVt;     // Lyapunov value
    std::string kerLane;
    int kerDeployable;
    int blastRadiusId;
    std::string evidenceHex;
};

// Karma tolerance identity from KarmaToleranceIdentities2026v1.csv
struct KarmaToleranceIdentity {
    std::string identityId;
    std::string brainIdentityDid;
    std::string bostromAddress;
    std::string mt6883HardwareProfile;
    char continuityGrade;  // A, B, C, etc.
    double karmaFloor;
    double karmaCeiling;
    double karmaToleranceBand;
    double rohCeiling;
    double rohToleranceBand;
    double psychRiskFloor;
    double psychRiskCeiling;
    double psychRiskToleranceBand;
    double ecoWealthFloor;
    double ecoWealthCeiling;
    double ecoWealthToleranceBand;
    std::string continuityContractId;
    std::string jurisdiction;
    std::string primaryPlane;
    std::string mt6883NeuroethicProfile;
    bool nonActuatingOnly;
    bool sovereignClauseActive;
    bool intelligenceIsSovereign;
    bool underAttackState;
    double neuroethicTimeHours;
    std::string notes;
};

// Karma window template from EcoNetCentralAZKarmaWindowTemplate2026v1.csv
struct KarmaWindowTemplate {
    std::string nodeId;
    std::string region;
    std::string lane;
    std::string windowStart;
    std::string windowEnd;
    std::string energyDomain;
    std::string energyLane;
    std::string primaryPlane;
    std::string secondaryPlanes;
    std::string karmaWindowLabel;
    std::string karmaWindowType;
    double energyJoules;
    double karmaRawWindow;
    double karmaDeltaWindow;
    double ecoPerJouleWindow;
    double thetaEco;
    double lifeForceWindow;
    double lifeForceFloor;
    double rohWindow;
    double rohCeiling;
    bool holidayRequired;
    double kWindow;
    double eWindow;
    double rWindow;
    double vtMaxWindow;
    int kerDeployable;
    std::string evidenceHex;
};

// Eco math engine record from EcoNetSupremeEcoMathEngine2026v1.csv
struct EcoMathRecord {
    std::string nodeId;
    std::string stakeholderId;
    std::string contaminant;
    double cIn;
    double cOut;
    double flow;
    std::string windowStart;
    std::string windowEnd;
    double cRef;
    double hazardWeight;
    double kn;
    double ecoImpactScore;
    std::string unitsC;
    std::string unitsQ;
};

class ParticleReader {
public:
    static std::vector<WaterQualityParticle> readWaterQualityCSV(const std::string& filepath);
    static std::vector<KarmaToleranceIdentity> readKarmaToleranceCSV(const std::string& filepath);
    static std::vector<KarmaWindowTemplate> readKarmaWindowCSV(const std::string& filepath);
    static std::vector<EcoMathRecord> readEcoMathCSV(const std::string& filepath);

private:
    static std::vector<std::string> splitCSVLine(const std::string& line);
    static std::string trim(const std::string& str);
};

} // namespace QpuParticles
} // namespace EcoKarma
