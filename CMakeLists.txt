cmake_minimum_required(VERSION 3.24)

# Specify CXX as the language even though it is purely CMake to make cmake-conan happy
project(PackageBuilder LANGUAGES CXX)

# Include our own modules
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(PackageBuilder)

# Use our own functions to create/export the package
package_create()
package_install()
