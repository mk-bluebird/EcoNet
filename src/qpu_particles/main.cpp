// filename: src/qpu_particles/main.cpp
// Demo program to read and display qpudatashards/particles data

#include "QpuParticles.hpp"
#include <iostream>
#include <iomanip>

int main(int argc, char* argv[]) {
    std::cout << "=== EcoNet QPU Particles Reader ===" << std::endl;
    std::cout << std::endl;
    
    // Default paths relative to repository root
    std::string base_path = "../qpudatashards/particles/";
    
    // Read water quality data
    std::cout << "--- Water Quality Particles (ArizonaGilaLakePleasant) ---" << std::endl;
    auto waterParticles = EcoKarma::QpuParticles::ParticleReader::readWaterQualityCSV(
        base_path + "ArizonaGilaLakePleasantWaterQuality2024-2026v1.csv");
    
    std::cout << "Loaded " << waterParticles.size() << " water quality records" << std::endl;
    if (!waterParticles.empty()) {
        std::cout << std::setw(15) << "NodeID" 
                  << std::setw(12) << "Contaminant" 
                  << std::setw(10) << "Mean" 
                  << std::setw(8) << "K" 
                  << std::setw(8) << "E" 
                  << std::setw(8) << "R" 
                  << std::setw(8) << "Vt" 
                  << std::endl;
        
        for (const auto& p : waterParticles) {
            std::cout << std::setw(15) << p.nodeId 
                      << std::setw(12) << p.contaminant 
                      << std::setw(10) << std::fixed << std::setprecision(2) << p.meanValue 
                      << std::setw(8) << std::setprecision(3) << p.kerK 
                      << std::setw(8) << p.kerE 
                      << std::setw(8) << p.kerR 
                      << std::setw(8) << p.kerVt 
                      << std::endl;
        }
    }
    std::cout << std::endl;
    
    // Read karma tolerance identities
    std::cout << "--- Karma Tolerance Identities ---" << std::endl;
    auto karmaIdentities = EcoKarma::QpuParticles::ParticleReader::readKarmaToleranceCSV(
        base_path + "KarmaToleranceIdentities2026v1.csv");
    
    std::cout << "Loaded " << karmaIdentities.size() << " karma tolerance identities" << std::endl;
    if (!karmaIdentities.empty()) {
        std::cout << std::setw(20) << "IdentityID" 
                  << std::setw(8) << "Grade" 
                  << std::setw(10) << "KFloor" 
                  << std::setw(10) << "KCeiling" 
                  << std::setw(12) << "PrimaryPlane" 
                  << std::setw(15) << "State" 
                  << std::endl;
        
        for (const auto& id : karmaIdentities) {
            std::string state = id.underAttackState ? "UNDERATTACK" : "NORMAL";
            std::cout << std::setw(20) << id.identityId 
                      << std::setw(8) << id.continuityGrade 
                      << std::setw(10) << std::fixed << std::setprecision(2) << id.karmaFloor 
                      << std::setw(10) << id.karmaCeiling 
                      << std::setw(12) << id.primaryPlane 
                      << std::setw(15) << state 
                      << std::endl;
        }
    }
    std::cout << std::endl;
    
    // Read karma window templates
    std::cout << "--- Karma Window Templates ---" << std::endl;
    auto karmaWindows = EcoKarma::QpuParticles::ParticleReader::readKarmaWindowCSV(
        base_path + "EcoNetCentralAZKarmaWindowTemplate2026v1.csv");
    
    std::cout << "Loaded " << karmaWindows.size() << " karma window templates" << std::endl;
    if (!karmaWindows.empty()) {
        std::cout << std::setw(18) << "NodeID" 
                  << std::setw(12) << "Type" 
                  << std::setw(10) << "Energy(J)" 
                  << std::setw(8) << "K" 
                  << std::setw(8) << "E" 
                  << std::setw(8) << "R" 
                  << std::setw(8) << "VtMax" 
                  << std::setw(8) << "Deploy" 
                  << std::endl;
        
        for (const auto& w : karmaWindows) {
            std::cout << std::setw(18) << w.nodeId 
                      << std::setw(12) << w.karmaWindowType 
                      << std::setw(10) << std::scientific << std::setprecision(2) << w.energyJoules 
                      << std::setw(8) << std::fixed << std::setprecision(2) << w.kWindow 
                      << std::setw(8) << w.eWindow 
                      << std::setw(8) << w.rWindow 
                      << std::setw(8) << w.vtMaxWindow 
                      << std::setw(8) << w.kerDeployable 
                      << std::endl;
        }
    }
    std::cout << std::endl;
    
    // Read eco math records
    std::cout << "--- Eco Math Engine Records ---" << std::endl;
    auto ecoMathRecords = EcoKarma::QpuParticles::ParticleReader::readEcoMathCSV(
        base_path + "EcoNetSupremeEcoMathEngine2026v1.csv");
    
    std::cout << "Loaded " << ecoMathRecords.size() << " eco math records" << std::endl;
    if (!ecoMathRecords.empty()) {
        std::cout << std::setw(18) << "NodeID" 
                  << std::setw(12) << "Contaminant" 
                  << std::setw(10) << "CIn" 
                  << std::setw(10) << "COut" 
                  << std::setw(10) << "Flow" 
                  << std::setw(12) << "EcoImpact" 
                  << std::endl;
        
        for (const auto& r : ecoMathRecords) {
            std::cout << std::setw(18) << r.nodeId 
                      << std::setw(12) << r.contaminant 
                      << std::setw(10) << std::fixed << std::setprecision(2) << r.cIn 
                      << std::setw(10) << r.cOut 
                      << std::setw(10) << r.flow 
                      << std::setw(12) << r.ecoImpactScore 
                      << std::endl;
        }
    }
    std::cout << std::endl;
    
    std::cout << "=== Summary ===" << std::endl;
    std::cout << "Total water quality particles: " << waterParticles.size() << std::endl;
    std::cout << "Total karma tolerance identities: " << karmaIdentities.size() << std::endl;
    std::cout << "Total karma window templates: " << karmaWindows.size() << std::endl;
    std::cout << "Total eco math records: " << ecoMathRecords.size() << std::endl;
    
    return 0;
}
