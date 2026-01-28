cmake_minimum_required(VERSION 3.15)
project(CMakeCore LANGUAGES NONE)

# Include our own Core.cmake module
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Propagate to parent scope for FetchContent or git submodule consumers
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)

include(CMakeCore)

# Set version from Git
#TODO
#core_set_version_from_git()

# Use our own core_install() function to install modules
core_install()

# Generate package config files
core_generate_package_config()