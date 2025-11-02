# DXcore Windows DLL Integration

This document describes how to build and integrate the DXcore Windows DLL with the DefyxVPN Flutter application.

## Prerequisites

- Go 1.19 or later (with CGO support)
- MinGW-w64 GCC compiler (for CGO on Windows)
- Flutter SDK
- Visual Studio 2019 or later (for Windows development)

## Building the DLL

### Step 1: Build DXcore.dll

From the `DXcore-private` directory, run the PowerShell build script:

```powershell
.\build_windows_dll.ps1
```

This will:
- Build `DXcore.dll` from the `DXcore/windows/dxcore_dll.go` source
- Generate the C header file `DXcore.h`
- Place both files in the `DXcore-private/out/` directory

**Manual Build (if needed):**

```powershell
cd DXcore-private\DXcore\windows
go build -buildmode=c-shared -o ..\..\out\DXcore.dll dxcore_dll.go
```

### Step 2: Build the Flutter Windows App

From the `defyxVPN` directory:

```powershell
flutter build windows
```

The CMakeLists.txt post-build step will automatically copy `DXcore.dll` from `DXcore-private/out/` to the output directory next to the `.exe`.

If the DLL is not found during build, you can manually copy it:

```powershell
copy ..\DXcore-private\out\DXcore.dll .\build\windows\runner\Release\DXcore.dll
```

## Architecture

### DXcore Go Bridge (`DXcore/windows/dxcore_dll.go`)

Exports C-compatible functions using CGO:
- `WinSetProgressListener` - Register progress callback
- `WinStop` - Stop VPN
- `WinMeasurePing` - Measure ping latency
- `WinGetFlag` - Get country flag
- `WinStartVPN` - Start VPN with config
- `WinStopVPN` - Stop VPN
- `WinSetAsnName` - Set ASN name
- `WinSetTimeZone` - Set timezone offset
- `WinGetFlowLine` - Get flow line config
- `WinFreeString` - Free Go-allocated strings

### Windows C++ Bridge (`windows/runner/dxcore_bridge.{h,cpp}`)

- Dynamically loads `DXcore.dll` at runtime
- Wraps exported functions with C++ API
- Handles string marshalling between C and C++
- Provides progress callback trampoline

### Flutter Method Channel (`windows/runner/flutter_window.cpp`)

Implements platform channels:
- **Method Channel**: `com.defyx.vpn`
  - Methods: `connect`, `disconnect`, `startVPN`, `stopVPN`, `calculatePing`, `getFlag`, `setTimezone`, `getFlowLine`, etc.
- **Event Channel**: `com.defyx.vpn_events`
  - Sends VPN status updates (connected/disconnected)
- **Event Channel**: `com.defyx.progress_events`
  - Sends real-time progress messages from DXcore

## Method Channel API

All methods mirror the Android/iOS implementations:

| Method | Arguments | Returns | Description |
|--------|-----------|---------|-------------|
| `connect` | - | `bool` | Connect VPN (stub on Windows) |
| `disconnect` | - | `bool` | Disconnect VPN |
| `startVPN` | `flowLine`, `pattern` | `bool` | Start VPN with config |
| `stopVPN` | - | `bool` | Stop VPN |
| `calculatePing` | - | `int` | Measure ping in ms |
| `getFlag` | - | `String` | Get country flag code |
| `getFlowLine` | `isTest` | `String` | Get flow line config |
| `setAsnName` | - | `void` | Set ASN name |
| `setTimezone` | `timezone` | `bool` | Set timezone offset |
| `setConnectionMethod` | `method` | `bool` | Set connection method (no-op) |
| `getVpnStatus` | - | `String` | Get current VPN status |
| `isTunnelRunning` | - | `bool` | Check if tunnel is running |

## Troubleshooting

### DLL Not Found

If the app fails to load `DXcore.dll`:
1. Verify the DLL exists in `DXcore-private/out/DXcore.dll`
2. Check that the DLL was copied to the same directory as the `.exe`
3. Ensure MinGW-w64 runtime DLLs are available (or statically linked)

### CGO Build Errors

If you encounter CGO build errors:
1. Ensure MinGW-w64 is installed and in PATH
2. Set environment variables:
   ```powershell
   $env:CGO_ENABLED = "1"
   $env:CC = "gcc"
   ```
3. Verify Go version supports CGO on Windows

### Missing Symbols

If you get "undefined reference" errors:
1. Rebuild the DLL with the build script
2. Ensure `//export` comments are present in Go code
3. Check that function names match in C++ loader

## Development Notes

- The Windows implementation uses a simplified status model (connected/disconnected)
- Cache directory defaults to `%LOCALAPPDATA%\DefyxVPN\cache`
- Progress callbacks are marshalled from Go to C++ via function pointer
- All string returns from Go must be freed with `WinFreeString`
