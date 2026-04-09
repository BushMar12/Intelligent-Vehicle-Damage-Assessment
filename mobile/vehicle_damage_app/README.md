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

Update the API base URL in `lib/services/api_service.dart` as needed for your environment:

- Local backend default: `http://127.0.0.1:8000`
- For physical devices: use your machine LAN IP instead of localhost
