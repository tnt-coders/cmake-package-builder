cmake_minimum_required(VERSION 3.24)

project(PackageBuilder VERSION 1.0.0 LANGUAGES CXX)

# Include our own modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(PackageBuilder)
