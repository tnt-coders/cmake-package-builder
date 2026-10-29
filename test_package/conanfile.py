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
        # The sample names the GUI app as its PRIMARY_TARGET, so the configure must not warn that
        # the package lacks one; nor, on Linux, that the app or the command-line tool has no
        # .desktop file. CMake writes warnings to stderr, which is captured to check and then
        # passed through. A first configure with an empty vendor and no tool checks the
        # configuration of a package that names no publisher and holds the GUI app alone; the cache
        # keeps both variables, so the second sets them back.
        cmake = CMake(self)
        cmake.configure(
            variables={
                "PACKAGE_BUILDER_TEST_VENDOR": "",
                "PACKAGE_BUILDER_TEST_COMPONENTS": "Runtime",
            }
        )
        stderr = StringIO()
        cmake.configure(
            variables={
                "PACKAGE_BUILDER_TEST_VENDOR": "Test Vendor",
                "PACKAGE_BUILDER_TEST_COMPONENTS": "Runtime;Tool",
            },
            stderr=stderr,
        )
        sys.stderr.write(stderr.getvalue())
        if "PRIMARY_TARGET is not set" in stderr.getvalue():
            raise ConanException("The configure warned that the package lacks a PRIMARY_TARGET.")
        if "desktop integration" in stderr.getvalue():
            raise ConanException("The configure warned about a .desktop file.")
        cmake.build()

    # The configure checks the package configuration; this checks the archive CPack stages from
    # it: one file named CPACK_PACKAGE_FILE_NAME, holding the listed app and tool and not the
    # unlisted game, and with a dynamically linked MSVC runtime, that runtime beside them. On
    # Windows it also compiles the one-click installer.
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
        if not any(re.search(r"bin/test-app(\.exe)?$", name) for name in names):
            raise ConanException(f"The archive lacks the listed app: {names}")
        if any("test-game" in name for name in names):
            raise ConanException(f"The archive holds the unlisted game: {names}")
        if (
            self.settings.compiler == "msvc"
            and self.settings.get_safe("compiler.runtime") == "dynamic"
        ):
            for runtime in ("msvcp140.dll", "vcruntime140.dll"):
                if not any(name.endswith(f"bin/{runtime}") for name in names):
                    raise ConanException(f"The archive lacks the C++ runtime's {runtime}: {names}")

        # Only makensis checks the one-click installer's template and the PATH plugin it loads, so
        # the test compiles the installer.
        if self.settings.os == "Windows":
            self.run(f"cpack -G NSIS -C {self.settings.build_type}", cwd=self.build_folder)
            installers = list(Path(self.build_folder).glob("PackageBuilderTest-1.0.0-*.exe"))
            if len(installers) != 1:
                raise ConanException(
                    f"Expected one PackageBuilderTest installer, found {installers}."
                )

        # No executable links a library the resolver keeps, so the archive cannot show where their
        # dependencies go; the install script names the component of each dependency rule. Each
        # top-level block of it is one rule, guarded by the component it belongs to. The listed
        # app's and tool's dependencies go to Runtime, and the unlisted game's stay in Game.
        script = (Path(self.build_folder) / "cmake_install.cmake").read_text()
        rules = re.split(r'^if\(CMAKE_INSTALL_COMPONENT STREQUAL "', script, flags=re.MULTILINE)
        dependency_components = {
            executable: {
                rule.split('"', 1)[0]
                for rule in rules[1:]
                if "GET_RUNTIME_DEPENDENCIES" in rule and executable in rule
            }
            for executable in ("test-app", "test-game", "test-tool")
        }
        if dependency_components != {
            "test-app": {"Runtime"},
            "test-game": {"Game"},
            "test-tool": {"Runtime"},
        }:
            raise ConanException(
                f"Dependency rules are in the wrong components: {dependency_components}"
            )
