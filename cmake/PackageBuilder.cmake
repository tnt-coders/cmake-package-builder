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

    # If the project uses cmake-conan make sure Conan has been invoked to avoid an error Conan is
    # invoke on the first call to "find_package()" This line only exists to prevent it from
    # complaining about projects that don't consume packages
    if(EXISTS ${PROJECT_SOURCE_DIR}/cmake-conan/conan_provider.cmake)
        find_package(__CONAN_DUMMY__ QUIET)
    endif()

    if(NOT PROJECT_VERSION)
        message(FATAL_ERROR "Package version could not be determined.")
    endif()

    # Search the project for a .clang-tidy file Account for projects that use a shared .clang-tidy
    # config from https://github.com/tnt-coders/project-config
    find_file(
        CLANG_TIDY_FILE .clang-tidy
        PATHS "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/project-config"
        NO_DEFAULT_PATH)
    if(CLANG_TIDY_FILE)
        set(CMAKE_EXPORT_COMPILE_COMMANDS
            ON
            CACHE BOOL "" FORCE)
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
endfunction()
