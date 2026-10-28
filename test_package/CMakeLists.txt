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

# A two-executable sample whose component list leaves the game out, so the package carries the
# tool alone, with the tool's Start Menu links and not the game's. The package names no
# PRIMARY_TARGET, so the tool, its only packaged executable, is the primary one. conanfile.py checks
# that the configure does not warn about it, that the archive holds the tool and not the game, and
# that the tool's runtime dependencies install in Runtime while the game's stay in Game.
package_create(VENDOR "Test Vendor")

foreach(_name IN ITEMS game tool)
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/test-${_name}.desktop"
         "[Desktop Entry]\nType=Application\nName=Test ${_name}\nExec=test-${_name}\n")
endforeach()
package_add_executable(
    test_game
    main.cpp
    DISPLAY_NAME
    "Test Game"
    COMPONENT
    Game
    LINUX_DESKTOP_FILE
    "${CMAKE_CURRENT_BINARY_DIR}/test-game.desktop"
    MENU_LINKS
    "bin/game-guide.html"
    "Test Game Guide")
package_add_executable(
    test_tool
    main.cpp
    DISPLAY_NAME
    "Test Tool"
    COMPONENT
    Tool
    LINUX_DESKTOP_FILE
    "${CMAKE_CURRENT_BINARY_DIR}/test-tool.desktop"
    MENU_LINKS
    "bin/tool-guide.html"
    "Test Tool Guide")
set_target_properties(test_game PROPERTIES OUTPUT_NAME test-game)
set_target_properties(test_tool PROPERTIES OUTPUT_NAME test-tool)
set_property(
    TARGET test_tool
    APPEND
    PROPERTY PACKAGE_BUILDER_MENU_LINKS "https://example.com/tool" "Test Tool Website")

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
                     "Test Vendor\\Test Tool")
        _test_expect("registry key" "${CPACK_PACKAGE_INSTALL_REGISTRY_KEY}" "Test Tool")

        # Only the packaged tool gets a Start Menu entry, a desktop shortcut and its links; nothing
        # of the unlisted game's appears.
        _test_expect("executables" "${CPACK_PACKAGE_EXECUTABLES}" "test-tool;Test Tool")
        _test_expect(
            "menu links" "${CPACK_NSIS_MENU_LINKS}"
            "bin/tool-guide.html;Test Tool Guide;https://example.com/tool;Test Tool Website")
        set(_shortcuts "${CPACK_NSIS_CREATE_ICONS_EXTRA}")
        string(FIND "${_shortcuts}" "$DESKTOP\\Test Tool.lnk" _found)
        if(_found EQUAL -1)
            message(FATAL_ERROR "the tool has no desktop shortcut:\n${_shortcuts}")
        endif()
        string(TOLOWER "${_shortcuts}" _shortcuts_lower)
        if(_shortcuts_lower MATCHES "game")
            message(FATAL_ERROR "shortcuts name the unlisted game:\n${_shortcuts}")
        endif()
    endif()
endfunction()
_test_package_configuration()

message(STATUS "PackageBuilder produced the expected package configuration.")
