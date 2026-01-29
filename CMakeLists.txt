cmake_minimum_required(VERSION 3.15)
project(PackageBuilder VERSION 1.0.0 LANGUAGES NONE)

# Include our own modules
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Package)

# Propagate to parent scope for FetchContent or git submodule consumers
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)

# Use our own functions to install/export the package
package_init()
package_install()
package_export(CONAN_PACKAGE cmake-package-builder)
