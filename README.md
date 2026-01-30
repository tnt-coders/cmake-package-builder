# PackageBuilder

**Tired of writing hundreds of lines of CMake boilerplate just to create a properly installable library?** Build sleek, professional C++ libraries and executables with a few simple function calls. Versioning, installation, package config generation, and Conan integration—all handled automatically.

## Overview

`PackageBuilder` provides CMake utility functions that simplify:
- Automatic Git-based semantic versioning
- Target creation with automatic namespace aliasing
- Installation with CMake config file generation
- Conan package export

## Installation

### Prerequisites
- CMake 3.24 or higher
- Git (for automatic version detection)

### Method 1: FetchContent (Recommended)

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyProject LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    PackageBuilder
    GIT_REPOSITORY https://github.com/tnt-coders/cmake-package-builder
    GIT_TAG main
)
FetchContent_MakeAvailable(PackageBuilder)

include(PackageBuilder)

# PackageBuilder functions are now available
```

### Method 2: Conan

```bash
conan install cmake-package-builder/1.0.0@
```

```cmake
find_package(PackageBuilder REQUIRED)
include(PackageBuilder)
```

### Method 3: System-Wide Installation

```bash
git clone https://github.com/tnt-coders/cmake-package-builder
cd cmake-package-builder
cmake -B build
cmake --install build --prefix /usr/local
```

```cmake
find_package(PackageBuilder REQUIRED)
include(PackageBuilder)
```

## Usage

### Initialize Package

**Required.** Must be called before any other PackageBuilder functions.

```cmake
package_init()
```

If `PROJECT_VERSION` is not set, this automatically extracts the version from Git tags (format: `v<MAJOR>.<MINOR>.<PATCH>`). Sets the following variables:

| Variable | Description |
|----------|-------------|
| `PROJECT_VERSION` | Full version string (e.g., `1.2.3`) |
| `PROJECT_VERSION_MAJOR` | Major version number |
| `PROJECT_VERSION_MINOR` | Minor version number |
| `PROJECT_VERSION_PATCH` | Patch version number |
| `PROJECT_VERSION_TWEAK` | Commits since last tag |
| `PROJECT_VERSION_IS_DIRTY` | `TRUE` if uncommitted changes exist |
| `PROJECT_VERSION_HASH` | Current commit hash |

### Create Targets

```cmake
# Create an executable
package_add_executable(my_app source1.cpp source2.cpp)

# Create a library (automatically aliased as ProjectName::my_lib)
package_add_library(my_lib source1.cpp source2.cpp)
```

Libraries are automatically given a namespaced alias based on `PROJECT_NAME`, allowing consumers to use `find_package()` and link with `ProjectName::target_name`.

### Install Package

```cmake
package_install()
```

This single function:
- Installs all targets created with `package_add_*` functions
- Installs public headers from `include/`
- Installs CMake modules from `cmake/`
- Generates and installs `<ProjectName>Config.cmake` and `<ProjectName>ConfigVersion.cmake`

After installation, other projects can use your library:
```cmake
find_package(MyProject REQUIRED)
target_link_libraries(app PRIVATE MyProject::my_lib)
```

### Export to Conan (Optional)

```cmake
package_export(CONAN_PACKAGE my-package-name)
```

When building with `-DCONAN_EXPORT=ON`, this creates a Conan package in the local cache.

## Complete Example

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyAwesomeLib LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    PackageBuilder
    GIT_REPOSITORY https://github.com/tnt-coders/cmake-package-builder
    GIT_TAG main
)
FetchContent_MakeAvailable(PackageBuilder)

include(PackageBuilder)

# Initialize (gets version from Git if not set)
package_init()

# Create targets
package_add_library(awesome src/awesome.cpp)
package_add_executable(awesome_app src/main.cpp)

target_link_libraries(awesome_app PRIVATE MyAwesomeLib::awesome)

# Install everything
package_install()

# Optional: Enable Conan export
package_export(CONAN_PACKAGE my-awesome-lib)
```

## Project Structure

PackageBuilder expects:

```
MyProject/
├── CMakeLists.txt
├── cmake/              # Optional: Custom CMake modules (auto-installed)
├── include/            # Public headers (auto-installed)
└── src/                # Source files
```

## License

MIT
