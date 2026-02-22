cmake_minimum_required(VERSION 3.24)
project(PackageBuilderTest)

# Verify the package can be found and included
find_package(PackageBuilder REQUIRED CONFIG)
include(PackageBuilder)

message(STATUS "PackageBuilder module was successfully found and included.")
