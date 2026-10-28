# PackageBuilder

[![Build - Windows](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-windows.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-windows.yml)
[![Build - Linux](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-linux.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-linux.yml)
[![Build - macOS](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-macos.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build-macos.yml)
[![Docs](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/docs.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/docs.yml)

**Tired of writing hundreds of lines of CMake boilerplate just to create a properly installable library?** Build sleek, professional C++ libraries and executables with a few simple function calls. Installation and package config generation all handled automatically.

> [!IMPORTANT]
> PackageBuilder assumes a [canonical CMake project structure](#project-structure) for its default behavior.

## Prerequisites

- CMake 3.24 or higher

---

## Installation

### Method 1: Conan via cmake-conan (Preferred)

If your project uses [cmake-conan](https://github.com/tnt-coders/cmake-conan) (the tnt-coders fork), this is the recommended way to consume PackageBuilder. Dependencies are resolved automatically with no manual installation.

Add the following to your `conanfile.py`:

```python
def requirements(self):
    self.requires("cmake-package-builder/1.0.0") #recipe: https://github.com/tnt-coders/cmake-package-builder.git
```

Or in `conanfile.txt`:

```ini
[requires]
cmake-package-builder/1.0.0 #recipe: https://github.com/tnt-coders/cmake-package-builder.git

[generators]
CMakeDeps
CMakeToolchain
```

The `#recipe:` tag tells cmake-conan where to find the source for the package. If the package is not already present in your local Conan cache or any configured remote, cmake-conan will automatically clone the tagged version from the provided git URL and run `conan create` to build it locally. No manual recipe hosting or remote setup needed.

Then in your CMakeLists.txt:

```cmake
find_package(PackageBuilder REQUIRED)
include(PackageBuilder)
```

For full details on how cmake-conan and the recipe tag work, see the tnt-coders fork of the [cmake-conan](https://github.com/tnt-coders/cmake-conan) repository.

### Method 2: FetchContent (Simplest)

The simplest way to get started. No installation or package manager required.

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyProject LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    PackageBuilder
    GIT_REPOSITORY https://github.com/tnt-coders/cmake-package-builder
    GIT_TAG v1.0.0
)
FetchContent_MakeAvailable(PackageBuilder)

include(PackageBuilder)
```

This allows you to immediately hit the ground running with professional quality install/package creation logic for your own project.

### Method 3: find_package (Classic)

Build and install PackageBuilder to your system, then find it like any other CMake package.

**Install:**

```
git clone https://github.com/tnt-coders/cmake-package-builder
cd cmake-package-builder
cmake -B build
cmake --install build
```

**Consume:**

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyProject LANGUAGES CXX)

find_package(PackageBuilder REQUIRED)
include(PackageBuilder)
```

---

## Usage

### Create The Package

**Required.** Must be called before any other PackageBuilder functions.

```cmake
package_create()
```

This function performs essential validation before any targets are defined:

- **Version verification:** Verifies that `PROJECT_VERSION` is set and fails with a fatal error if it is not. `PROJECT_VERSION` is typically set by specifying the version in the `project()` command.
- **Package version:** The installers carry `PROJECT_VERSION` unless `VERSION` overrides it with that version plus a SemVer pre-release or build suffix, e.g. `package_create(VERSION 1.0.0-alpha)` under `project(MyProject VERSION 1.0.0)`; any other value is a fatal error. `project()` and the numeric platform version fields (Windows VERSIONINFO's `FILEVERSION` and `PRODUCTVERSION`, Apple plists) accept integers only, so they keep the numeric version while installer file names, displayed versions and the Windows version text fields carry the full one. Debian packages spell the suffix with `~` (`1.0.0~alpha`) so that a pre-release sorts before its final release.
- **Description verification:** Verifies that `PROJECT_DESCRIPTION` is set and fails with a fatal error if it is not. Set via the `DESCRIPTION` argument in the `project()` command.
- **License verification:** Verifies that a `LICENSE` file exists at the project root. This is required for CPack packaging.

It also takes the package's identity, all optional:

| Argument | Description |
|----------|-------------|
| `VENDOR` | The publisher: `CPACK_PACKAGE_VENDOR`, the Windows *Publisher* entry, and the parent folder of the Windows install directory. Without it, CPack's default vendor applies and the install directory has no parent folder. |
| `DISPLAY_NAME` | The package's name on Windows: the installer title, the *Apps & features* entry, the Start Menu folder, the install directory and the registry key. Defaults to the `PRIMARY_TARGET`'s display name, then `PROJECT_NAME`. |
| `ICON` | The installer, uninstaller and *Apps & features* icon. Defaults to the `PRIMARY_TARGET`'s icon. |
| `PRIMARY_TARGET` | The executable that represents the package when `DISPLAY_NAME` or `ICON` is not given, and that gets the desktop shortcut by default. It must be packaged (see [Install components](#install-components)). A package with one packaged executable infers it. |
| `DESKTOP_LINKS` | See [Desktop shortcuts and launchers](#desktop-shortcuts-and-launchers). |
| `VERSION` | See above. |

The Windows install directory is `<VENDOR>\<DISPLAY_NAME>` under Program Files and the registry key is `<DISPLAY_NAME>`. Neither carries the version, so a new version installs over the last one rather than beside it:

```cmake
# Installs to "Program Files\My Company\My Suite"
package_create(VENDOR "My Company" DISPLAY_NAME "My Suite" ICON resources/my_suite.ico
               PRIMARY_TARGET my_app)
```

### Add Targets

```cmake
# Create a library (automatically aliased as MyProject::mylib)
package_add_library(mylib src/mylib.cpp)

# Create an executable
package_add_executable(myapp src/main.cpp)

# Create an executable with packaging metadata
package_add_executable(myapp src/main.cpp
    ICON                 resources/myapp.ico
    LINUX_DESKTOP_FILE   resources/myapp.desktop
    LINUX_ICON_THEME_DIR resources/icons)

# Link them together using the namespaced alias
target_link_libraries(myapp PRIVATE MyProject::mylib)
```

Libraries created with `package_add_library` are automatically given a namespaced alias of `<PROJECT_NAME>::<target>`. This is the same alias that downstream consumers will use after `find_package()`.

Targets created with `package_add_library` and `package_add_executable` automatically receive
these private include directories:

- `${CMAKE_CURRENT_SOURCE_DIR}`
- `${CMAKE_CURRENT_SOURCE_DIR}/include`
- `${CMAKE_CURRENT_SOURCE_DIR}/src`

For libraries, only `${CMAKE_CURRENT_SOURCE_DIR}/include` is exposed publicly. The project root is
a build-time convenience only and is not exported to consumers.

`package_add_executable` accepts optional packaging arguments:

| Argument       | Description |
|----------------|-------------|
| `DISPLAY_NAME`         | Human-readable name for the executable: its shortcut label and, on Windows, its `File description` and `Product name`. Defaults to the executable's output name. |
| `ICON`                 | Path to an icon file (`.ico`). On Windows, `package_add_executable()` embeds this into the executable and also uses it as the NSIS installer/uninstaller icon. Changing the icon re-runs CMake; that is how the compiled resource learns of it. Paths may be relative to the calling `CMakeLists.txt`. |
| `LINUX_DESKTOP_FILE`   | Path to an XDG `.desktop` file. Installed to `share/applications` on Linux for desktop launcher integration. Paths may be relative to the calling `CMakeLists.txt`. |
| `LINUX_ICON_THEME_DIR` | Path to a directory containing a Linux icon theme subtree such as `hicolor/256x256/apps/myapp.png`. Installed to `share/icons` on Linux. Paths may be relative to the calling `CMakeLists.txt`. |
| `COMPONENT`            | The install component that carries the executable, its runtime dependencies, and its Linux launcher entry and icons. Defaults to `Runtime`. See [Install components](#install-components). |
| `MENU_LINKS`           | Extra Windows Start Menu links that ship with the executable: `<path> <label>` pairs, where `<path>` is relative to the install directory or is a URL. |

All other arguments after the target name are forwarded to `add_executable()` as source files.

On Windows, every executable created with `package_add_executable` also gets version information, which Explorer shows under Properties → Details: the numeric `FILEVERSION` and `PRODUCTVERSION` carry `PROJECT_VERSION`, the `File version` and `Product version` text carries the full package version (`1.0.0-alpha`), and the `File description` and `Product name` carry the target's `DISPLAY_NAME` (or its output name when none is given).

A target created outside PackageBuilder can carry the same version information, and its registered `ICON`, through `package_write_resource_script(<out_var> <target>)`, which writes the resource script and returns its path. Call it after `package_register_target`, so the display name and icon are known. When the target's own tooling writes its resource script, include this one from it. For a JUCE app, JUCE's generated resource script includes `JUCE_USER_DEFINED_RC_FILE` in place of its own version block; leave JUCE's `ICON_BIG` and `ICON_SMALL` unset, so the icon comes from this script alone:

```cmake
juce_add_gui_app(my_app PRODUCT_NAME "My App" VERSION ${PROJECT_VERSION})
package_register_target(my_app DISPLAY_NAME "My App" ICON resources/my_app.ico)
if(WIN32)
    package_write_resource_script(_my_app_rc my_app)
    target_compile_definitions(my_app PRIVATE JUCE_USER_DEFINED_RC_FILE="${_my_app_rc}")
endif()
```

### Register Existing Targets

If your target is created outside PackageBuilder, such as by `add_executable` or another CMake
helper, register it for install, export, and CPack handling with `package_register_target`:

```cmake
add_executable(my_app main.cpp)
target_include_directories(my_app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

package_register_target(my_app
    ICON                 resources/my_app.ico
    LINUX_DESKTOP_FILE   resources/my_app.desktop
    LINUX_ICON_THEME_DIR resources/icons)
```

For externally created libraries, use `PUBLIC_HEADER_DIRS` to tell PackageBuilder which public
header roots should be installed:

```cmake
add_library(my_lib)
target_sources(my_lib PRIVATE src/my_lib.cpp)
target_include_directories(
    my_lib
    PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
           $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

package_register_target(my_lib PUBLIC_HEADER_DIRS include)
```

`package_register_target` accepts the same `DISPLAY_NAME`, `ICON`, `LINUX_DESKTOP_FILE`,
`LINUX_ICON_THEME_DIR`, `COMPONENT`, and `MENU_LINKS` arguments as `package_add_executable`;
`COMPONENT` applies to targets with runtime artifacts only, and `MENU_LINKS` to executables only.
For externally created targets, `ICON` is packaging metadata only; it is
used for the NSIS installer/uninstaller icon on Windows, but it does not modify the executable's
own resources. `package_register_target` does not create the target, add sources, add include
directories, or create a namespaced build-tree alias. Those details remain the responsibility of
the project that created the target.

### Generate Package Install Logic

```cmake
package_install()
```

This single call handles everything:

- Installs all targets registered via `package_add_library`, `package_add_executable`, and
  `package_register_target`
- Installs public headers from `include/` or any `PUBLIC_HEADER_DIRS` provided while registering
  external libraries
- Installs any custom CMake modules from `cmake/`
- Generates and installs `<ProjectName>Config.cmake` and `<ProjectName>ConfigVersion.cmake`

Downstream projects can then consume your package:

```cmake
find_package(MyProject REQUIRED)
target_link_libraries(myapp PRIVATE MyProject::mylib)
```

---

## Packaging Behavior

`package_install()` configures [CPack](https://cmake.org/cmake/help/latest/module/CPack.html) to generate platform-native installers:

| Platform | Generators     |
|----------|---------------|
| Windows  | ZIP, NSIS      |
| macOS    | ZIP, DragNDrop |
| Linux    | ZIP, DEB       |

Multiple registered applications — including macOS app bundles created by external CMake helpers —
are supported in a single package. Each registered runtime target gets its own runtime dependency
set, so CPack can correctly resolve and bundle the dependencies for every app.

### Install components

PackageBuilder assigns every install artifact to one of two CPack components:

| Component | Contents |
|-----------|----------|
| `Runtime` | Executables, macOS app bundles, shared libraries, and their runtime dependencies |
| `Development` | Static libraries, public headers, CMake package metadata (exported targets, config/version files, custom modules) |

A runtime target registered with `COMPONENT <name>` goes to that component instead of `Runtime`,
together with its runtime dependencies and its Linux `.desktop` file and icons. Registration records
every runtime target's component, `Runtime` included, as its `PACKAGE_BUILDER_COMPONENT` property,
so a project's own install rules for files that belong to one executable can read it rather than
restate it:

```cmake
package_add_executable(my_game main.cpp DISPLAY_NAME "My Game" COMPONENT Game)

get_target_property(_game_component my_game PACKAGE_BUILDER_COMPONENT)
install(DIRECTORY levels/ DESTINATION ${CMAKE_INSTALL_BINDIR}/levels COMPONENT ${_game_component})
```

`PACKAGE_BUILDER_CPACK_COMPONENTS` lists the components the generated packages carry. Every
generator honours it: the ZIP and DEB generators run in component mode with all listed components
grouped into one package, so each still produces one file named `<PROJECT_NAME>-<version>-<os>-<arch>`.
A component left off the list ships in no package, while its targets still build and its install
rules still run for `cmake --install`. On Windows, an executable whose component is not listed gets
no Start Menu entry, desktop shortcut or menu link, and cannot be the `PRIMARY_TARGET`.

### Runtime-only installers

By default, `PACKAGE_BUILDER_CPACK_COMPONENTS` is `Runtime` plus every component a target was
registered with, so the generated installers carry executables, app bundles, and shared libraries.
Development-facing artifacts such as static libraries, public headers, exported CMake target
definitions, and package config files are excluded because [Conan](https://conan.io/) is the
preferred method for consuming packages as libraries during development.

To leave a finished-but-unreleased application out of every package, set the list without its
component before calling `package_install()`:

```cmake
# my_game (COMPONENT Game) keeps building and testing, but ships in no package until listed
set(PACKAGE_BUILDER_CPACK_COMPONENTS Runtime Tool)
package_install()
```

### Desktop shortcuts and launchers

Every packaged executable gets a Start Menu entry (Windows) and an XDG `.desktop` launcher entry
(Linux). Desktop shortcuts (Windows) go to the package's `PRIMARY_TARGET` by default; pass
`DESKTOP_LINKS` to `package_create()` to choose the targets that receive one, or an empty list for
none. Targets in `DESKTOP_LINKS` whose component is not listed get none:

```cmake
# Both apps get a desktop shortcut
package_create(PRIMARY_TARGET my_app DESKTOP_LINKS my_app my_tool)
```

| Platform | Behavior |
|----------|----------|
| Windows  | See [Windows one-click installer](#windows-one-click-installer) below for desktop shortcut behavior. An executable's `MENU_LINKS` add Start Menu links that ship with it. The NSIS installer icon is the package's `ICON`, else the `PRIMARY_TARGET`'s. |
| Linux    | Installs the `.desktop` file provided via `LINUX_DESKTOP_FILE` to `share/applications`, and installs the icon theme tree provided via `LINUX_ICON_THEME_DIR` to `share/icons`. If `LINUX_DESKTOP_FILE` is omitted, PackageBuilder falls back to looking for a `<target>.desktop` file in the same directory as the target's `CMakeLists.txt`. |
| macOS    | No action needed — DragNDrop bundles are self-contained and Launchpad discovers them automatically when dragged to `/Applications`. |

### Windows one-click installer

By default (`PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER ON`), the generated NSIS installer is
**zero-interaction**: the user double-clicks the installer, it installs the application, creates a
desktop shortcut, and closes automatically. No wizard pages, no "Next" buttons, no path or
directory choices.

When set to `OFF`, the installer reverts to the classic NSIS wizard with Welcome, License,
Directory, Start Menu, and Install pages, plus an opt-in desktop shortcut checkbox.

```cmake
# Default: zero-interaction installer (user just double-clicks)
# set(PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER ON)

# Classic wizard with pages
set(PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER OFF)
package_install()
```

| Mode | Desktop shortcut | PATH modification | Wizard pages |
|------|-----------------|-------------------|--------------|
| `ON` (default) | Always created unconditionally | Never added to PATH | None — installs silently |
| `OFF` | Opt-in checkbox during install | User-controlled via installer page | Welcome, License, Directory, Start Menu, Finish |

#### Providing a custom NSIS template

If your project needs a fully custom NSIS installer template, set `PACKAGE_BUILDER_NSIS_TEMPLATE_DIR`
to the directory containing your `NSIS.template.in` before calling `package_install()`. This
directory takes the highest priority over PackageBuilder's own template:

```cmake
set(PACKAGE_BUILDER_NSIS_TEMPLATE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/packaging/nsis")
package_install()
```

PackageBuilder's lookup order for `NSIS.template.in` (highest to lowest priority):

1. `PACKAGE_BUILDER_NSIS_TEMPLATE_DIR` — caller-provided override
2. PackageBuilder's bundled `cmake/NSIS/` directory (one-click template)
3. CMake's built-in NSIS template (classic wizard)

### Including development components

If your project needs installers that also ship development files, set `PACKAGE_BUILDER_CPACK_COMPONENTS` before calling `package_install()`. Setting it replaces the default list, so name every component the packages should carry:

```cmake
set(PACKAGE_BUILDER_CPACK_COMPONENTS Runtime Development)
package_install()
```

---

## Project Structure

PackageBuilder is designed to work best with the following project layout:

```
MyProject/
|- CMakeLists.txt
|- cmake/              # Optional: custom CMake modules (auto-installed alongside config files)
|- include/            # Public headers (auto-installed to the system include directory)
`- src/                # Private source and header files
```

- Headers in `include/` are exposed publicly to consumers of your library.
- The project root is also added as a private include directory for targets created by
  `package_add_library` and `package_add_executable`.
- Files in `src/` are private to your project and are not installed.
- Any `.cmake` files in `cmake/` are installed alongside the generated package config, making them
  available to consumers via `CMAKE_MODULE_PATH`.

Projects with non-canonical layouts can still use PackageBuilder by creating targets themselves and
then registering them with `package_register_target(...)`.

---

## Complete Example

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyAwesomeLib VERSION 1.0.0 DESCRIPTION "An awesome library" LANGUAGES CXX)

# Or use FetchContent if the package is not installed
find_package(PackageBuilder REQUIRED)
include(PackageBuilder)

# Create the package - validates version, description, and license
package_create()

# Create targets
package_add_library(awesome src/awesome.cpp)
package_add_executable(awesome_app src/main.cpp
    ICON                 resources/awesome_app.ico
    LINUX_DESKTOP_FILE   resources/awesome_app.desktop
    LINUX_ICON_THEME_DIR resources/icons)

target_link_libraries(awesome_app PRIVATE MyAwesomeLib::awesome)

# Give awesome_app a Start Menu entry and desktop shortcut (Windows), install its
# .desktop file to share/applications (Linux), and install its icon theme
# assets to share/icons (Linux)
package_install()
```

---

## Example: JUCE Application

[JUCE](https://juce.com/) creates GUI app targets via `juce_add_gui_app` rather than
`add_executable`. Use `package_register_target` to hand the externally-created target off to
PackageBuilder:

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyApp VERSION 1.0.0 DESCRIPTION "A JUCE-based application" LANGUAGES CXX)

find_package(PackageBuilder REQUIRED)
include(PackageBuilder)

package_create()

# JUCE creates and configures the target internally
juce_add_gui_app(my_app
    PRODUCT_NAME "My App"
    VERSION      ${PROJECT_VERSION})

target_sources(my_app PRIVATE main.cpp)
target_compile_definitions(my_app PRIVATE JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0)
target_link_libraries(my_app PRIVATE juce::juce_gui_basics juce::juce_recommended_warning_flags)

# Register the JUCE target so PackageBuilder includes it in install/CPack output
package_register_target(my_app
    DISPLAY_NAME         "My App"
    ICON                 resources/my_app.ico
    LINUX_DESKTOP_FILE   resources/my_app.desktop
    LINUX_ICON_THEME_DIR resources/icons)

# Give the executable its version information and icon through JUCE's own resource script
if(WIN32)
    package_write_resource_script(_my_app_rc my_app)
    target_compile_definitions(my_app PRIVATE JUCE_USER_DEFINED_RC_FILE="${_my_app_rc}")
endif()

# Give my_app a Start Menu entry and desktop shortcut (Windows), install its .desktop
# file to share/applications (Linux), and install its icon theme assets to
# share/icons (Linux)
package_install()
```

For Linux desktop icons, place PNG files under a standard icon theme layout rooted at the
directory passed to `LINUX_ICON_THEME_DIR`, for example:

```text
resources/icons/
`- hicolor/
   |- 32x32/apps/my_app.png
   |- 48x48/apps/my_app.png
   |- 64x64/apps/my_app.png
   |- 128x128/apps/my_app.png
   `- 256x256/apps/my_app.png
```

Then set `Icon=my_app` in your `.desktop` file, without a file extension.

