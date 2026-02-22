include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

function(_package_check_initialized)
    get_property(package_initialized GLOBAL PROPERTY PACKAGE_INITALIZED)
    if(NOT package_initialized)
        message(
            FATAL_ERROR "package_create() must be called before all other PackageBuilder functions."
        )
    endif()
endfunction()

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

    set_property(GLOBAL PROPERTY PACKAGE_INITALIZED TRUE)
endfunction()

function(package_add_executable target)
    _package_check_initialized()

    add_executable(${target} ${ARGN})

    # Executables don't need to publicly expose headers so all headers are private
    target_include_directories(${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include
                                                 ${CMAKE_CURRENT_SOURCE_DIR}/src)

    set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_TARGETS ${target})
endfunction()

function(package_add_library target)
    _package_check_initialized()

    add_library(${target} ${ARGN})

    target_include_directories(
        ${target}
        PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
               $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

    set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_TARGETS ${target})
    set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_PUBLIC_HEADER_PATHS
                                        ${CMAKE_CURRENT_SOURCE_DIR}/include)

    add_library(${PROJECT_NAME}::${target} ALIAS ${target})
endfunction()

function(package_install)
    _package_check_initialized()

    get_property(targets GLOBAL PROPERTY ${PROJECT_NAME}_TARGETS)

    # Set the install destination and namespace
    set(install_destination "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

    if(targets)
        # Create an export package of the targets Use GNUInstallDirs and COMPONENTS See "Deep CMake
        # for Library Authors" https://www.youtube.com/watch?v=m0DwB4OvDXk
        install(
            TARGETS ${targets}
            EXPORT ${PROJECT_NAME}Targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
            INCLUDES
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            COMPONENT Development
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                    COMPONENT Runtime
                    NAMELINK_COMPONENT Development
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime)

        # Install the export package
        install(
            EXPORT ${PROJECT_NAME}Targets
            FILE ${PROJECT_NAME}Targets.cmake
            NAMESPACE ${args_NAMESPACE}
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

    # Both ZIP and native installer per platform
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
