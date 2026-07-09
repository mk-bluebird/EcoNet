# CMakeLists.txt for EcoNet C++ Components
# Builds: actuator_failsafe, ker_guard, qpu_particles

cmake_minimum_required(VERSION 3.10)
project(EcoNetCpp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_SOURCE_DIR}/src)

# ============================================================================
# Library: actuator_failsafe (6D convex safety corridor enforcement)
# ============================================================================
add_library(actuator_failsafe STATIC
    src/core/actuator_failsafe.cpp
)

target_include_directories(actuator_failsafe PUBLIC
    ${CMAKE_SOURCE_DIR}/src/core
)

# ============================================================================
# Library: cyboquatic_guard (KER monotonicity validation)
# ============================================================================
add_library(cyboquatic_guard STATIC
    src/cpp/cyboquatic_guard/ker_guard.cpp
)

target_include_directories(cyboquatic_guard PUBLIC
    ${CMAKE_SOURCE_DIR}/src/cpp/cyboquatic_guard
)

# ============================================================================
# Library: karma_policy (Karma tolerance evaluation)
# ============================================================================
add_library(karma_policy STATIC
    src/KarmaPolicy.cpp
)

target_include_directories(karma_policy PUBLIC
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/src
)

# ============================================================================
# Library: qpu_particles (QPUDatashards particles CSV reader)
# ============================================================================
add_library(qpu_particles STATIC
    src/qpu_particles/QpuParticles.cpp
)

target_include_directories(qpu_particles PUBLIC
    ${CMAKE_SOURCE_DIR}/src/qpu_particles
    ${CMAKE_SOURCE_DIR}/include
)

# ============================================================================
# Executable: qpu_particles_demo (Demo program to read particle data)
# ============================================================================
add_executable(qpu_particles_demo
    src/qpu_particles/main.cpp
)

target_link_libraries(qpu_particles_demo
    qpu_particles
)

# Set output directory for demo executable
set_target_properties(qpu_particles_demo PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# ============================================================================
# Installation targets
# ============================================================================
install(TARGETS actuator_failsafe cyboquatic_guard karma_policy qpu_particles
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(DIRECTORY include/ DESTINATION include/EcoNet
    FILES_MATCHING PATTERN "*.hpp"
)

install(DIRECTORY src/core/ DESTINATION include/EcoNet/core
    FILES_MATCHING PATTERN "*.hpp"
)

install(DIRECTORY src/cpp/cyboquatic_guard/ DESTINATION include/EcoNet/cyboquatic_guard
    FILES_MATCHING PATTERN "*.hpp"
)

install(DIRECTORY src/qpu_particles/ DESTINATION include/EcoNet/qpu_particles
    FILES_MATCHING PATTERN "*.hpp"
)

# Print configuration summary
message(STATUS "EcoNet C++ Build Configuration:")
message(STATUS "  - C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  - Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  - Libraries: actuator_failsafe, cyboquatic_guard, karma_policy, qpu_particles")
message(STATUS "  - Executables: qpu_particles_demo")
