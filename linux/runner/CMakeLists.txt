cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "defyx_core.cpp"
  "defyx_linux_plugin.cc"
  "proxy_manager.cpp"
  "settings_manager.cpp"
  "system_tray.cpp"
  "vpn_channel_handler.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
find_package(Threads REQUIRED)

# Find AppIndicator library for system tray
find_package(PkgConfig REQUIRED)
pkg_check_modules(APPINDICATOR REQUIRED ayatana-appindicator3-0.1)

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${BINARY_NAME} PRIVATE dl)
target_link_libraries(${BINARY_NAME} PRIVATE Threads::Threads)
target_link_libraries(${BINARY_NAME} PRIVATE ${APPINDICATOR_LIBRARIES})

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE ${APPINDICATOR_INCLUDE_DIRS})

target_compile_options(${BINARY_NAME} PRIVATE ${APPINDICATOR_CFLAGS_OTHER})

# --- DXcore native library build and packaging --------------------------------

# Allow overriding the DXcore source directory and built library via env vars.
if(NOT DEFYX_DXCORE_DIR AND DEFINED ENV{DEFYX_DXCORE_DIR})
  set(DEFYX_DXCORE_DIR "$ENV{DEFYX_DXCORE_DIR}")
endif()

if(NOT DEFYX_DXCORE_LIB AND DEFINED ENV{DEFYX_DXCORE_LIB})
  set(DEFYX_DXCORE_LIB "$ENV{DEFYX_DXCORE_LIB}")
endif()

get_filename_component(_runner_dir "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)

set(_dxcore_source_candidates "")

if(DEFYX_DXCORE_LIB)
  get_filename_component(_override_lib "${DEFYX_DXCORE_LIB}" ABSOLUTE)
  list(APPEND _dxcore_source_candidates "${_override_lib}")
endif()

set(_runner_local_lib "${_runner_dir}/libDXcore.so")
list(APPEND _dxcore_source_candidates "${_runner_local_lib}")

if(DEFYX_DXCORE_DIR)
  get_filename_component(_dxcore_root "${DEFYX_DXCORE_DIR}" ABSOLUTE)
else()
  get_filename_component(_dxcore_root "${_runner_dir}/../../../DXcore-private" ABSOLUTE)
endif()

set(_dxcore_repo_lib "${_dxcore_root}/libDXcore.so")
list(APPEND _dxcore_source_candidates "${_dxcore_repo_lib}")

set(_dxcore_source "")

foreach(candidate IN LISTS _dxcore_source_candidates)
  if(EXISTS "${candidate}")
    set(_dxcore_source "${candidate}")
    break()
  endif()
endforeach()

set(_have_dxcore_lib FALSE)

find_program(GO_EXECUTABLE go)

if(NOT _dxcore_source AND GO_EXECUTABLE AND EXISTS "${_dxcore_root}")
  set(_dxcore_source "${_dxcore_repo_lib}")
  add_custom_target(dxcore_shared_lib
    COMMAND ${CMAKE_COMMAND} -E env GO111MODULE=on ${GO_EXECUTABLE} build -buildmode=c-shared -o "${_dxcore_source}" ./DXcore/linux
    WORKING_DIRECTORY "${_dxcore_root}"
    COMMENT "Building libDXcore.so via Go"
    VERBATIM
  )
  add_dependencies(${BINARY_NAME} dxcore_shared_lib)
elseif(NOT _dxcore_source)
  if(NOT GO_EXECUTABLE)
    message(WARNING "Go executable not found; libDXcore.so will not be rebuilt automatically.")
  elseif(NOT EXISTS "${_dxcore_root}")
    message(WARNING "DXcore source directory '${_dxcore_root}' is missing; libDXcore.so cannot be rebuilt.")
  endif()
endif()

if(_dxcore_source)
  set(_have_dxcore_lib TRUE)
endif()

if(_have_dxcore_lib)
  set(DEFYX_DXCORE_LIB_SOURCE "${_dxcore_source}" PARENT_SCOPE)
  set(DEFYX_DXCORE_LIB_NAME "libDXcore.so" PARENT_SCOPE)
endif()

if(NOT PROJECT_BUILD_DIR)
  set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/")
endif()

set(_bundle_config "${CMAKE_BUILD_TYPE}")

if("${_bundle_config}" STREQUAL "")
  set(_bundle_config "Debug")
endif()

string(TOLOWER "${_bundle_config}" _bundle_config_lower)
set(_bundle_dir "${PROJECT_BUILD_DIR}linux/x64/${_bundle_config_lower}/bundle")

if(_have_dxcore_lib)
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_bundle_dir}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dxcore_source}" "${_bundle_dir}/libDXcore.so"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_bundle_dir}/lib"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dxcore_source}" "${_bundle_dir}/lib/libDXcore.so"
    COMMENT "Copying libDXcore.so into Flutter Linux bundle (${_bundle_config_lower})"
  )
else()
  message(WARNING "libDXcore.so not found and cannot be built; VPN core will be unavailable in the Linux build.")
endif()
