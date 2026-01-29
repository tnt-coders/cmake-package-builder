from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout, CMakeDeps
from conan.tools.files import copy
import os

class CMakePackageBuilderConan(ConanFile):
    name = "cmake-package-builder"
    license = "MIT"
    author = "TNT Coders <tnt-coders@googlegroups.com>"
    url = "https://github.com/tnt-coders/cmake-package-builder"
    description = "CMake utility functions for simplified project setup/installation"
    package_type = "build-scripts"
    settings = "os", "compiler", "build_type", "arch"
    exports_sources = "CMakeLists.txt", "cmake/*"

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.variables["CONAN_EXPORT"] = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["cmake-package-builder"]
        self.cpp_info.set_property("cmake_file_name", "PackageBuilder")
