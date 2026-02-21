cmake_minimum_required(VERSION 3.24)
project(
    PackageBuilderTest
    VERSION 1.0.0
    LANGUAGES CXX)

# Find the package we're testing
find_package(PackageBuilder REQUIRED CONFIG)
include(PackageBuilder)

# Test that we can use the PackageBuilder functions This will test that package_create() works
package_create()

# Create a simple test executable
package_add_executable(test_package src/main.cpp)

# Install the test
package_install()
