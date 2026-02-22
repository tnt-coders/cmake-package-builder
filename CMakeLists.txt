cmake_minimum_required(VERSION 3.24)

# Specify CXX as the language even though it is purely CMake to make cmake-conan happy
project(
    PackageBuilder
    VERSION 1.0.0
    DESCRIPTION "Tools for working with Wwise file types"
    LANGUAGES C CXX)

# Enable docs
option(PROJECT_CONFIG_ENABLE_DOCS
       "Enable docs target generation from project-config when Doxygen is available" ON)

# Add project config
add_subdirectory(project-config)

# Include our own modules
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(PackageBuilder)

# Use our own functions to create/export the package
package_create()
package_install()
