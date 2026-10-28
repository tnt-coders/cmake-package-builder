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
# no Start Menu entry or desktop shortcut. conanfile.py checks that the configure warns about
# neither, that the archive holds the app, the tool and the MSVC C++ runtime and not the game, and
# that the app's and tool's runtime dependencies install in Runtime while the game's stay in Game.
package_create(
    VENDOR
    "Test Vendor"
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

set(PACKAGE_BUILDER_CPACK_COMPONENTS Runtime Tool)
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
    _test_expect("components" "${CPACK_COMPONENTS_ALL}" "Runtime;Tool")
    _test_expect("Runtime required" "${CPACK_COMPONENT_RUNTIME_REQUIRED}" "TRUE")
    _test_expect("file name" "${CPACK_PACKAGE_FILE_NAME}"
                 "PackageBuilderTest-1.0.0-${CPACK_SYSTEM_NAME}")
    _test_expect("vendor" "${CPACK_PACKAGE_VENDOR}" "Test Vendor")
    if(WIN32)
        _test_expect("install directory" "${CPACK_PACKAGE_INSTALL_DIRECTORY}"
                     "Test Vendor\\Test App")
        _test_expect("registry key" "${CPACK_PACKAGE_INSTALL_REGISTRY_KEY}" "Test App")

        # Only the GUI app gets a Start Menu entry: the console tool gets none, and nothing of the
        # unlisted game's appears. The package's links join the app's entry.
        _test_expect("executables" "${CPACK_PACKAGE_EXECUTABLES}" "test-app;Test App")
        _test_expect("menu links" "${CPACK_NSIS_MENU_LINKS}"
                     "bin/guide.html;Test Guide;https://example.com/tool;Test Tool Website")

        # The uninstaller removes the vendor folder it created once it is empty.
        string(FIND "${CPACK_NSIS_DELETE_ICONS_EXTRA}" "RMDir \"$INSTDIR\\..\"" _found)
        if(_found EQUAL -1)
            message(FATAL_ERROR "the uninstaller keeps the vendor folder:\n"
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
    endif()
endfunction()
_test_package_configuration()

message(STATUS "PackageBuilder produced the expected package configuration.")
