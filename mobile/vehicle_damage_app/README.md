# Vehicle Damage App — Flutter Frontend

Cross-platform Flutter client for the Intelligent Vehicle Damage Assessment system. Runs on **Web, iOS, macOS, and Android**.

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| **Home** | Upload image/video or take a photo. Shows live backend connection status. |
| **Results** | Annotated damage image, severity badge, detected damages list, AUD cost breakdown, and recommended actions. |
| **Ask AI** | Chat with a local Qwen LLM about your specific assessment. Full conversation history persisted to PostgreSQL. |
| **History** | Browse past assessments with severity colour-coding, damage types, and cost summary. Tap for detailed view. |
| **Settings** | Configure confidence threshold, currency, and backend URL. |

---

## 🚀 Quick Start

### Prerequisites

- [Flutter 3.x](https://flutter.dev/docs/get-started/install)
- Backend API running on `http://127.0.0.1:8000` (see root `README.md`)

### Run in browser (Chrome)

```bash
flutter pub get
flutter run -d chrome
```

### Build and serve as static web app

```bash
flutter build web --release
cd build/web
python3 -m http.server 8080
# Open http://localhost:8080
```

---

## 📡 Backend API URL

The app reads the backend URL from `--dart-define` at build/run time. Default is `http://127.0.0.1:8000`.

```bash
# iOS Simulator (uses host machine's localhost)
flutter run -d ios

# Physical iPhone on same WiFi
flutter run -d <device_id> --release \
  --dart-define=API_BASE_URL=http://192.168.0.48:8000

# Production build
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                         # App entry point + providers
├── models/
│   └── damage_models.dart            # All Dart data classes
├── screens/
│   ├── home_screen.dart              # Upload / capture entry point
│   ├── results_screen.dart           # Detection + cost results
│   ├── chat_screen.dart              # AI assistant chat UI
│   ├── history_screen.dart           # Past assessments viewer
│   └── settings_screen.dart         # User preferences
├── services/
│   ├── api_service.dart              # All HTTP calls to FastAPI
│   ├── assessment_state.dart         # ChangeNotifier state
│   └── theme_provider.dart           # Dark/light mode toggle
└── theme/                            # App colour scheme + typography
```

---

## 🤖 AI Chat Feature

After every analysis, an **"Ask AI"** button appears in the bottom-right corner of the Results screen. Tapping it opens a chat interface where you can ask questions about your specific assessment:

- *"Is this windshield crack safe to drive with?"*
- *"What's the cheapest way to fix the dents?"*
- *"Should I claim this on insurance?"*

The AI has full context of your detection results and cost estimates. All conversations are stored in PostgreSQL so history persists across sessions.

> **Requires:** Ollama running locally with `ollama run qwen2.5`

---

## 🍎 iOS Deployment

### Simulator (no code signing required)

```bash
flutter clean && flutter pub get
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
flutter run -d "iPhone 17 Pro"
```

### Physical Device

1. Open `ios/Runner.xcworkspace` in Xcode
2. **Runner target** → **Signing & Capabilities** → select your Team
3. Change Bundle ID to something unique (e.g. `com.yourname.vehicleDamageApp`)
4. Enable **Developer Mode** on iPhone: Settings → Privacy & Security → Developer Mode
5. Connect iPhone and run:

```bash
flutter run -d <device_id> --release \
  --dart-define=API_BASE_URL=http://<mac-lan-ip>:8000
```

> **Tip:** If your project is in OneDrive/cloud storage, copy it to a local folder first to avoid code signing issues with extended attributes:
> ```bash
> rsync -av --exclude='build' --exclude='Pods' . /tmp/vehicle_damage_app/
> cd /tmp/vehicle_damage_app && xattr -rc .
> ```

### TestFlight / App Store

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com
```
Then upload the `.ipa` via Xcode Organizer → App Store Connect.

---

## 🔧 Troubleshooting

**iOS Simulator can't reach the backend:**
- Ensure backend binds to `0.0.0.0:8000`, not `127.0.0.1`
- Simulator routes `127.0.0.1` to the host Mac — this is correct behaviour

**Physical device can't reach the backend:**
- Use your Mac's LAN IP: `ipconfig getifaddr en0`
- Both Mac and iPhone must be on the same WiFi
- Check macOS Firewall: System Settings → Network → Firewall

**"Ask AI" button not appearing:**
- The button shows only after the Report is generated
- Check the browser console for errors (`Cmd+Option+J`)
- Ensure PostgreSQL and the FastAPI backend are running

**CocoaPods issues:**
```bash
sudo gem install cocoapods
cd ios && pod repo update && pod install
```

---

## 📄 Related

- [Root README](../../README.md) — Full system setup including backend, database, and Ollama
- [Backend API Docs](http://localhost:8000/docs) — Interactive Swagger UI (when backend is running)
