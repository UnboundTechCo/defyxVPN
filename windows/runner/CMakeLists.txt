cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "dxcore_bridge.cpp"
  "registry_manager.cpp"
  "vpn_channel_handler.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "system_tray.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "bcrypt.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Optional: Copy DXcore.dll next to the built executable if present
# Use a path relative to this CMakeLists directory to avoid ambiguity.
set(DXCORE_DLL_PATH "${CMAKE_CURRENT_LIST_DIR}/DXcore.dll")
if (EXISTS "${DXCORE_DLL_PATH}")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${DXCORE_DLL_PATH}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/DXcore.dll"
  )
else()
  message(WARNING "DXcore.dll not found at ${DXCORE_DLL_PATH}; skipping copy. Build the DLL first.")
endif()

# Embed Windows gateway key from WINDOWS_KEY.txt into a generated header
set(GATEWAY_KEY_FILE "${CMAKE_CURRENT_LIST_DIR}/WINDOWS_KEY.txt")
if(EXISTS "${GATEWAY_KEY_FILE}")
  file(READ "${GATEWAY_KEY_FILE}" _GATEWAY_KEY_RAW)
  string(REGEX REPLACE "[ \t\r\n]+" "" WINDOWS_GATEWAY_KEY_STRIPPED "${_GATEWAY_KEY_RAW}")
  configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/windows_key_generated.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/windows_key_generated.h"
    @ONLY
  )
else()
  message(WARNING "WINDOWS_KEY.txt not found; gateway key will be empty.")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/windows_key_generated.h"
    "#pragma once\nstatic const char kWindowsGatewayKey[] = \"\";\n")
endif()
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
