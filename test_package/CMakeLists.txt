cmake_minimum_required(VERSION 3.24)
project(
    PackageBuilderTest
    VERSION 1.0.0
    DESCRIPTION "PackageBuilder test package"
    LANGUAGES CXX)

# Verify the package can be found and included
find_package(PackageBuilder REQUIRED CONFIG)
include(PackageBuilder)

message(STATUS "PackageBuilder module was successfully found and included.")

# A three-executable sample whose component list leaves the game out, so the package carries the
# GUI app and the command-line tool, beside the package's Start Menu links. The app is the
# PRIMARY_TARGET, so it names the package and gets the desktop shortcut. The tool has no .desktop
# file, which is no reason to warn on Linux, and on Windows it is a console executable, so it gets
# no Start Menu entry or desktop shortcut, but puts the bin directory on PATH. conanfile.py checks
# that the configure warns about neither, that the archive holds the app, the tool and the MSVC C++
# runtime and not the game, that the app's and tool's runtime dependencies install in Runtime while
# the game's stay in Game, and on Windows that the one-click installer compiles. conanfile.py also
# configures once with an empty vendor, the same path as passing no VENDOR, and without the tool.
set(PACKAGE_BUILDER_TEST_VENDOR
    "Test Vendor"
    CACHE STRING "The package's VENDOR; empty checks a package that names no publisher")
set(PACKAGE_BUILDER_TEST_COMPONENTS
    "Runtime;Tool"
    CACHE STRING "The packaged components; Runtime alone checks a package of the GUI app only")
package_create(
    VENDOR
    "${PACKAGE_BUILDER_TEST_VENDOR}"
    PRIMARY_TARGET
    test_app
    MENU_LINKS
    "bin/guide.html"
    "Test Guide"
    "https://example.com/tool"
    "Test Tool Website")

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/test-game.desktop"
     "[Desktop Entry]\nType=Application\nName=Test game\nExec=test-game\n")
package_add_executable(
    test_game
    main.cpp
    DISPLAY_NAME
    "Test Game"
    COMPONENT
    Game
    LINUX_DESKTOP_FILE
    "${CMAKE_CURRENT_BINARY_DIR}/test-game.desktop")
package_add_executable(test_tool main.cpp DISPLAY_NAME "Test Tool" COMPONENT Tool)
set_target_properties(test_game PROPERTIES OUTPUT_NAME test-game)
set_target_properties(test_tool PROPERTIES OUTPUT_NAME test-tool)
package_add_executable(test_app WIN32 main.cpp DISPLAY_NAME "Test App")
set_target_properties(test_app PROPERTIES OUTPUT_NAME test-app)
# The GUI subsystem defaults to a WinMain entry; keep the shared plain main() under MSVC.
target_link_options(test_app PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/ENTRY:mainCRTStartup>)

set(PACKAGE_BUILDER_CPACK_COMPONENTS ${PACKAGE_BUILDER_TEST_COMPONENTS})
package_install()

function(_test_expect what actual expected)
    if(NOT "${actual}" STREQUAL "${expected}")
        message(FATAL_ERROR "${what}: expected '${expected}', got '${actual}'")
    endif()
endfunction()

get_target_property(_game_component test_game PACKAGE_BUILDER_COMPONENT)
_test_expect("game component" "${_game_component}" "Game")
get_target_property(_tool_component test_tool PACKAGE_BUILDER_COMPONENT)
_test_expect("tool component" "${_tool_component}" "Tool")

