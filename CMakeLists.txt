cmake_minimum_required(VERSION 3.24)

# Specify CXX as the language even though it is purely CMake to make cmake-conan happy
project(
    PackageBuilder
    VERSION 1.0.0
    DESCRIPTION "Tools to assist with CMake/C++ package development"
    LANGUAGES C CXX)

# Add project config (disabled for Conan builds where project-config is not exported)
option(INCLUDE_PROJECT_CONFIG "Include project-config for docs, linting, and CMake presets" ON)
if(INCLUDE_PROJECT_CONFIG)

    # Set project-config specific options
    option(PROJECT_CONFIG_ENABLE_DOCS "Enable docs target when Doxygen is available" ON)
    option(PROJECT_CONFIG_ENABLE_CLANG_TIDY
           "Enable clang-tidy target when run-clang-tidy is available" OFF)

    add_subdirectory(project-config)
endif()

# Include our own modules
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(PackageBuilder)

# Use our own functions to create/export the package
package_create()
package_install()
