# PackageBuilder

**Tired of writing hundreds of lines of CMake boilerplate just to create a properly installable library?** Build sleek, professional C++ libraries and executables with a few simple function calls. Versioning, installation, package config generation, and Conan integration—all handled automatically.

---

## Prerequisites

- CMake 3.24 or higher
- Git (required for automatic version detection)

---

## Getting Started

### Method 1: FetchContent

The simplest way to consume PackageBuilder. No installation step required.

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
```

### Method 2: Install and find_package

Build and install PackageBuilder to your system, then find it like any other CMake package.

**Install:**

```bash
git clone https://github.com/tnt-coders/cmake-package-builder
cd cmake-package-builder
cmake -B build
cmake --install build --prefix /usr/local
```

**Consume:**

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyProject LANGUAGES CXX)

find_package(PackageBuilder REQUIRED)
include(PackageBuilder)
```

### Method 3: Conan via cmake-conan

If your project uses [cmake-conan](https://github.com/tnt-coders/cmake-conan) (the tnt-coders fork), PackageBuilder can be pulled in as a Conan dependency with zero manual installation.

Add the following to your `conanfile.py`:

```python
def requirements(self):
    self.requires("cmake-package-builder/1.0.0 #recipe: https://github.com/tnt-coders/cmake-package-builder.git")
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

For full details on how cmake-conan and the recipe tag work, see the [cmake-conan repository](https://github.com/tnt-coders/cmake-conan).

---

## Usage

### Initialize

**Required.** Must be called before any other PackageBuilder functions.

```cmake
package_create()
```

If `PROJECT_VERSION` is not already set (e.g. via the `project()` command), `package_create()` automatically extracts the version from Git tags. Tags must follow the format `v<MAJOR>.<MINOR>.<PATCH>`. The following variables are set:

| Variable | Description |
|----------|-------------|
| `PROJECT_VERSION` | Full version string (e.g. `1.2.3`) |
| `PROJECT_VERSION_MAJOR` | Major version number |
| `PROJECT_VERSION_MINOR` | Minor version number |
| `PROJECT_VERSION_PATCH` | Patch version number |
| `PROJECT_VERSION_TWEAK` | Number of commits since the last tag |
| `PROJECT_VERSION_IS_DIRTY` | `TRUE` if there are uncommitted local changes |
| `PROJECT_VERSION_HASH` | Full commit hash |

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

### Install

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
project(MyAwesomeLib LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    PackageBuilder
    GIT_REPOSITORY https://github.com/tnt-coders/cmake-package-builder
    GIT_TAG main
)
FetchContent_MakeAvailable(PackageBuilder)

include(PackageBuilder)

# Initialize — pulls version from Git tags automatically
package_create()

# Create targets
package_add_library(awesome src/awesome.cpp)
package_add_executable(awesome_app src/main.cpp)

target_link_libraries(awesome_app PRIVATE MyAwesomeLib::awesome)

# Install everything
package_install()
```

---

## License

MIT
