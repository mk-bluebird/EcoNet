// filename: src/qpu_particles/QpuParticles.cpp
// Implementation for reading and parsing qpudatashards/particles CSV data

#include "QpuParticles.hpp"
#include <algorithm>
#include <iostream>

namespace EcoKarma {
namespace QpuParticles {

std::string ParticleReader::trim(const std::string& str) {
    size_t start = str.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = str.find_last_not_of(" \t\r\n");
    return str.substr(start, end - start + 1);
}

std::vector<std::string> ParticleReader::splitCSVLine(const std::string& line) {
    std::vector<std::string> result;
    std::stringstream ss(line);
    std::string field;
    
    while (std::getline(ss, field, ',')) {
        result.push_back(trim(field));
    }
    
    return result;
}

std::vector<WaterQualityParticle> ParticleReader::readWaterQualityCSV(const std::string& filepath) {
    std::vector<WaterQualityParticle> particles;
    std::ifstream file(filepath);
    
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open file " << filepath << std::endl;
        return particles;
    }
    
    std::string line;
    // Skip header line
    std::getline(file, line);
    
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        
        auto fields = splitCSVLine(line);
        if (fields.size() < 21) continue;
        
        try {
            WaterQualityParticle p;
            p.nodeId = fields[0];
            p.region = fields[1];
            p.basin = fields[2];
            p.subCorridor = fields[3];
            p.latitude = std::stod(fields[4]);
            p.longitude = std::stod(fields[5]);
            p.windowStart = fields[6];
            p.windowEnd = fields[7];
            p.contaminant = fields[8];
            p.metric = fields[9];
            p.unit = fields[10];
            p.meanValue = std::stod(fields[11]);
            p.minValue = std::stod(fields[12]);
            p.maxValue = std::stod(fields[13]);
            p.stddev = std::stod(fields[14]);
            p.sampleCount = std::stoi(fields[15]);
            p.kerK = std::stod(fields[16]);
            p.kerE = std::stod(fields[17]);
            p.kerR = std::stod(fields[18]);
            p.kerVt = std::stod(fields[19]);
            p.kerLane = fields[20];
            p.kerDeployable = (fields.size() > 21) ? std::stoi(fields[21]) : 0;
            p.blastRadiusId = (fields.size() > 22) ? std::stoi(fields[22]) : 0;
            p.evidenceHex = (fields.size() > 23) ? fields[23] : "";
            
            particles.push_back(p);
        } catch (const std::exception& e) {
            std::cerr << "Warning: Failed to parse line: " << line << " (" << e.what() << ")" << std::endl;
        }
    }
    
    file.close();
    return particles;
}

std::vector<KarmaToleranceIdentity> ParticleReader::readKarmaToleranceCSV(const std::string& filepath) {
    std::vector<KarmaToleranceIdentity> identities;
    std::ifstream file(filepath);
    
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open file " << filepath << std::endl;
        return identities;
    }
    
    std::string line;
    // Skip header line
    std::getline(file, line);
    
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        
        auto fields = splitCSVLine(line);
        if (fields.size() < 26) continue;
        
        try {
            KarmaToleranceIdentity id;
            id.identityId = fields[0];
            id.brainIdentityDid = fields[1];
            id.bostromAddress = fields[2];
            id.mt6883HardwareProfile = fields[3];
            id.continuityGrade = fields[4].empty() ? ' ' : fields[4][0];
            id.karmaFloor = std::stod(fields[5]);
            id.karmaCeiling = std::stod(fields[6]);
            id.karmaToleranceBand = std::stod(fields[7]);
            id.rohCeiling = std::stod(fields[8]);
            id.rohToleranceBand = std::stod(fields[9]);
            id.psychRiskFloor = std::stod(fields[10]);
            id.psychRiskCeiling = std::stod(fields[11]);
            id.psychRiskToleranceBand = std::stod(fields[12]);
            id.ecoWealthFloor = std::stod(fields[13]);
            id.ecoWealthCeiling = std::stod(fields[14]);
            id.ecoWealthToleranceBand = std::stod(fields[15]);
            id.continuityContractId = fields[16];
            id.jurisdiction = fields[17];
            id.primaryPlane = fields[18];
            id.mt6883NeuroethicProfile = fields[19];
            id.nonActuatingOnly = (fields.size() > 20 && fields[20] == "1");
            id.sovereignClauseActive = (fields.size() > 21 && fields[21] == "1");
            id.intelligenceIsSovereign = (fields.size() > 22 && fields[22] == "1");
            id.underAttackState = (fields.size() > 23 && fields[23] == "UNDERATTACK");
            id.neuroethicTimeHours = (fields.size() > 24) ? std::stod(fields[24]) : 24.0;
            id.notes = (fields.size() > 25) ? fields[25] : "";
            
            identities.push_back(id);
        } catch (const std::exception& e) {
            std::cerr << "Warning: Failed to parse line: " << line << " (" << e.what() << ")" << std::endl;
        }
    }
    
    file.close();
    return identities;
}

