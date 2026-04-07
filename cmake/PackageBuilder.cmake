include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

# Fails fast if package_create() has not been called before other PackageBuilder entry points.
function(_package_check_initialized)
    get_property(package_initialized GLOBAL PROPERTY PACKAGE_INITIALIZED)
    if(NOT package_initialized)
        message(
            FATAL_ERROR "package_create() must be called before all other PackageBuilder functions."
        )
    endif()
endfunction()

# Converts caller-provided header root paths to absolute paths before storing them as install
# metadata.
function(_package_make_paths_absolute out_var)
    # Public header roots may be passed relative to the caller's CMakeLists, so normalise them once
    # here before storing install metadata globally.
    set(absolute_paths)
    foreach(path IN LISTS ARGN)
        if(IS_ABSOLUTE "${path}")
            list(APPEND absolute_paths "${path}")
        else()
            list(APPEND absolute_paths "${CMAKE_CURRENT_SOURCE_DIR}/${path}")
        endif()
    endforeach()
    set(${out_var}
        "${absolute_paths}"
        PARENT_SCOPE)
endfunction()

# Records an existing target for install/export handling and optionally tracks public header roots
# for header installation. This helper must not mutate target build settings.
function(_package_register_target_impl target)
    cmake_parse_arguments(PARSE_ARGV 1 PACKAGE_REGISTER "" "" "PUBLIC_HEADER_DIRS")

    if(NOT TARGET ${target})
        message(FATAL_ERROR "Target '${target}' does not exist and cannot be registered.")
    endif()

    # External targets may already be fully configured, so registration only records packaging
    # metadata and must not mutate build properties such as include paths or sources.
    set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_TARGETS ${target})

    if(PACKAGE_REGISTER_PUBLIC_HEADER_DIRS)
        _package_make_paths_absolute(public_header_dirs ${PACKAGE_REGISTER_PUBLIC_HEADER_DIRS})
        set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_PUBLIC_HEADER_PATHS
                                            ${public_header_dirs})
    endif()
endfunction()

# Filters a target list down to runtime-bearing targets that should contribute executable/shared
# artifacts to installers and runtime dependency collection.
function(_package_collect_runtime_targets out_var)
    set(runtime_targets)
    foreach(target IN LISTS ARGN)
        if(TARGET ${target})
            get_target_property(target_type ${target} TYPE)
            if(target_type STREQUAL "EXECUTABLE"
               OR target_type STREQUAL "SHARED_LIBRARY"
               OR target_type STREQUAL "MODULE_LIBRARY")
                list(APPEND runtime_targets ${target})
            endif()
        endif()
    endforeach()
    set(${out_var}
        "${runtime_targets}"
        PARENT_SCOPE)
endfunction()

# Validates that the project has the minimum metadata needed for packaging and marks the module as
# initialized.
function(package_create)

    if(NOT PROJECT_VERSION)
        message(FATAL_ERROR "PROJECT_VERSION is not set. Add a VERSION to your project() call, "
                            "e.g. project(MyProject VERSION 1.0.0)")
    endif()

    if(NOT PROJECT_DESCRIPTION)
        message(
            FATAL_ERROR "PROJECT_DESCRIPTION is not set. Add a DESCRIPTION to your project() call, "
                        "e.g. project(MyProject DESCRIPTION \"A short summary\")")
    endif()

    if(NOT EXISTS "${PROJECT_SOURCE_DIR}/LICENSE")
        message(
            FATAL_ERROR "A LICENSE file is required at ${PROJECT_SOURCE_DIR}/LICENSE for packaging."
        )
    endif()

    set_property(GLOBAL PROPERTY PACKAGE_INITIALIZED TRUE)
endfunction()

# Registers a target created outside PackageBuilder so it participates in install/export/CPack
# generation.
function(package_register_target target)
    _package_check_initialized()
    # This is the low-level integration point for targets created outside PackageBuilder.
    _package_register_target_impl(${target} ${ARGN})
endfunction()