# Reads the generated CPack configuration in a scope of its own and checks the package it describes.
function(_test_package_configuration)
    include("${CMAKE_BINARY_DIR}/CPackConfig.cmake")
    _test_expect("components" "${CPACK_COMPONENTS_ALL}" "${PACKAGE_BUILDER_TEST_COMPONENTS}")
    _test_expect("Runtime required" "${CPACK_COMPONENT_RUNTIME_REQUIRED}" "TRUE")
    _test_expect("file name" "${CPACK_PACKAGE_FILE_NAME}"
                 "PackageBuilderTest-1.0.0-${CPACK_SYSTEM_NAME}")
    # Defined even when empty: an undefined vendor would take CPack's default, "Humanity".
    if(NOT DEFINED CPACK_PACKAGE_VENDOR)
        message(FATAL_ERROR "CPACK_PACKAGE_VENDOR is undefined, so CPack names a default vendor")
    endif()
    _test_expect("vendor" "${CPACK_PACKAGE_VENDOR}" "${PACKAGE_BUILDER_TEST_VENDOR}")
    if(WIN32)
        if(PACKAGE_BUILDER_TEST_VENDOR)
            _test_expect("install directory" "${CPACK_PACKAGE_INSTALL_DIRECTORY}"
                         "Test Vendor\\Test App")
        else()
            _test_expect("install directory" "${CPACK_PACKAGE_INSTALL_DIRECTORY}" "Test App")
        endif()
        _test_expect("registry key" "${CPACK_PACKAGE_INSTALL_REGISTRY_KEY}" "Test App")

        # Only the GUI app gets a Start Menu entry: the console tool gets none, and nothing of the
        # unlisted game's appears. The package's links join the app's entry.
        _test_expect("executables" "${CPACK_PACKAGE_EXECUTABLES}" "test-app;Test App")
        _test_expect("menu links" "${CPACK_NSIS_MENU_LINKS}"
                     "bin/guide.html;Test Guide;https://example.com/tool;Test Tool Website")

        # The uninstaller removes the vendor folder it created once it is empty, and with no vendor
        # never touches the install directory's parent.
        string(FIND "${CPACK_NSIS_DELETE_ICONS_EXTRA}" "RMDir \"$INSTDIR\\..\"" _found)
        if(PACKAGE_BUILDER_TEST_VENDOR AND _found EQUAL -1)
            message(FATAL_ERROR "the uninstaller keeps the vendor folder:\n"
                                "${CPACK_NSIS_DELETE_ICONS_EXTRA}")
        elseif(NOT PACKAGE_BUILDER_TEST_VENDOR AND NOT _found EQUAL -1)
            message(FATAL_ERROR "the uninstaller removes the parent of a vendor-less install:\n"
                                "${CPACK_NSIS_DELETE_ICONS_EXTRA}")
        endif()

        # The primary GUI app gets the desktop shortcut; neither the tool nor the game gets one.
        set(_shortcuts "${CPACK_NSIS_CREATE_ICONS_EXTRA}")
        string(FIND "${_shortcuts}" "$DESKTOP\\Test App.lnk" _found)
        if(_found EQUAL -1)
            message(FATAL_ERROR "the app has no desktop shortcut:\n${_shortcuts}")
        endif()
        string(TOLOWER "${_shortcuts}" _shortcuts_lower)
        if(_shortcuts_lower MATCHES "test tool|game")
            message(FATAL_ERROR "shortcuts name the tool or the unlisted game:\n${_shortcuts}")
        endif()

        # The packaged tool puts the bin directory on PATH, through the plugin the installed
        # PackageBuilder carries; the GUI app alone leaves PATH alone.
        if("Tool" IN_LIST PACKAGE_BUILDER_TEST_COMPONENTS)
            _test_expect("PATH modification" "${CPACK_NSIS_MODIFY_PATH}" "ON")
        else()
            _test_expect("PATH modification" "${CPACK_NSIS_MODIFY_PATH}" "OFF")
        endif()
        _test_expect("bin directory" "${CPACK_PACKAGE_BUILDER_NSIS_BINDIR}" "bin")
        if(NOT EXISTS "${CPACK_PACKAGE_BUILDER_NSIS_PLUGIN_DIR}/x86-unicode/EnVar.dll")
            message(FATAL_ERROR "the one-click template's EnVar plugin is missing from "
                                "${CPACK_PACKAGE_BUILDER_NSIS_PLUGIN_DIR}")
        endif()
    endif()
endfunction()
_test_package_configuration()

message(STATUS "PackageBuilder produced the expected package configuration.")
