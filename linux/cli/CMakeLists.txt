cmake_minimum_required(VERSION 3.13)
project(defyxvpn_cli LANGUAGES C CXX)

include(CTest)
include(GNUInstallDirs)

find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)
pkg_check_modules(JSON_C REQUIRED IMPORTED_TARGET json-c)

set(DEFYX_DXCORE_LIB "" CACHE FILEPATH
    "Path to the production or mock libdxcore_amd64.so")
if(NOT DEFYX_DXCORE_LIB AND DEFINED ENV{DEFYX_DXCORE_LIB})
  set(DEFYX_DXCORE_LIB "$ENV{DEFYX_DXCORE_LIB}")
endif()

set(DEFYX_CLI_VERSION "dev")
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/../../pubspec.yaml"
     _pubspec_version_line REGEX "^version:[ \t]*" LIMIT_COUNT 1)
if(_pubspec_version_line)
  string(REGEX REPLACE "^version:[ \t]*([^+ \t]+).*$" "\\1"
         DEFYX_CLI_VERSION "${_pubspec_version_line}")
endif()

function(defyx_cli_compile_settings target)
  target_compile_features(${target} PUBLIC cxx_std_17)
  target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
  target_compile_definitions(
    ${target} PRIVATE DEFYX_CLI_VERSION="${DEFYX_CLI_VERSION}")
endfunction()

add_library(defyx_cli_support STATIC
  src/cli_options.cpp
  src/flowline.cpp
  src/progress.cpp
  src/status_file.cpp
  src/tcp_forwarder.cpp
)
defyx_cli_compile_settings(defyx_cli_support)
target_include_directories(defyx_cli_support PUBLIC "${CMAKE_CURRENT_LIST_DIR}/src")
target_link_libraries(defyx_cli_support PUBLIC PkgConfig::JSON_C Threads::Threads)

add_library(defyx_native_core STATIC
  "${CMAKE_CURRENT_LIST_DIR}/../runner/defyx_core.cpp"
)
defyx_cli_compile_settings(defyx_native_core)
target_include_directories(
  defyx_native_core PUBLIC "${CMAKE_CURRENT_LIST_DIR}/../runner")
target_link_libraries(
  defyx_native_core PUBLIC ${CMAKE_DL_LIBS} Threads::Threads)

add_executable(defyxvpn-cli src/main.cpp)
defyx_cli_compile_settings(defyxvpn-cli)
target_link_libraries(
  defyxvpn-cli PRIVATE defyx_cli_support defyx_native_core)
set_target_properties(
  defyxvpn-cli PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(DEFYX_DXCORE_LIB)
  get_filename_component(_dxcore_library "${DEFYX_DXCORE_LIB}" ABSOLUTE)
  if(NOT EXISTS "${_dxcore_library}")
    message(FATAL_ERROR "DEFYX_DXCORE_LIB does not exist: ${_dxcore_library}")
  endif()

  add_custom_command(
    TARGET defyxvpn-cli POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${_dxcore_library}"
            "$<TARGET_FILE_DIR:defyxvpn-cli>/libdxcore_amd64.so"
    COMMENT "Copying DXcore beside defyxvpn-cli"
  )
  install(FILES "${_dxcore_library}"
          DESTINATION "${CMAKE_INSTALL_BINDIR}"
          RENAME "libdxcore_amd64.so")
endif()

install(TARGETS defyxvpn-cli RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES README.md defyxvpn-cli.env.example
        DESTINATION "${CMAKE_INSTALL_DOCDIR}")
install(FILES defyxvpn-cli.service
        DESTINATION "${CMAKE_INSTALL_DOCDIR}/systemd")

if(BUILD_TESTING)
  add_executable(defyxvpn-cli-tests tests/cli_tests.cpp)
  defyx_cli_compile_settings(defyxvpn-cli-tests)
  target_link_libraries(defyxvpn-cli-tests PRIVATE defyx_cli_support)
  add_test(NAME defyxvpn-cli-tests COMMAND defyxvpn-cli-tests)
  set_tests_properties(defyxvpn-cli-tests PROPERTIES TIMEOUT 15)

  add_library(dxcore_mock SHARED tests/mock_dxcore.c)
  set_target_properties(
    dxcore_mock PROPERTIES
    OUTPUT_NAME "dxcore_amd64"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/test"
  )
  add_test(
    NAME defyxvpn-cli-integration
    COMMAND bash
            "${CMAKE_CURRENT_LIST_DIR}/tests/integration_test.sh"
            "$<TARGET_FILE:defyxvpn-cli>"
            "$<TARGET_FILE:dxcore_mock>"
  )
  set_tests_properties(defyxvpn-cli-integration PROPERTIES TIMEOUT 15)
endif()
