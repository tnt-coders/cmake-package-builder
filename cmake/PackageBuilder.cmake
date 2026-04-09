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
# for header installation. Accepts ICON, LINUX_DESKTOP_FILE, and LINUX_ICON_THEME_DIR to store
# per-target packaging metadata. This helper must not mutate target build settings.
function(_package_register_target_impl target)
    cmake_parse_arguments(PARSE_ARGV 1 PACKAGE_REGISTER ""
                          "ICON;LINUX_DESKTOP_FILE;LINUX_ICON_THEME_DIR" "PUBLIC_HEADER_DIRS")

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

    if(PACKAGE_REGISTER_ICON)
        _package_make_paths_absolute(_icon_abs "${PACKAGE_REGISTER_ICON}")
        set_target_properties(${target} PROPERTIES PACKAGE_BUILDER_ICON "${_icon_abs}")
    endif()

    if(PACKAGE_REGISTER_LINUX_DESKTOP_FILE)
        _package_make_paths_absolute(_desktop_abs "${PACKAGE_REGISTER_LINUX_DESKTOP_FILE}")
        set_target_properties(${target} PROPERTIES PACKAGE_BUILDER_LINUX_DESKTOP_FILE
                                                   "${_desktop_abs}")
    endif()

    if(PACKAGE_REGISTER_LINUX_ICON_THEME_DIR)
        _package_make_paths_absolute(_desktop_icon_dir_abs
                                     "${PACKAGE_REGISTER_LINUX_ICON_THEME_DIR}")
        set_target_properties(${target} PROPERTIES PACKAGE_BUILDER_LINUX_ICON_THEME_DIR
                                                   "${_desktop_icon_dir_abs}")
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
# defaults for application-style layouts. Accepts ICON, LINUX_DESKTOP_FILE, and LINUX_ICON_THEME_DIR
# as packaging metadata; all other arguments are forwarded to add_executable() as sources. When ICON
# is provided on Windows, PackageBuilder also generates a resource file so the executable itself
# gets that icon.
function(package_add_executable target)
    _package_check_initialized()

    cmake_parse_arguments(PARSE_ARGV 1 PACKAGE_EXEC ""
                          "ICON;LINUX_DESKTOP_FILE;LINUX_ICON_THEME_DIR" "")

    add_executable(${target} ${PACKAGE_EXEC_UNPARSED_ARGUMENTS})

    # Executables don't need a public header surface, but adding the project root keeps app-style
    # layouts working without extra include boilerplate.
    target_include_directories(
        ${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/include
                          ${CMAKE_CURRENT_SOURCE_DIR}/src)

    if(WIN32 AND PACKAGE_EXEC_ICON)
        _package_make_paths_absolute(_icon_abs "${PACKAGE_EXEC_ICON}")
        set(_rc_file "${CMAKE_CURRENT_BINARY_DIR}/${target}_icon.rc")
        file(WRITE "${_rc_file}" "IDI_ICON1 ICON \"${_icon_abs}\"\n")
        target_sources(${target} PRIVATE "${_rc_file}")
    endif()

    set(_register_args)
    if(PACKAGE_EXEC_ICON)
        list(APPEND _register_args ICON "${PACKAGE_EXEC_ICON}")
    endif()
    if(PACKAGE_EXEC_LINUX_DESKTOP_FILE)
        list(APPEND _register_args LINUX_DESKTOP_FILE "${PACKAGE_EXEC_LINUX_DESKTOP_FILE}")
    endif()
    if(PACKAGE_EXEC_LINUX_ICON_THEME_DIR)
        list(APPEND _register_args LINUX_ICON_THEME_DIR "${PACKAGE_EXEC_LINUX_ICON_THEME_DIR}")
    endif()

    _package_register_target_impl(${target} ${_register_args})
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
#
# HOW CPack COMPONENTS WORK
# --------------------------
# CPack uses "components" to categorize install() rules. When you run `cpack`, it inspects
# CPACK_COMPONENTS_ALL to decide which install() rules to include in the package. Rules that belong
# to a component not listed in CPACK_COMPONENTS_ALL are silently excluded.
#
# PackageBuilder defines two components. The Runtime component holds executables, macOS app bundles,
# shared libraries, and their transitive runtime dependencies — everything an end user needs to run
# the application. The Development component holds static libraries, public headers, CMake exported
# target definitions, and generated package config files — everything needed to compile against this
# project as a library.
#
# By default, CPACK_COMPONENTS_ALL is set to "Runtime" so generated installers ship only what end
# users need. To also ship development files, set PACKAGE_BUILDER_CPACK_COMPONENTS to "Runtime
# Development" before calling package_install().
function(package_install)
    _package_check_initialized()

    get_property(targets GLOBAL PROPERTY ${PROJECT_NAME}_TARGETS)
    _package_collect_runtime_targets(runtime_targets ${targets})

    # Set the install destination and namespace
    set(install_destination "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

    if(targets)
        # -------------------------------------------------------------------
        # Separate registered targets into two groups.
        #
        # Runtime targets (EXECUTABLE, SHARED_LIBRARY, MODULE_LIBRARY) each need their own
        # per-target install() call with a unique RUNTIME_DEPENDENCY_SET, explained in Group B.
        # Non-runtime targets (STATIC_LIBRARY, OBJECT_LIBRARY, INTERFACE_LIBRARY) share one
        # install() call with no dependency set, but still contribute to the export so
        # find_package() consumers can link against them.
        # -------------------------------------------------------------------
        set(non_runtime_targets ${targets})
        foreach(rt_target IN LISTS runtime_targets)
            list(REMOVE_ITEM non_runtime_targets ${rt_target})
        endforeach()

        # -------------------------------------------------------------------
        # Group A: Non-runtime targets (static/object/interface libraries).
        #
        # ARCHIVE installs the .a / .lib file into the Development component. INCLUDES DESTINATION
        # annotates the export entry with the public include path so downstream consumers get the
        # right INTERFACE_INCLUDE_DIRECTORIES from find_package() without needing a separate
        # target_include_directories().
        # -------------------------------------------------------------------
        if(non_runtime_targets)
            install(
                TARGETS ${non_runtime_targets}
                EXPORT ${PROJECT_NAME}Targets
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
                INCLUDES
                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
        endif()

        if(runtime_targets)
            # ---------------------------------------------------------------
            # Pre-build the exclude regex lists used by every runtime dependency set install. These
            # filters prevent bundling OS-provided libraries that are guaranteed to exist on the
            # target machine.
            #
            # PRE_EXCLUDE_REGEXES match against the unresolved dependency name (fast: no disk lookup
            # required).
            # ---------------------------------------------------------------
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

            # POST_EXCLUDE_REGEXES match against the resolved absolute path (catch-all safety net
            # for paths that slipped past pre-exclude).
            set(_post_exclude_regexes
                [=[.*[/\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\][Ss][Yy][Ss][Tt][Ee][Mm]32[/\\].*]=]
                [=[^/lib]=] # Linux system libs
                [=[^/usr/lib]=] # Linux multiarch + macOS system libs
                [=[^/System/Library]=] # macOS system frameworks
            )

            foreach(rt_target IN LISTS runtime_targets)
                # -----------------------------------------------------------
                # Group B: Per-runtime-target install call.
                #
                # WHY ONE CALL PER TARGET? CMake's install(TARGETS ...) accepts exactly one
                # RUNTIME_DEPENDENCY_SET name per call. On macOS, a runtime dependency set may be
                # associated with at most one app bundle executable. If two bundle targets share one
                # set, CMake fails: "install A runtime dependency set may only have one bundle
                # executable"
                #
                # The fix is to give each runtime target its own uniquely named dependency set. All
                # per-target calls still contribute to the same EXPORT name — CMake merges them into
                # one targets file — so the exported package remains project-wide.
                #
                # Archive files (ARCHIVE) go to Development since they are only needed at link time.
                # App bundles (BUNDLE), shared library binaries (LIBRARY), and other executables
                # (RUNTIME) go to Runtime. Shared library version symlinks (NAMELINK) go to
                # Development since only the compiler needs them.
                # -----------------------------------------------------------
                set(_dep_set "${PROJECT_NAME}_${rt_target}_RuntimeDeps")

                install(
                    TARGETS ${rt_target} RUNTIME_DEPENDENCY_SET ${_dep_set}
                    EXPORT ${PROJECT_NAME}Targets
                    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
                    BUNDLE DESTINATION . COMPONENT Runtime
                    INCLUDES
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                            COMPONENT Runtime
                            NAMELINK_COMPONENT Development
                    RESOURCE DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
                    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime)

                # -----------------------------------------------------------
                # Group C: Per-runtime-target dependency set install.
                #
                # Each RUNTIME_DEPENDENCY_SET declared in Group B must have a matching
                # install(RUNTIME_DEPENDENCY_SET ...) call. CMake resolves the transitive shared
                # library dependencies of the target at install time and copies them to DESTINATION,
                # applying the exclude filters to skip system-provided libraries.
                # -----------------------------------------------------------
                install(
                    RUNTIME_DEPENDENCY_SET
                    ${_dep_set}
                    DESTINATION
                    ${CMAKE_INSTALL_BINDIR}
                    COMPONENT
                    Runtime
                    PRE_EXCLUDE_REGEXES
                    ${_pre_exclude_regexes}
                    POST_EXCLUDE_REGEXES
                    ${_post_exclude_regexes})
            endforeach()
        endif()

        # Export metadata is a development artifact: it is the generated <ProjectName>Targets.cmake
        # file that downstream find_package() calls include to get target definitions. It must not
        # appear in runtime-only installers, so it is tagged COMPONENT Development.
        install(
            EXPORT ${PROJECT_NAME}Targets
            FILE ${PROJECT_NAME}Targets.cmake
            NAMESPACE ${PROJECT_NAME}::
            DESTINATION ${install_destination}
            COMPONENT Development)
    endif()

    # Public headers are consumed at compile time by downstream projects, not at runtime by end
    # users. Tag them Development so they stay out of release packages.
    get_property(public_header_paths GLOBAL PROPERTY ${PROJECT_NAME}_PUBLIC_HEADER_PATHS)
    foreach(public_header_path IN LISTS public_header_paths)
        install(
            DIRECTORY ${public_header_path}/
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            COMPONENT Development
            FILES_MATCHING
            PATTERN "*.h*")
    endforeach()

    # Custom CMake modules (cmake/*.cmake) are consumed by downstream CMake projects via
    # CMAKE_MODULE_PATH after find_package(). They are build-system metadata, not runtime artifacts,
    # and belong in the Development component.
    install(
        DIRECTORY ${PROJECT_SOURCE_DIR}/cmake/
        DESTINATION ${install_destination}
        COMPONENT Development
        FILES_MATCHING
        PATTERN "*.cmake"
        PATTERN "*.in")

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

    # The generated Config and ConfigVersion files are consumed by find_package() in downstream
    # projects. They are CMake package metadata — development artifacts — and must not appear in
    # runtime-only release installers.
    install(
        FILES ${install_files}
        DESTINATION ${install_destination}
        COMPONENT Development)

    # -------------------------------------------------------------------
    # CPack configuration
    #
    # CPack reads the CPACK_* variables set below and generates platform-native installers (ZIP,
    # NSIS, DEB, DragNDrop, etc.) from the install() rules defined above. Only install() rules whose
    # COMPONENT is listed in CPACK_COMPONENTS_ALL are included in the generated package.
    # -------------------------------------------------------------------
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

    # CPACK_COMPONENTS_ALL tells CPack which component buckets to include in the generated
    # installer. Only install() rules tagged with one of these components will be packaged.
    #
    # Default: Runtime only — release installers ship app executables and shared libraries but not
    # headers, static libs, or CMake package metadata. Set PACKAGE_BUILDER_CPACK_COMPONENTS to
    # "Runtime Development" before calling package_install() to include both.
    if(NOT DEFINED PACKAGE_BUILDER_CPACK_COMPONENTS)
        set(PACKAGE_BUILDER_CPACK_COMPONENTS Runtime)
    endif()
    set(CPACK_COMPONENTS_ALL ${PACKAGE_BUILDER_CPACK_COMPONENTS})

    if(WIN32)
        set(CPACK_GENERATOR "ZIP;NSIS")
        set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
        # In one-click mode the InstallOptions page (which let the user toggle $DO_NOT_ADD_TO_PATH)
        # is removed. Setting MODIFY_PATH OFF prevents the installer from silently adding the
        # install directory to PATH on every install. In checkbox mode the page is present and the
        # user controls this, so the default ON applies.
        if(PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER)
            set(CPACK_NSIS_MODIFY_PATH OFF)
        else()
            set(CPACK_NSIS_MODIFY_PATH ON)
        endif()

        # CPACK_PACKAGE_EXECUTABLES: pairs of (executable name, label) for all executables, which
        # drives Start Menu shortcuts. The NSIS generator resolves the name relative to the bin
        # directory automatically. Desktop shortcut behavior is controlled by
        # PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER (default ON):
        #
        # ON  — CPACK_NSIS_CREATE_ICONS_EXTRA and CPACK_NSIS_DELETE_ICONS_EXTRA inject explicit
        # CreateShortCut / Delete commands so shortcuts are always created without a user checkbox.
        # CPACK_CREATE_DESKTOP_LINKS must NOT also be set for the same targets or the installer will
        # create duplicate shortcuts.
        #
        # OFF — CPACK_CREATE_DESKTOP_LINKS is set instead, restoring the NSIS checkbox-based flow
        # where the user opts in or out during installation.
        #
        # No value validation is performed — CMake's if() handles all truthy/falsy spellings.
        #
        # Defaults to all executables if PACKAGE_BUILDER_DESKTOP_LINKS is not set by the caller.
        #
        # CPACK_NSIS_MUI_ICON / CPACK_NSIS_MUI_UNIICON: installer/uninstaller window icon. Set from
        # the first executable that has a PACKAGE_BUILDER_ICON target property.
        if(NOT DEFINED PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER)
            set(PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER ON)
        endif()

        set(_cpack_executables)
        set(_cpack_desktop_links)
        foreach(rt_target IN LISTS runtime_targets)
            get_target_property(_target_type ${rt_target} TYPE)
            if(_target_type STREQUAL "EXECUTABLE")
                get_target_property(_output_name ${rt_target} OUTPUT_NAME)
                if(NOT _output_name)
                    set(_output_name "${rt_target}")
                endif()
                list(APPEND _cpack_executables "${_output_name}" "${_output_name}")
                if(NOT DEFINED PACKAGE_BUILDER_DESKTOP_LINKS OR rt_target IN_LIST
                                                                PACKAGE_BUILDER_DESKTOP_LINKS)
                    list(APPEND _cpack_desktop_links "${_output_name}")
                endif()
                if(NOT CPACK_NSIS_MUI_ICON)
                    get_target_property(_icon ${rt_target} PACKAGE_BUILDER_ICON)
                    if(_icon)
                        set(CPACK_NSIS_MUI_ICON "${_icon}")
                        set(CPACK_NSIS_MUI_UNIICON "${_icon}")
                    endif()
                endif()
            endif()
        endforeach()
        if(_cpack_executables)
            set(CPACK_PACKAGE_EXECUTABLES ${_cpack_executables})
            if(PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER)
                # One-click mode: inject CreateShortCut / Delete commands directly into the NSIS
                # script so desktop shortcuts are created unconditionally at install / uninstall
                # time. CMAKE_INSTALL_BINDIR may use forward slashes; normalize to backslashes
                # because NSIS path syntax requires them.
                string(REPLACE "/" "\\" _nsis_bindir "${CMAKE_INSTALL_BINDIR}")
                set(_nsis_create_icons "")
                set(_nsis_delete_icons "")
                foreach(_exe_name IN LISTS _cpack_desktop_links)
                    string(APPEND _nsis_create_icons
                           "CreateShortCut \"$DESKTOP\\${_exe_name}.lnk\""
                           " \"$INSTDIR\\${_nsis_bindir}\\${_exe_name}.exe\"\n  ")
                    string(APPEND _nsis_delete_icons "Delete \"$DESKTOP\\${_exe_name}.lnk\"\n  ")
                endforeach()
                set(CPACK_NSIS_CREATE_ICONS_EXTRA "${_nsis_create_icons}")
                set(CPACK_NSIS_DELETE_ICONS_EXTRA "${_nsis_delete_icons}")
            else()
                # Checkbox mode: the NSIS installer presents a "Create Desktop Shortcut" checkbox.
                set(CPACK_CREATE_DESKTOP_LINKS ${_cpack_desktop_links})
            endif()
        endif()
    elseif(APPLE)
        set(CPACK_GENERATOR "ZIP;DragNDrop")
        # macOS: DragNDrop bundles are self-contained; users drag .app to /Applications and
        # Launchpad handles discovery automatically. No desktop shortcut action needed.
    else()
        set(CPACK_GENERATOR "ZIP;DEB")
        set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${PROJECT_NAME} maintainers")

        # Install XDG .desktop files and icon theme assets for executables that should get desktop
        # launcher integration. Defaults to all executables if PACKAGE_BUILDER_DESKTOP_LINKS is not
        # set by the caller. Uses the PACKAGE_BUILDER_LINUX_DESKTOP_FILE target property if set;
        # otherwise falls back to expecting a <target>.desktop file in the same directory as the
        # target's CMakeLists.txt. Linux icon assets are installed from LINUX_ICON_THEME_DIR, which
        # is expected to contain a hicolor/... tree rooted at that directory.
        foreach(rt_target IN LISTS runtime_targets)
            get_target_property(_target_type ${rt_target} TYPE)
            if(_target_type STREQUAL "EXECUTABLE")
                if(NOT DEFINED PACKAGE_BUILDER_DESKTOP_LINKS OR rt_target IN_LIST
                                                                PACKAGE_BUILDER_DESKTOP_LINKS)
                    get_target_property(_desktop_file ${rt_target}
                                        PACKAGE_BUILDER_LINUX_DESKTOP_FILE)
                    if(NOT _desktop_file)
                        get_target_property(_source_dir ${rt_target} SOURCE_DIR)
                        set(_desktop_file "${_source_dir}/${rt_target}.desktop")
                    endif()
                    if(EXISTS "${_desktop_file}")
                        install(
                            FILES "${_desktop_file}"
                            DESTINATION share/applications
                            COMPONENT Runtime)
                    else()
                        message(
                            WARNING
                                "PackageBuilder: No .desktop file found for '${rt_target}' at "
                                "${_desktop_file}. Skipping Linux desktop integration for this target."
                        )
                    endif()

                    get_target_property(_desktop_icon_dir ${rt_target}
                                        PACKAGE_BUILDER_LINUX_ICON_THEME_DIR)
                    if(_desktop_icon_dir)
                        if(EXISTS "${_desktop_icon_dir}")
                            install(
                                DIRECTORY "${_desktop_icon_dir}/"
                                DESTINATION "${CMAKE_INSTALL_DATADIR}/icons"
                                COMPONENT Runtime
                                FILES_MATCHING
                                PATTERN "*.png"
                                PATTERN "*.svg")
                        else()
                            message(
                                WARNING
                                    "PackageBuilder: Desktop icon directory for '${rt_target}' "
                                    "does not exist at ${_desktop_icon_dir}. Skipping Linux icon "
                                    "installation for this target.")
                        endif()
                    endif()
                endif()
            endif()
        endforeach()
    endif()

    # Ensure backslashes and other special characters in CPACK variable values are properly escaped
    # when written to CPackConfig.cmake. Without this, backslashes in paths (e.g. bin\appname) would
    # be interpreted as CMake escape sequences when the file is re-read, corrupting values.
    set(CPACK_VERBATIM_VARIABLES TRUE)

    if(WIN32 AND PACKAGE_BUILDER_WINDOWS_ONE_CLICK_INSTALLER)
        # Inject the one-click NSIS template by prepending its directory to CMAKE_MODULE_PATH so
        # CPack's NSIS generator finds it before CMake's built-in template. The precedence is:
        #
        # PACKAGE_BUILDER_NSIS_TEMPLATE_DIR (caller override, highest priority) PackageBuilder's own
        # cmake/NSIS/ directory CMake's built-in templates (lowest priority)
        #
        # CMAKE_CURRENT_FUNCTION_LIST_DIR resolves to the directory containing PackageBuilder.cmake
        # regardless of where package_install() is called from (requires CMake 3.17+).
        list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/NSIS")
        if(DEFINED PACKAGE_BUILDER_NSIS_TEMPLATE_DIR)
            list(PREPEND CMAKE_MODULE_PATH "${PACKAGE_BUILDER_NSIS_TEMPLATE_DIR}")
        endif()
    endif()

    include(CPack)
endfunction()
