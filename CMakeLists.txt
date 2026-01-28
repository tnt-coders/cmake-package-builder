cmake_minimum_required(VERSION 3.15)
project(cmake-core LANGUAGES NONE)

# Include our own Core.cmake module
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Core)

# Set version from Git
core_set_project_version_from_git()

# Use our own core_install() function to install Core.cmake and generate config files
# MODULE_FILES installs the specified files and includes them in the generated Config file
core_install(MODULE_FILES cmake/Core.cmake)