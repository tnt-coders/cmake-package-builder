cmake_minimum_required(VERSION 3.15)
project(CMakeCore VERSION 1.0.0 LANGUAGES NONE)

# Include our own Core.cmake module
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Propagate to parent scope for FetchContent or git submodule consumers
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)

include(CMakeCore)

# Get the project version
core_get_project_version()

# Use our own core_install() function to install modules
core_install()
