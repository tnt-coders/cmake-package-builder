import re
import sys
import zipfile
from io import StringIO
from pathlib import Path

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.cmake import CMake, cmake_layout


class CMakePackageBuilderTestConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        cmake_layout(self)

    def build(self):
        # The sample's only packaged executable is its primary one, so the configure must not warn
        # that the package lacks a PRIMARY_TARGET. CMake writes warnings to stderr, which is
        # captured to check and then passed through.
        cmake = CMake(self)
        stderr = StringIO()
        cmake.configure(stderr=stderr)
        sys.stderr.write(stderr.getvalue())
        if "PRIMARY_TARGET is not set" in stderr.getvalue():
            raise ConanException("The configure warned that the package lacks a PRIMARY_TARGET.")
        cmake.build()

    # The configure checks the package configuration; this checks the archive CPack stages from
    # it: one file named CPACK_PACKAGE_FILE_NAME, holding the listed tool and not the unlisted game.
    def test(self):
        self.run(f"cpack -G ZIP -C {self.settings.build_type}", cwd=self.build_folder)
        archives = list(Path(self.build_folder).glob("*.zip"))
        if len(archives) != 1 or not re.fullmatch(
            r"PackageBuilderTest-1\.0\.0-[a-z]+-[a-z0-9_]+\.zip", archives[0].name
        ):
            raise ConanException(f"Expected one PackageBuilderTest archive, found {archives}.")
        with zipfile.ZipFile(archives[0]) as archive:
            names = archive.namelist()
        if not any(re.search(r"bin/test-tool(\.exe)?$", name) for name in names):
            raise ConanException(f"The archive lacks the listed tool: {names}")
        if any("test-game" in name for name in names):
            raise ConanException(f"The archive holds the unlisted game: {names}")

        # Neither executable links a library the resolver keeps, so the archive cannot show where
        # their dependencies go; the install script names the component of each dependency rule.
        # Each top-level block of it is one rule, guarded by the component it belongs to. The
        # listed tool's dependencies go to Runtime, and the unlisted game's stay in Game.
        script = (Path(self.build_folder) / "cmake_install.cmake").read_text()
        rules = re.split(r'^if\(CMAKE_INSTALL_COMPONENT STREQUAL "', script, flags=re.MULTILINE)
        dependency_components = {
            executable: {
                rule.split('"', 1)[0]
                for rule in rules[1:]
                if "GET_RUNTIME_DEPENDENCIES" in rule and executable in rule
            }
            for executable in ("test-game", "test-tool")
        }
        if dependency_components != {"test-game": {"Game"}, "test-tool": {"Runtime"}}:
            raise ConanException(
                f"Dependency rules are in the wrong components: {dependency_components}"
            )
