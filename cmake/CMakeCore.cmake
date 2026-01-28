include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

function(core_get_project_version)

    # If project version is already defined, return
    if(PROJECT_VERSION)
        return()
    endif()

    # Get the version information from Git
    find_package(Git QUIET)
    if(git_FOUND)

        # Use "git describe" to get version information from Git
        execute_process(
                COMMAND ${GIT_EXECUTABLE} describe --dirty --long --match=v* --tags
                WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
                RESULT_VARIABLE git_result
                OUTPUT_VARIABLE git_output OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_VARIABLE git_error ERROR_STRIP_TRAILING_WHITESPACE)

        # If the result is not "0" an error has occurred
        if(git_result)
            message(FATAL_ERROR ${git_error})
        endif()

        # Parse the version string returned by Git
        # Format is "v<MAJOR>.<MINOR>.<PATCH>-<TWEAK>-<GIT_HASH>[-dirty]"
        if(git_output MATCHES "^v([0-9]+)[.]([0-9]+)[.]([0-9]+)-([0-9]+)")
            set(version_major ${CMAKE_MATCH_1})
            set(version_minor ${CMAKE_MATCH_2})
            set(version_patch ${CMAKE_MATCH_3})
            set(version_tweak ${CMAKE_MATCH_4})

            string(APPEND version "${version_major}.${version_minor}.${version_patch}")
        else()
            message(FATAL_ERROR "Git returned an invalid version: ${git_output}")
        endif()

        # The version is considered dirty if there are uncommitted local changes
        if(git_output MATCHES "-dirty$")
            set(version_is_dirty TRUE)
        else()
            set(version_is_dirty FALSE)
        endif()

        # Use "git log" to get the current commit hash from Git
        execute_process(
                COMMAND ${GIT_EXECUTABLE} log -1 --pretty=format:%H
                WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
                RESULT_VARIABLE git_result
                OUTPUT_VARIABLE git_output OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_VARIABLE git_error ERROR_STRIP_TRAILING_WHITESPACE)

        # If the result is not "0" an error has occurred
        if(git_result)
            message(FATAL_ERROR ${git_error})
        endif()

        set(version_git_hash ${git_output})

        # Set global CMake variables containing project version information
        set(PROJECT_VERSION ${version} PARENT_SCOPE)
        set(PROJECT_VERSION_MAJOR ${version_major} PARENT_SCOPE)
        set(PROJECT_VERSION_MINOR ${version_minor} PARENT_SCOPE)
        set(PROJECT_VERSION_PATCH ${version_patch} PARENT_SCOPE)
        set(PROJECT_VERSION_TWEAK ${version_tweak} PARENT_SCOPE)
        set(PROJECT_VERSION_IS_DIRTY ${version_is_dirty} PARENT_SCOPE)
        set(PROJECT_VERSION_HASH ${version_git_hash} PARENT_SCOPE)

        set(${PROJECT_NAME}_VERSION ${version} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_MAJOR ${version_major} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_MINOR ${version_minor} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_PATCH ${version_patch} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_TWEAK ${version_tweak} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_IS_DIRTY ${version_is_dirty} PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_HASH ${version_git_hash} PARENT_SCOPE)

    endif()

    if(NOT PROJECT_VERSION)
        set(PROJECT_VERSION "0.0.0" PARENT_SCOPE)
        set(PROJECT_VERSION_MAJOR "0" PARENT_SCOPE)
        set(PROJECT_VERSION_MINOR "0" PARENT_SCOPE)
        set(PROJECT_VERSION_PATCH "0" PARENT_SCOPE)
        message(WARNING "Project version could not be determined."
            "Defaulting to 0.0.0."
            "Either specify the project version manually or add a Git tag(v<major>.<minor>.<patch>) to override.")
    endif()
endfunction()

function(core_install)
    set(options)
    set(one_value_args NAMESPACE)
    set(multi_value_args TARGETS)
    cmake_parse_arguments(args "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Set the install destination and namespace
    set(install_destination "lib/cmake/${PROJECT_NAME}")

    if(args_TARGETS)
        # Create an export package of the targets
        # Use GNUInstallDirs and COMPONENTS
        # See "Deep CMake for Library Authors" https://www.youtube.com/watch?v=m0DwB4OvDXk
        # TODO: Implement COMPONENTS
        install(
                TARGETS ${args_TARGETS}
                EXPORT ${PROJECT_NAME}Targets
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
                #COMPONENT Development
                INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                #COMPONENT Development
                LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                #COMPONENT Runtime
                #NAMELINK_COMPONENT Development
                RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
                #COMPONENT Runtime)

        # Install the export package
        install(
                EXPORT ${PROJECT_NAME}Targets
                FILE ${PROJECT_NAME}Targets.cmake
                NAMESPACE ${args_NAMESPACE}
                DESTINATION ${install_destination})

        # Store installed targets for later use by core_generate_package_config
        set(${PROJECT_NAME}_INSTALLED_TARGETS ${args_TARGETS} PARENT_SCOPE)
    endif()

    # Install public CMake modules for the project
    install(
            DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/cmake/
            DESTINATION ${install_destination}
            FILES_MATCHING PATTERN "*.cmake")

    # Install public header files for the project
    install(
            DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/include/
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            FILES_MATCHING PATTERN "*.h*")

    # Generate a package configuration file
    set(config_content "@PACKAGE_INIT@\n")

    string(APPEND config_content "\nlist(APPEND CMAKE_MODULE_PATH \"\${CMAKE_CURRENT_LIST_DIR}\")\n")

    # Include targets file if we have targets installed
    if(${PROJECT_NAME}_INSTALLED_TARGETS)
        string(APPEND config_content "\ninclude(\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}Targets.cmake)")
    endif()

    file(WRITE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in "${config_content}")
    configure_package_config_file(
            ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in
            ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
            INSTALL_DESTINATION ${install_destination})

    # Gather files to be installed
    list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)

    # If the package has a version specified, generate a package version file
    if(PROJECT_VERSION)
        write_basic_package_version_file(${PROJECT_NAME}ConfigVersion.cmake
                VERSION ${PROJECT_VERSION}
                COMPATIBILITY SameMajorVersion)

        list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake)
    endif()

    # Install config files for the project
    install(
            FILES ${install_files}
            DESTINATION ${install_destination})
endfunction()

function(core_conan_package)
    if(CONAN_EXPORTED)
        return()
    endif()

    set(options)
    set(one_value_args USER CHANNEL)
    set(multi_value_args)
    cmake_parse_arguments(args "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    if(NOT PROJECT_VERSION)
        message(FATAL "Project version not specified.")
    endif()

    if(NOT args_CHANNEL)
        if(PROJECT_VERSION_TWEAK OR PROJECT_VERSION_IS_DIRTY)
            set(args_CHANNEL testing)
        else()
            set(args_CHANNEL stable)
        endif()
    endif()
    if(NOT args_USER)
        set(args_USER "localuser")
    endif()

    # Make sure conanfile.py exists
    if(NOT EXISTS ${PROJECT_SOURCE_DIR}/conanfile.py)
        message(FATAL_ERROR "No conanfile.py found for the current project.")
    endif()

    # Build package into local cache
    set(package_ref "${PROJECT_NAME}/${PROJECT_VERSION}@${args_USER}/${args_CHANNEL}")
    add_custom_target(${args_NAME}_conan_create ALL
        COMMAND conan create ${PROJECT_SOURCE_DIR} ${package_ref}
        VERBATIM
        COMMENT "Building and installing ${package_ref} into local cache"
    )
endfunction()
