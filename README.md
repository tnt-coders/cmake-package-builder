# PackageBuilder

[![Build](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build.yml)

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
- **Description verification:** Verifies that `PROJECT_DESCRIPTION` is set and fails with a fatal error if it is not. Set via the `DESCRIPTION` argument in the `project()` command.
- **License verification:** Verifies that a `LICENSE` file exists at the project root. This is required for CPack packaging.

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
| `ICON`                 | Path to an icon file (`.ico`). On Windows, `package_add_executable()` embeds this into the executable and also uses it as the NSIS installer/uninstaller icon. Paths may be relative to the calling `CMakeLists.txt`. |
| `LINUX_DESKTOP_FILE`   | Path to an XDG `.desktop` file. Installed to `share/applications` on Linux for desktop launcher integration. Paths may be relative to the calling `CMakeLists.txt`. |
| `LINUX_ICON_THEME_DIR` | Path to a directory containing a Linux icon theme subtree such as `hicolor/256x256/apps/myapp.png`. Installed to `share/icons` on Linux. Paths may be relative to the calling `CMakeLists.txt`. |

All other arguments after the target name are forwarded to `add_executable()` as source files.

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

`package_register_target` accepts the same `ICON`, `LINUX_DESKTOP_FILE`, and
`LINUX_ICON_THEME_DIR` arguments as
`package_add_executable`. For externally created targets, `ICON` is packaging metadata only; it is
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

### Runtime-only installers

By default, generated installers include only the **Runtime** component: executables, app bundles,
and shared libraries. Development-facing artifacts such as static libraries, public headers, exported
CMake target definitions, and package config files are excluded because
[Conan](https://conan.io/) is the preferred method for consuming packages as libraries during
development.

### Desktop shortcuts and launchers

By default, every registered executable gets a desktop shortcut (Windows) or an XDG `.desktop`
launcher entry (Linux). To limit this to a specific subset, set `PACKAGE_BUILDER_DESKTOP_LINKS` to
the list of target names that should receive shortcuts before calling `package_install()`:

```cmake
# Only my_app gets a Start Menu / desktop shortcut
set(PACKAGE_BUILDER_DESKTOP_LINKS my_app)
package_install()
```

| Platform | Behavior |
|----------|----------|
| Windows  | See [Windows one-click installer](#windows-one-click-installer) below for desktop shortcut behavior. The NSIS installer icon is taken from the first registered executable that provides `ICON`. |
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

If your project needs installers that also ship development files, set `PACKAGE_BUILDER_CPACK_COMPONENTS` before calling `package_install()`:

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

# Give awesome_app a Start Menu / desktop shortcut (Windows), install its
# .desktop file to share/applications (Linux), and install its icon theme
# assets to share/icons (Linux)
set(PACKAGE_BUILDER_DESKTOP_LINKS awesome_app)
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
    VERSION      ${PROJECT_VERSION}
    ICON_BIG     resources/my_app.ico
    ICON_SMALL   resources/my_app.ico)

target_sources(my_app PRIVATE main.cpp)
target_compile_definitions(my_app PRIVATE JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0)
target_link_libraries(my_app PRIVATE juce::juce_gui_basics juce::juce_recommended_warning_flags)

# Register the JUCE target so PackageBuilder includes it in install/CPack output
package_register_target(my_app
    ICON                 resources/my_app.ico
    LINUX_DESKTOP_FILE   resources/my_app.desktop
    LINUX_ICON_THEME_DIR resources/icons)

# Give my_app a Start Menu / desktop shortcut (Windows), install its .desktop
# file to share/applications (Linux), and install its icon theme assets to
# share/icons (Linux)
set(PACKAGE_BUILDER_DESKTOP_LINKS my_app)
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

