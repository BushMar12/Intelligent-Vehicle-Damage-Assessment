# Vehicle Damage App

Flutter client for the Vehicle Damage Assessment system.

## Features

- Capture/select vehicle images
- Upload videos for frame-based analysis
- View detected damages with confidence and severity
- Request AUD repair cost estimation
- Generate assessment summaries

## Requirements

- Flutter 3.x
- Dart SDK compatible with the version in `pubspec.yaml`
- Backend API running from `backend/`

## Development

```bash
flutter pub get
flutter run -d chrome
```

## Build Web

```bash
flutter build web --release
cd build/web
python -m http.server 8080
```

Open http://localhost:8080 after starting the local server.

## Backend API Base URL

Set the backend URL at build/run time with `--dart-define`:

- Local backend default (simulator): `http://127.0.0.1:8000`
- Physical device example: `http://192.168.1.50:8000`
- Production example: `https://api.yourdomain.com`

Examples:

```bash
flutter run -d ios --dart-define=API_BASE_URL=http://192.168.1.50:8000
flutter build ipa --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

## Deploy to iPhone

Important: iOS builds require macOS + Xcode. You cannot produce a signed iPhone IPA directly on Windows.

### 1. Prepare on macOS

```bash
cd mobile/vehicle_damage_app
flutter clean
flutter pub get
flutter doctor
```

### 2. Configure iOS signing in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select Runner target -> Signing & Capabilities.
3. Choose your Apple Developer Team.
4. Replace bundle identifier `com.example.vehicleDamageApp` with your own unique ID.
5. Connect your iPhone, trust developer cert, and enable Developer Mode on device.

### 3. Run on physical iPhone (development)

```bash
flutter devices
flutter run -d <iphone_device_id> --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
```

### 4. Build for TestFlight / App Store

1. Update app version in `pubspec.yaml` (`version: x.y.z+build`).
2. Build archive from Flutter:

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

3. In Xcode Organizer, upload the archive to App Store Connect.
4. In App Store Connect -> TestFlight, add internal/external testers.

### 5. Production backend requirements

- Prefer HTTPS backend for App Store release.
- If you use a local/LAN HTTP backend for development, keep that for debug/testing only.
- Ensure backend CORS and firewall allow requests from iPhone network.
