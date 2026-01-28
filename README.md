# CMakeCore

**Tired of writing hundreds of lines of CMake boilerplate just to create a properly installable library?** Stop drowning in cryptic configuration! Build sleek, professional C++ libraries and executables with a few simple CMake function calls. Target creation, include paths, installation, and package configs—all handled automatically.

## Overview

`CMakeCore` provides a collection of CMake utility functions that simplify common project setup tasks including:
- Git-based semantic versioning
- Simplified target creation with standard include directory structures
- Automated installation and packaging with CMake config file generation
- Namespace support for library targets

## ⚠️ Required Project Structure

**IMPORTANT:** This library requires your project to follow a standard directory structure with `include/` and `src/` directories. See [Project Structure Conventions](#project-structure-conventions) below for full details.

## Installation and Setup

### Prerequisites
- CMake 3.15 or higher
- Git (required for version management)

Choose one of the following installation methods:

---

### Method 1: FetchContent (Recommended)

This is the easiest and most common method. CMake automatically downloads and integrates CMakeCore into your project.

**CMakeLists.txt:**
```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    CMakeCore
    GIT_REPOSITORY <repository-url>
    GIT_TAG main  # or specify a version tag like v1.0.0
)
FetchContent_MakeAvailable(CMakeCore)

include(CMakeCore)

# CMakeCore.cmake is now available - use the functions below
```

---

### Method 2: System-Wide Installation

For system-wide installation (requires admin/sudo privileges):

**Terminal:**
```bash
git clone <repository-url> CMakeCore
cd CMakeCore
cmake -B build
cmake --install build --prefix /usr/local  # or your preferred install location
```

**CMakeLists.txt:**
```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

find_package(CMakeCore REQUIRED)

include(CMakeCore)

# CMakeCore.cmake is now available - use the functions below
```

---

### Method 3: Git Submodule + Subdirectory

If you prefer to track the dependency in your repository, or if you need to make custom modifications to the library:

**Terminal:**
```bash
# Add CMakeCore as a git submodule
git submodule add <repository-url> external/CMakeCore
git submodule update --init --recursive
```

**CMakeLists.txt:**
```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

# Add CMakeCore module path and include it
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/external/CMakeCore/cmake")
include(CMakeCore)

# CMakeCore.cmake is now available - use the functions below
```

**Note:** This method is ideal if your project uses a non-standard directory structure and you need to fork/modify CMakeCore to work with your specific setup. You can make changes directly in the submodule without affecting other projects.

---

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

**What this does:** Makes your project installable and usable by other CMake projects via `find_package()`.

After installing your project, other developers can use it like this:
```cmake
find_package(MyProject REQUIRED)
target_link_libraries(their_app PRIVATE MyProject::my_library)
```

This function automatically generates:
- `<PROJECT_NAME>Config.cmake` - Tells CMake how to find and use your project
- `<PROJECT_NAME>ConfigVersion.cmake` - Enables version checking (uses SameMajorVersion compatibility)
- Includes all your CMake modules and export targets

**Note:** You only need this if you're creating a library that other projects will use via `find_package()`. Skip this for standalone applications.

## Complete Example

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyAwesomeProject LANGUAGES CXX)

# Fetch CMakeCore
include(FetchContent)
FetchContent_Declare(
    CMakeCore
    GIT_REPOSITORY <repository-url>
    GIT_TAG main
)
FetchContent_MakeAvailable(CMakeCore)

include(CMakeCore)

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

Your project **MUST** follow this structure for CMakeCore functions to work correctly:

```
MyProject/
├── CMakeLists.txt
├── cmake/                  # OPTIONAL: Custom CMake modules
│   └── FindSomeLib.cmake   # Automatically installed by core_install()
├── include/                # REQUIRED: Public headers
│   ├── my_library/         # Per-target headers (optional)
│   │   └── api.h
│   └── MyNamespace/        # REQUIRED if using core_set_namespace()
│       └── my_library/     # Per-target headers (optional)
│           └── api.h
├── src/                    # REQUIRED: Implementation files
│   ├── my_library/         # Optional organization
│   │   └── impl.cpp
│   └── main.cpp
└── ...
```

### What Each Directory Does

- **`include/`** (Required): Public header files that will be installed and accessible to users of your library
  - Automatically added to include paths by `core_add_library()` and `core_add_executable()`
  - Headers are installed to the system include directory by `core_install()`

- **`src/`** (Required): Private source files and implementation-only headers
  - Automatically added as a PRIVATE include directory
  - Not installed by `core_install()`

- **`cmake/`** (Optional): Custom CMake modules (e.g., FindXXX.cmake, XXXConfig.cmake)
  - Automatically installed by `core_install()` if the directory exists

- **Per-target subdirectories** (Optional but recommended):
  - `include/<target>/` or `include/<namespace>/<target>/`: Target-specific headers
  - Automatically added as PRIVATE include paths for that target

### If Your Project Has a Different Structure

If you can't use this structure, you'll need to:
1. Use standard CMake functions (`add_library()`, `add_executable()`) instead of `core_add_library()` and `core_add_executable()`
2. Manually configure include directories with `target_include_directories()`
3. Manually configure installation with `install()` commands

The `core_set_version_from_git()` and `core_set_namespace()` functions will still work regardless of your directory structure.
