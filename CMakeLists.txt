cmake_minimum_required(VERSION 3.15)
project(cmake-core LANGUAGES NONE)

# Include our own Core.cmake module
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Core)

# Set version from Git
core_set_version_from_git()

# Use our own core_install() function to install Core.cmake
core_install()

# Generate package config files
core_generate_package_config()