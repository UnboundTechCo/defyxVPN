# Defyx VPN

A modern, relatively smart, secure, and open-source VPN application built with Flutter, providing free internet access and privacy protection with a fresh user experience.

![Cover](.github/images/cover.jpg)

## Features

- Simple, with a beautiful and user-friendly interface
- One-tap connect/disconnect functionality
- Powered by [DXcore](https://github.com/UnboundTechCo/DXcore), which unifies Warp, Psiphon, Warp-in-Warp, Xray, Outline, and exclusive proprietary protocols
- Relatively smart, requiring no manual configuration
- Ability to test internet speed and quality

## Download it

<a href="https://apps.apple.com/us/app/defyx/id6746811872?platform=iphone" target="_blank">
    <img height="60" src=".github/images/download/apple-store.png" alt="download" />
</a>
<a href="https://play.google.com/store/apps/details?id=de.unboundtech.defyxvpn" target="_blank">
    <img height="60" src=".github/images/download/google-play.png" alt="download" />
</a>
<a href="https://github.com/UnboundTechCo/defyxVPN/releases">
    <img height="60" src=".github/images/download/github.png" alt="download" />
</a>

## Installation

### Prerequisites

- Flutter SDK ≥ 3.7.0
- Dart SDK ≥ 3.0.0
- Xcode for iOS/macOS development

### 🧑‍💻 How to Set Up

1. Install dependencies:

```bash
flutter pub get
```

2. Run the application:

```bash
flutter run
```

3. Build for iOS:

```bash
make build-ios
```

This will:

- Clean the Flutter build
- Clean pub cache
- Build the IPA file

## Usage

1. Launch the app
2. Tap the connect button to secure your connection
3. Use the speed test feature to check your connection performance
4. Share the app with friends to spread internet freedom

## Technical Architecture

The app is built using:

- Flutter framework with Dart
- Riverpod for state management
- Native platform channels for VPN functionality
- Custom UI with Material Design components

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

For support or inquiries, please [create an issue](https://github.com/UnboundTechCo/defyxVPN/issues) or contact us at info@UnboundTechCo.de.

---

Made with ❤️ by the UnboundTechCo Team
