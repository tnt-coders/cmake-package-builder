cmake_minimum_required(VERSION 3.15)
project(cmake-core LANGUAGES NONE)

# Include our own Core.cmake module
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Core)

# Set version from Git
core_set_project_version_from_git()

# Set namespace for the package
core_set_namespace(Core)

# Create an INTERFACE library (header-only/module-only library with no compiled code)
core_add_library(TARGET cmake INTERFACE)

# Install the Core.cmake module file to the proper location
# This must be in lib/cmake/cmake-core/ so it can be found by find_package()
install(
    FILES cmake/Core.cmake
    DESTINATION lib/cmake/${PROJECT_NAME}
)

# Use our own core_install() function to generate CoreConfig.cmake and CoreConfigVersion.cmake
core_install(TARGETS cmake)