# cmake-core

Distillation of common CMake boilerplate code into simple re-usable functions.

## Overview

`cmake-core` provides a collection of CMake utility functions that simplify common project setup tasks including:
- Git-based semantic versioning
- Simplified target creation with standard include directory structures
- Automated installation and packaging with CMake config file generation
- Namespace support for library targets

## Installation and Setup

### Prerequisites
- CMake 3.15 or higher
- Git (required for version management)

### Recommended: FetchContent (Most Common)

Add this to the top of your `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    cmake-core
    GIT_REPOSITORY <repository-url>
    GIT_TAG main  # or specify a version tag like v1.0.0
)
FetchContent_MakeAvailable(cmake-core)
```

### Alternative Methods

**System-wide installation:**
```bash
git clone <repository-url> cmake-core
cd cmake-core
cmake -B build
cmake --install build --prefix /path/to/install
```

Then in your CMakeLists.txt:
```cmake
find_package(cmake-core REQUIRED)
```

**As a subdirectory:**
```cmake
add_subdirectory(path/to/cmake-core)
```

## Usage

### Setting Version from Git

Automatically set project version from Git tags:

```cmake
core_set_version_from_git()
```

This function expects Git tags in the format `v<MAJOR>.<MINOR>.<PATCH>` (e.g., `v1.2.3`). It sets the following variables:
- `PROJECT_VERSION`, `PROJECT_VERSION_MAJOR`, `PROJECT_VERSION_MINOR`, `PROJECT_VERSION_PATCH`
- `PROJECT_VERSION_TWEAK` (commits since last tag)
- `PROJECT_VERSION_IS_DIRTY` (TRUE if uncommitted changes exist)
- `PROJECT_VERSION_HASH` (current commit hash)
- `<PROJECT_NAME>_VERSION` and related variables

### Setting Project Namespace

Define a namespace for your library targets:

```cmake
core_set_namespace(MyNamespace)
```

This creates namespaced aliases (e.g., `MyNamespace::MyLibrary`) for your targets.

### Creating Executables

```cmake
core_add_executable(
    TARGET my_executable
    SOURCES src/main.cpp src/utils.cpp
)
```

This automatically configures include directories:
- `PUBLIC`: `${PROJECT_SOURCE_DIR}/include`
- `PRIVATE`: `${PROJECT_SOURCE_DIR}/include/<target>` or `${PROJECT_SOURCE_DIR}/include/<namespace>/<target>`
- `PRIVATE`: `${PROJECT_SOURCE_DIR}/src`

### Creating Libraries

Standard library:
```cmake
core_add_library(
    TARGET my_library
    SOURCES src/lib.cpp src/helper.cpp
)
```

Interface-only library:
```cmake
core_add_library(
    TARGET my_header_only_lib
    INTERFACE
)
```

Libraries automatically get:
- Proper include directory configuration for build and install interfaces
- Namespaced aliases if `core_set_namespace()` was called
- RPATH configuration for shared libraries

### Installing Targets

Install all targets in the current directory:
```cmake
core_install()
```

Install specific targets:
```cmake
core_install(TARGETS my_library my_executable)
```

This handles:
- Installing binaries to appropriate locations (using GNUInstallDirs)
- Installing public headers from `include/` directory
- Creating and installing CMake export files
- Installing CMake module files from `cmake/` directory

### Generating Package Config Files

```cmake
core_generate_package_config()
```

This generates:
- `<PROJECT_NAME>Config.cmake` for use with `find_package()`
- `<PROJECT_NAME>ConfigVersion.cmake` with SameMajorVersion compatibility
- Automatic inclusion of CMake modules and target files

## Complete Example

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyAwesomeProject LANGUAGES CXX)

# Fetch cmake-core
include(FetchContent)
FetchContent_Declare(
    cmake-core
    GIT_REPOSITORY <repository-url>
    GIT_TAG main
)
FetchContent_MakeAvailable(cmake-core)

# Set version from Git tags
core_set_version_from_git()

# Set namespace
core_set_namespace(MyNamespace)

# Create a library
core_add_library(
    TARGET awesome_lib
    SOURCES src/awesome.cpp src/helper.cpp
)

# Create an executable
core_add_executable(
    TARGET awesome_app
    SOURCES src/main.cpp
)

# Link executable to library
target_link_libraries(awesome_app PRIVATE MyNamespace::awesome_lib)

# Install everything
core_install(TARGETS awesome_lib awesome_app)

# Generate package config
core_generate_package_config()
```

## Project Structure Conventions

For best results, organize your project as follows:

```
MyProject/
├── CMakeLists.txt
├── cmake/
│   └── (optional CMake modules)
├── include/
│   └── MyNamespace/        # If using namespaces
│       └── my_library/
│           └── header.h
├── src/
│   └── implementation.cpp
└── ...
```

## License

See LICENSE file for details.
