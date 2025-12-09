# Linux Dependencies

## Required Packages

Install the following packages before building the Flutter Linux app:

```bash
sudo apt update && sudo apt install -y \
    libayatana-appindicator3-dev \
    libgtk-3-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    libsecret-1-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang
```

## Package Details

| Package | Purpose |
|---------|---------|
| `libayatana-appindicator3-dev` | System tray support |
| `libgtk-3-dev` | GTK 3 UI framework |
| `libgstreamer1.0-dev` | GStreamer core (audio playback) |
| `libgstreamer-plugins-base1.0-dev` | GStreamer base plugins |
| `gstreamer1.0-plugins-good` | GStreamer good codecs |
| `gstreamer1.0-plugins-bad` | GStreamer additional codecs |
| `gstreamer1.0-plugins-ugly` | GStreamer patent-encumbered codecs |
| `libsecret-1-dev` | Secure storage (flutter_secure_storage) |
| `pkg-config` | Build configuration tool |
| `cmake` | Build system |
| `ninja-build` | Fast build tool |
| `clang` | C/C++ compiler |

## Build & Run

```bash
flutter clean
flutter pub get
flutter run -d linux
```
