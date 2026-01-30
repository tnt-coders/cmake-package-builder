cmake_minimum_required(VERSION 3.15)
project(test_package VERSION 1.0.0 LANGUAGES CXX)

# Find the PackageBuilder package
find_package(PackageBuilder REQUIRED)

# Include the PackageBuilder module
include(PackageBuilder)

# Initialize the package
package_init()

# Create a simple test executable using package_add_executable
package_add_executable(test_package test_package.cpp)

# Install and export the package to verify all functions work
package_install()