# Creates and registers an executable target using PackageBuilder's conventional private include
# defaults for application-style layouts.
function(package_add_executable target)
    _package_check_initialized()

    add_executable(${target} ${ARGN})

    # Executables don't need a public header surface, but adding the project root keeps app-style
    # layouts working without extra include boilerplate.
    target_include_directories(
        ${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/include
                          ${CMAKE_CURRENT_SOURCE_DIR}/src)

    _package_register_target_impl(${target})
endfunction()

# Creates and registers a library target, wiring conventional public/private include paths and the
# default public header installation root.
function(package_add_library target)
    _package_check_initialized()

    add_library(${target} ${ARGN})

    target_include_directories(
        ${target}
        PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
               $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        # The source-tree root is a build-time convenience only. Consumers still see just the
        # installed public include directory.
        PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/src)

    # Libraries created by PackageBuilder use the conventional include/ directory as installable
    # public headers without requiring a separate registration call.
    _package_register_target_impl(${target} PUBLIC_HEADER_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include)

    add_library(${PROJECT_NAME}::${target} ALIAS ${target})
endfunction()

# Generates install rules, package config files, and CPack configuration for all registered targets
# and public header roots in the current project.
function(package_install)
    _package_check_initialized()

    get_property(targets GLOBAL PROPERTY ${PROJECT_NAME}_TARGETS)
    _package_collect_runtime_targets(runtime_targets ${targets})

    # Set the install destination and namespace
    set(install_destination "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

    if(targets)
        set(runtime_dep_arg)
        if(runtime_targets)
            set(runtime_dep_arg RUNTIME_DEPENDENCY_SET ${PROJECT_NAME}RuntimeDeps)
        endif()

        # Create an export package of the targets Use GNUInstallDirs and COMPONENTS See "Deep CMake
        # for Library Authors" https://www.youtube.com/watch?v=m0DwB4OvDXk
        install(
            TARGETS ${targets} ${runtime_dep_arg}
            EXPORT ${PROJECT_NAME}Targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
                    # GUI applications may be packaged as bundles on Apple platforms, so keep bundle
                    # payloads in the runtime component alongside normal executables.
            BUNDLE DESTINATION . COMPONENT Runtime
            INCLUDES
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            COMPONENT Development
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                    COMPONENT Runtime
                    NAMELINK_COMPONENT Development
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime)

        if(runtime_targets)
            # Regexes matched against the *unresolved* dependency name (skips disk lookup entirely)
            set(_pre_exclude_regexes
                [=[api-ms-]=] # Windows API sets
                [=[ext-ms-]=] # Windows extension sets
                [=[kernel32\.dll]=]
                [=[ntdll\.dll]=]
                [=[libc\.so\.]=] # Linux glibc
                [=[libgcc_s\.so\.]=]
                [=[libm\.so\.]=]
                [=[libstdc\+\+\.so\.]=]
                [=[libpthread\.so\.]=] # no-op on glibc 2.34+ (merged into libc)
                [=[libdl\.so\.]=] # same
                [=[librt\.so\.]=] # same
                [=[ld-linux.*\.so\.]=] # dynamic linker
            )

            # Regexes matched against the *resolved* full path (catch-all safety net)
            set(_post_exclude_regexes
                [=[.*[/\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\][Ss][Yy][Ss][Tt][Ee][Mm]32[/\\].*]=]
                [=[^/lib]=] # Linux system libs
                [=[^/usr/lib]=] # Linux multiarch + macOS system libs
                [=[^/System/Library]=] # macOS system frameworks
            )

            install(
                RUNTIME_DEPENDENCY_SET
                ${PROJECT_NAME}RuntimeDeps
                DESTINATION
                ${CMAKE_INSTALL_BINDIR}
                COMPONENT
                Runtime
                PRE_EXCLUDE_REGEXES
                ${_pre_exclude_regexes}
                POST_EXCLUDE_REGEXES
                ${_post_exclude_regexes})
        endif()

        # Export metadata is a development artifact and should stay out of runtime-only installers.
        install(
            EXPORT ${PROJECT_NAME}Targets
            FILE ${PROJECT_NAME}Targets.cmake
            NAMESPACE ${PROJECT_NAME}::
            DESTINATION ${install_destination})
    endif()

    # Install public header files for the project
    get_property(public_header_paths GLOBAL PROPERTY ${PROJECT_NAME}_PUBLIC_HEADER_PATHS)
    foreach(public_header_path IN LISTS public_header_paths)
        install(
            DIRECTORY ${public_header_path}/
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            FILES_MATCHING
            PATTERN "*.h*")
    endforeach()

    # Install public CMake modules for the project
    install(
        DIRECTORY ${PROJECT_SOURCE_DIR}/cmake/
        DESTINATION ${install_destination}
        FILES_MATCHING
        PATTERN "*.cmake")

    # Generate a package configuration file
    set(config_content "@PACKAGE_INIT@\n")

    string(APPEND config_content
           "\nlist(APPEND CMAKE_MODULE_PATH \"\${CMAKE_CURRENT_LIST_DIR}\")\n")

    # Include targets file if we have targets installed
    if(targets)
        string(APPEND config_content
               "\ninclude(\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}Targets.cmake)")
    endif()

    file(WRITE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in "${config_content}")
    configure_package_config_file(
        ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in
        ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
        INSTALL_DESTINATION ${install_destination})

    # Gather files to be installed
    list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)

    # Generate a package version file
    write_basic_package_version_file(
        ${PROJECT_NAME}ConfigVersion.cmake
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMajorVersion)

    list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake)

    # Install config files for the project
    install(FILES ${install_files} DESTINATION ${install_destination})

    # CPack configuration
    set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
    set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")

    # Normalize system name: linux-x86_64, macos-arm64, windows-x86_64, etc.
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" _os)
    if(_os STREQUAL "darwin")
        set(_os "macos")
    endif()
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
    if(_arch MATCHES "amd64")
        set(_arch "x86_64")
    elseif(_arch MATCHES "arm64|aarch64")
        set(_arch "arm64")
    endif()
    set(CPACK_SYSTEM_NAME "${_os}-${_arch}")
    set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${_os}-${_arch}")

    if(NOT runtime_targets)
        message(
            STATUS
                "No runtime targets found for ${PROJECT_NAME}; skipping CPack package generation.")
        return()
    endif()

    # Both ZIP and native installer per platform. Installers should ship runtime artifacts by
    # default (apps/shared runtime), not development files such as headers/static libraries/CMake
    # package metadata.
    if(NOT DEFINED PACKAGE_BUILDER_CPACK_COMPONENTS)
        set(PACKAGE_BUILDER_CPACK_COMPONENTS Runtime)
    endif()
    set(CPACK_COMPONENTS_ALL ${PACKAGE_BUILDER_CPACK_COMPONENTS})

    if(WIN32)
        set(CPACK_GENERATOR "ZIP;NSIS")
        set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
        set(CPACK_NSIS_MODIFY_PATH ON)
    elseif(APPLE)
        set(CPACK_GENERATOR "ZIP;DragNDrop")
    else()
        set(CPACK_GENERATOR "ZIP;DEB")
        set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${PROJECT_NAME} maintainers")
    endif()

    include(CPack)
endfunction()
