# CPack project configuration file (CPACK_PROJECT_CONFIG_FILE), which package_install() names. CPack
# includes it once per generator, after setting CPACK_GENERATOR to the generator being run.
#
# package_install() runs the archive generators in component mode, so that they honour
# CPACK_COMPONENTS_ALL. An archive built in component mode leaves out its top-level directory
# (CPACK_PACKAGE_FILE_NAME) unless CPACK_COMPONENT_INCLUDE_TOPLEVEL_DIRECTORY is ON, and that
# setting nests the staged tree of every component-mode generator, NSIS included. It is therefore
# turned on here for the archive generators alone, which keeps their layout.
if(CPACK_GENERATOR MATCHES "^(7Z|TBZ2|TGZ|TXZ|TZ|TZST|ZIP)$")
    set(CPACK_COMPONENT_INCLUDE_TOPLEVEL_DIRECTORY ON)
endif()
