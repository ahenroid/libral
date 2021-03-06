include(leatherman)
get_commit_string(PROJECT_COMMIT)

# Generate a file containing the above version numbers.
configure_file("version.h.in" "${CMAKE_CURRENT_LIST_DIR}/inc/libral/version.h")

# Generate files for Doxygen
configure_file("Doxyfile.in"       "${CMAKE_CURRENT_LIST_DIR}/Doxyfile")
configure_file("namespaces.dox.in" "${CMAKE_CURRENT_LIST_DIR}/docs/namespaces.dox")

# Set C++ compile flags based on project settings.
set(CMAKE_CXX_FLAGS ${${PROJECT_NAME_UPPER}_CXX_FLAGS})

# Set prefix for logging messages.
leatherman_logging_namespace("ral")

# Setup compiling the library.
include_directories(
  inc
  ${PROJECT_BINARY_DIR}/inc
  ${AUGEAS_INCLUDE_DIRS}
  ${Boost_INCLUDE_DIRS}
  ${YAMLCPP_INCLUDE_DIRS}
  ${LEATHERMAN_INCLUDE_DIRS})

link_directories(
  ${Boost_LIBRARY_DIRS}
  ${YAMLCPP_LIBRARY_DIRS})

set(PROJECT_SOURCES "src/libral.cc" "src/augeas.cc" "src/ral.cc"
  "src/type.cc" "src/mount.cc" "src/provider.cc"
  "src/simple_provider.cc" "src/json_provider.cc"
  "src/user.cc" "src/value.cc" "src/file.cc"
  "src/prov/spec.cc" "src/attr/spec.cc"
  "src/command.cc")

## An object target is generated that can be used by both the library and test executable targets.
## Without the intermediate target, unexported symbols can't be tested.
add_library(libprojectsrc OBJECT ${PROJECT_SOURCES})
set_target_properties(libprojectsrc PROPERTIES POSITION_INDEPENDENT_CODE true)

add_library(libral $<TARGET_OBJECTS:libprojectsrc>)
set_target_properties(libral PROPERTIES VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
target_link_libraries(libral
  ${LEATHERMAN_LIBRARIES}
  ${YAMLCPP_LIBRARIES}
  ${Boost_LIBRARIES}
  ${AUGEAS_LIBRARIES}
)

symbol_exports(libral "${CMAKE_CURRENT_LIST_DIR}/inc/libral/export.h")

leatherman_install(libral)
install(DIRECTORY inc/libral DESTINATION include)

add_subdirectory(tests)
