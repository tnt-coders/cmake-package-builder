# PackageBuilder

[![Verify](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/verify.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/verify.yml)
[![Build](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/build.yml)
[![Package](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/package.yml/badge.svg)](https://github.com/tnt-coders/cmake-package-builder/actions/workflows/package.yml)

**Tired of writing hundreds of lines of CMake boilerplate just to create a properly installable library?** Build sleek, professional C++ libraries and executables with a few simple function calls. Installation and package config generation—all handled automatically.

> [!IMPORTANT]
> PackageBuilder expects a [canonical CMake project structure](#project-structure) to function correctly.

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

```
[requires]
cmake-package-builder/1.0.0 #recipe: https://github.com/tnt-coders/cmake-package-builder.git
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

This function performs essential setup before any targets are defined:

- **Version verification:** Verifies that `PROJECT_VERSION` is set and fails with a fatal error if it is not. `PROJECT_VERSION` is typically set by specifying the version in the `project()` command.

### Add Targets

```cmake
# Create a library (automatically aliased as MyProject::mylib)
package_add_library(mylib src/mylib.cpp)

# Create an executable
package_add_executable(myapp src/main.cpp)

# Link them together using the namespaced alias
target_link_libraries(myapp PRIVATE MyProject::mylib)
```

Libraries created with `package_add_library` are automatically given a namespaced alias of `<PROJECT_NAME>::<target>`. This is the same alias that downstream consumers will use after `find_package()`.

### Generate Package Install Logic

```cmake
package_install()
```

This single call handles everything:

- Installs all targets registered via `package_add_library` and `package_add_executable`
- Installs public headers from `include/`
- Installs any custom CMake modules from `cmake/`
- Generates and installs `<ProjectName>Config.cmake` and `<ProjectName>ConfigVersion.cmake`

Downstream projects can then consume your package:

```cmake
find_package(MyProject REQUIRED)
target_link_libraries(myapp PRIVATE MyProject::mylib)
```

---

## Project Structure

PackageBuilder expects your project to follow this layout:

```
MyProject/
├── CMakeLists.txt
├── cmake/              # Optional: custom CMake modules (auto-installed alongside config files)
├── include/            # Public headers (auto-installed to the system include directory)
└── src/                # Private source and header files
```

- Headers in `include/` are exposed publicly to consumers of your library.
- Files in `src/` are private to your project and are not installed.
- Any `.cmake` files in `cmake/` are installed alongside the generated package config, making them available to consumers via `CMAKE_MODULE_PATH`.

---

## Complete Example

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyAwesomeLib VERSION 1.0.0 LANGUAGES CXX)

# Or use FetchContent if the package is not installed
find_package(PackageBuilder REQUIRED)
include(PackageBuilder)

# Create the package — verifies version is set
package_create()

# Create targets
package_add_library(awesome src/awesome.cpp)
package_add_executable(awesome_app src/main.cpp)

target_link_libraries(awesome_app PRIVATE MyAwesomeLib::awesome)

# Install everything
package_install()
```