std::vector<KarmaWindowTemplate> ParticleReader::readKarmaWindowCSV(const std::string& filepath) {
    std::vector<KarmaWindowTemplate> windows;
    std::ifstream file(filepath);
    
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open file " << filepath << std::endl;
        return windows;
    }
    
    std::string line;
    // Skip header line
    std::getline(file, line);
    
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        
        auto fields = splitCSVLine(line);
        if (fields.size() < 25) continue;
        
        try {
            KarmaWindowTemplate w;
            w.nodeId = fields[0];
            w.region = fields[1];
            w.lane = fields[2];
            w.windowStart = fields[3];
            w.windowEnd = fields[4];
            w.energyDomain = fields[5];
            w.energyLane = fields[6];
            w.primaryPlane = fields[7];
            w.secondaryPlanes = fields[8];
            w.karmaWindowLabel = fields[9];
            w.karmaWindowType = fields[10];
            w.energyJoules = std::stod(fields[11]);
            w.karmaRawWindow = std::stod(fields[12]);
            w.karmaDeltaWindow = std::stod(fields[13]);
            w.ecoPerJouleWindow = std::stod(fields[14]);
            w.thetaEco = std::stod(fields[15]);
            w.lifeForceWindow = std::stod(fields[16]);
            w.lifeForceFloor = std::stod(fields[17]);
            w.rohWindow = std::stod(fields[18]);
            w.rohCeiling = std::stod(fields[19]);
            w.holidayRequired = (fields.size() > 20 && fields[20] == "true");
            w.kWindow = std::stod(fields[21]);
            w.eWindow = std::stod(fields[22]);
            w.rWindow = std::stod(fields[23]);
            w.vtMaxWindow = std::stod(fields[24]);
            w.kerDeployable = (fields.size() > 25) ? std::stoi(fields[25]) : 0;
            w.evidenceHex = (fields.size() > 26) ? fields[26] : "";
            
            windows.push_back(w);
        } catch (const std::exception& e) {
            std::cerr << "Warning: Failed to parse line: " << line << " (" << e.what() << ")" << std::endl;
        }
    }
    
    file.close();
    return windows;
}

std::vector<EcoMathRecord> ParticleReader::readEcoMathCSV(const std::string& filepath) {
    std::vector<EcoMathRecord> records;
    std::ifstream file(filepath);
    
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open file " << filepath << std::endl;
        return records;
    }
    
    std::string line;
    // Skip header line
    std::getline(file, line);
    
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        
        auto fields = splitCSVLine(line);
        if (fields.size() < 14) continue;
        
        try {
            EcoMathRecord r;
            r.nodeId = fields[0];
            r.stakeholderId = fields[1];
            r.contaminant = fields[2];
            r.cIn = std::stod(fields[3]);
            r.cOut = std::stod(fields[4]);
            r.flow = std::stod(fields[5]);
            r.windowStart = fields[6];
            r.windowEnd = fields[7];
            r.cRef = std::stod(fields[8]);
            r.hazardWeight = std::stod(fields[9]);
            r.kn = std::stod(fields[10]);
            r.ecoImpactScore = std::stod(fields[11]);
            r.unitsC = fields[12];
            r.unitsQ = fields[13];
            
            records.push_back(r);
        } catch (const std::exception& e) {
            std::cerr << "Warning: Failed to parse line: " << line << " (" << e.what() << ")" << std::endl;
        }
    }
    
    file.close();
    return records;
}

} // namespace QpuParticles
} // namespace EcoKarma
