# Defines how cmake should behave, and the minimum version necessary to build.
cmake_minimum_required(VERSION 3.2.2)

# Project Setup - modify to match project naming
## Source code for a simple command-line executable for a dynamic library will be generated from the project name.
## The command-line and library names will be based off the project name.
project(libral VERSION 0.0.1)

# Whether to build a static executable. Only works with pl-build-tools for
# now since Fedora is missing augeas-static, icu-static, and yaml-cpp-static
option(LIBRAL_STATIC "Build a static executable")

# The default data dir. Providers should be placed into
set(LIBRAL_DATA_DIR "${CMAKE_INSTALL_PREFIX}/share/libral/data" CACHE STRING "where to look for providers etc. by default")

string(MAKE_C_IDENTIFIER ${PROJECT_NAME} PROJECT_C_NAME)
string(TOUPPER ${PROJECT_C_NAME} PROJECT_NAME_UPPER)
string(TOLOWER ${PROJECT_C_NAME} PROJECT_NAME_LOWER)

# Common cmake setup
if (NOT CMAKE_BUILD_TYPE)
    message(STATUS "Defaulting to a release build.")
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

enable_testing()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

option(YAMLCPP_STATIC "Use yaml-cpp's static libraries" ${LIBRAL_STATIC})
find_package(YAMLCPP REQUIRED)

# Leatherman setup
SET(LEATHERMAN_COMPONENTS locale catch nowide logging execution json_container)
SET(BOOST_STATIC ${LIBRAL_STATIC})
find_package(Leatherman REQUIRED COMPONENTS ${LEATHERMAN_COMPONENTS})

# Now that we have leatherman, we can pull in its options file, which
# we need for finding all our other libraries.
include(options)
## Pull in common cflags setting from leatherman. Don't override CMAKE_CXX_FLAGS at the project root to avoid impacting 3rd party code.
include(cflags)
set(${PROJECT_NAME_UPPER}_CXX_FLAGS "${LEATHERMAN_CXX_FLAGS}")
add_definitions(${LEATHERMAN_DEFINITIONS})
## Pull in helper macros for working with leatherman libraries
include(leatherman)

# Add other dependencies
set(Boost_USE_STATIC_LIBS ${LIBRAL_STATIC})
find_package(Boost 1.54 REQUIRED COMPONENTS program_options)

set(AUGEAS_STATIC ${LIBRAL_STATIC})
find_package(Augeas REQUIRED)
add_definitions(${AUGEAS_DEFINITIONS})

# Display a summary of the features
include(FeatureSummary)
feature_summary(WHAT ALL)

add_subdirectory(lib)
add_subdirectory(exe)

configure_file("${PROJECT_SOURCE_DIR}/config.hpp.in"
               "${PROJECT_BINARY_DIR}/inc/config.hpp")
include_directories(${PROJECT_BINARY_DIR}/inc)

# Add cpplint and cppcheck targets
file(GLOB_RECURSE ALL_SOURCES lib/src/**/*.cc lib/inc/*.hpp exe/*.cc)
add_cpplint_files(${ALL_SOURCES})
enable_cpplint()

add_cppcheck_dirs("${PROJECT_SOURCE_DIR}/lib" "${PROJECT_SOURCE_DIR}/exe")
enable_cppcheck()

# This will be used to install all data:
file(GLOB_RECURSE ALL_LENSES "${CMAKE_SOURCE_DIR}/data/lenses/*.aug")
file(GLOB_RECURSE ALL_PROVIDERS "${CMAKE_SOURCE_DIR}/data/providers/*.prov")

install(FILES ${ALL_LENSES} DESTINATION "${LIBRAL_DATA_DIR}/lenses/")
install(PROGRAMS ${ALL_PROVIDERS} DESTINATION "${LIBRAL_DATA_DIR}/providers/")
