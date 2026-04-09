# Intelligent Vehicle Damage Assessment Using Deep Learning

An end-to-end deep learning system for automatic vehicle damage detection and assessment, featuring model comparison, cost estimation in AUD, and web/mobile deployment.

## Overview

This project implements a complete vehicle damage assessment pipeline that:
- Detects 6 types of vehicle damage using state-of-the-art object detection models
- Supports both **images and videos** for damage detection
- Compares YOLO11m, YOLOv8m, Faster R-CNN, and RT-DETR
- Provides repair cost estimation in **AUD** (Australian market rates) with 10% GST
- Generates AI-powered assessment reports
- Deploys as a Flutter web/mobile application with FastAPI backend

## Project Structure

```
vehicle_damage_assessment/
├── notebooks/
│   └── model_comparison.ipynb      # Training & evaluation notebook
├── backend/
│   ├── app/
│   │   ├── main.py                 # FastAPI application
│   │   ├── config.py               # Configuration (AUD pricing)
│   │   ├── models/                 # Model inference wrappers
│   │   ├── routers/                # API endpoints
│   │   │   ├── damage.py           # Image & video detection
│   │   │   ├── cost.py             # Cost estimation
│   │   │   └── report.py           # Report generation
│   │   ├── schemas/                # Pydantic models
│   │   └── utils/                  # Utility functions
│   ├── .env                        # Environment configuration
│   ├── requirements.txt
│   └── Dockerfile
├── mobile/
│   └── vehicle_damage_app/         # Flutter web/mobile application
│       ├── lib/
│       │   ├── screens/            # UI screens
│       │   ├── services/           # API services
│       │   ├── models/             # Data models
│       │   └── theme/              # App theming
├── data/
│   └── CarDD/                      # CarDD Dataset
├── models/                         # Trained model weights
│   ├── yolov8m_best.pt            # YOLOv8m trained weights
│   └── yolo11m_best.pt            # YOLO11m trained weights
└── configs/
    └── training_config.yaml        # Training configuration
```

## Damage Categories

| ID | Category | Description | Base Cost (AUD) |
|----|----------|-------------|-----------------|
| 0 | Dent | Body panel deformation | $350 |
| 1 | Scratch | Surface paint damage | $250 |
| 2 | Crack | Structural cracks | $450 |
| 3 | Glass Shatter | Window/windshield damage | $650 |
| 4 | Lamp Broken | Headlight/taillight damage | $400 |
| 5 | Tire Flat | Tire damage/deflation | $250 |

*Costs are multiplied by severity (small: 1x, medium: 2x, large: 3.5x) plus labor and parts*

## Installation

### Prerequisites
- Python 3.9+
- CUDA 11.8+ (for NVIDIA GPU) or Apple Silicon Mac (for MPS)
- Flutter 3.x (for web/mobile development)

### Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Configure Model Path

Edit `backend/.env`:
```env
MODEL_PATH=../models/yolov8m_best.pt
MODEL_TYPE=yolov8
CONF_THRESHOLD=0.25
IOU_THRESHOLD=0.45
```

### Run Backend Server

```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Backend API docs: http://localhost:8000/docs

### Flutter App Setup

#### Web App

```bash
cd mobile/vehicle_damage_app

# Install dependencies
flutter pub get

# Build for web
flutter build web --release

# Serve the web app
cd build/web
python3 -m http.server 8080
```

Web app: http://localhost:8080

#### iOS App (macOS only)

**Prerequisites:**
- macOS with Xcode installed
- CocoaPods (`sudo gem install cocoapods`)
- Apple Developer account (for physical device deployment)

**Build for iOS Simulator (No Code Signing):**

```bash
cd mobile/vehicle_damage_app

# Clean and install dependencies
flutter clean
flutter pub get

# Install iOS CocoaPods (clean install recommended)
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Build with xcodebuild (no code signing required for simulator)
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean build

# Install and launch on simulator
xcrun simctl install "iPhone 17" \
  ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl launch "iPhone 17" com.example.vehicleDamageApp
open -a Simulator
```

**Alternative (requires code signing setup):**
```bash
flutter run -d ios
```

**For Physical Device Deployment:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities**
3. Enable **"Automatically manage signing"**
4. Select your **Team** (Apple Developer account)
5. Update **Bundle Identifier** to a unique ID (e.g., `com.yourname.vehicleDamageApp`)
6. Connect your iPhone and run:

```bash
flutter run -d <device_id> --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
```

**Build for TestFlight/App Store:**

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Then upload via Xcode Organizer to App Store Connect.

## Model Comparison

The notebook trains and evaluates four models:

| Model | Architecture | Size | Best For |
|-------|-------------|------|----------|
| YOLO11m | YOLO v11 Medium | 41MB | Latest improvements |
| YOLOv8m | YOLO v8 Medium | 52MB | Balanced speed/accuracy |
| Faster R-CNN | ResNet50-FPN v2 | Larger | Strong two-stage baseline |
| RT-DETR | Transformer detector | Larger | End-to-end transformer baseline |

## API Endpoints

### Image Detection: `POST /damage/predict`

```bash
curl -X POST "http://localhost:8000/damage/predict" \
  -F "file=@damaged_car.jpg"
```

### Video Detection: `POST /damage/predict/video`

```bash
curl -X POST "http://localhost:8000/damage/predict/video?frame_interval=30&max_frames=50" \
  -F "file=@damage_video.mp4"
```

**Parameters:**
- `frame_interval`: Process every Nth frame (default: 30)
- `max_frames`: Maximum frames to analyze (default: 50)

### Cost Estimation: `POST /cost/predict`

Returns itemized cost breakdown with:
- Base repair cost per damage type
- Labor costs ($120/hour AUD)
- Parts costs
- GST (10%)
- Estimate range (±20%)

### Report Generation: `POST /report/generate`

Generates AI-powered assessment report with:
- Overall severity rating
- Primary concerns
- Recommended actions
- Safety notes

## Cost Estimation (AUD)

| Component | Rate |
|-----------|------|
| Labor | $120/hour |
| GST | 10% |
| Severity Multiplier (Small) | 1.0x |
| Severity Multiplier (Medium) | 2.0x |
| Severity Multiplier (Large) | 3.5x |

## App Features

- 📷 **Camera capture** for real-time damage assessment
- 🖼️ **Gallery upload** for existing images
- 🎥 **Video upload** for comprehensive vehicle scan
- 🔍 **Damage visualization** with annotated bounding boxes
- 💵 **Cost estimation** in AUD with GST breakdown
- 📊 **Key frame viewer** for video analysis results
- 📄 **Assessment reports** with severity ratings

### Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Web | ✅ Supported | Chrome, Firefox, Safari, Edge |
| iOS | ✅ Supported | Requires macOS + Xcode for building |
| macOS | ✅ Supported | Native desktop app |
| Android | 🔧 Configured | Requires Android Studio setup |

## Quick Start

### Option 1: Web App (Quickest)

```bash
# Terminal 1: Start backend
cd backend && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Serve frontend
cd mobile/vehicle_damage_app/build/web
python3 -m http.server 8080
```

Then open http://localhost:8080 in your browser.

### Option 2: iOS Simulator (macOS)

```bash
# Terminal 1: Start backend
cd backend && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Build and run iOS app
cd mobile/vehicle_damage_app
flutter clean
flutter pub get
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Build for simulator (no code signing required)
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean build

# Install and launch on simulator
xcrun simctl install "iPhone 17" \
  ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl launch "iPhone 17" com.example.vehicleDamageApp
open -a Simulator
```

**Alternative (if code signing is configured):**
```bash
cd mobile/vehicle_damage_app
flutter run -d ios
```

### Option 3: Physical iPhone

**Prerequisites:**
- Code signing configured in Xcode (see iOS App Setup above)
- iPhone and Mac on the same WiFi network
- Developer Mode enabled on iPhone (Settings → Privacy & Security → Developer Mode)

```bash
# Step 1: Get your Mac's LAN IP
ipconfig getifaddr en0
# Example output: 192.168.0.48

# Step 2: Start backend (accessible on network)
cd backend && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Step 3: List connected devices
flutter devices
# Find your iPhone's device ID (e.g., 00008120-XXXX)

# Step 4: Build and run on iPhone (RELEASE mode required for home screen launch)
cd mobile/vehicle_damage_app
flutter run -d <device_id> --release --dart-define=API_BASE_URL=http://<lan-ip>:8000

# Example:
flutter run -d 00008120-0019450201B9A01E --release --dart-define=API_BASE_URL=http://192.168.0.48:8000
```

**Important Notes:**
- Use `--release` mode to launch from home screen (debug mode only works via Xcode/Flutter)
- First launch requires trusting the developer certificate: Settings → General → VPN & Device Management → Trust
- If project is in OneDrive/cloud storage, copy to local folder first to avoid code signing issues:
  ```bash
  rsync -av --exclude='build' --exclude='Pods' mobile/vehicle_damage_app /tmp/
  cd /tmp/vehicle_damage_app
  flutter run -d <device_id> --release --dart-define=API_BASE_URL=http://<lan-ip>:8000
  ```

## Configuration

### Environment Variables (`backend/.env`)

```env
MODEL_PATH=../models/yolov8m_best.pt
MODEL_TYPE=yolov8          # yolo, yolov8, yolo11, faster_rcnn, rtdetr
CONF_THRESHOLD=0.25
IOU_THRESHOLD=0.45
```

### Switch Models

```bash
# Use YOLOv8
MODEL_PATH=../models/yolov8m_best.pt
MODEL_TYPE=yolov8

# Use YOLO11
MODEL_PATH=../models/yolo11m_best.pt
MODEL_TYPE=yolo11

# Use RT-DETR
MODEL_PATH=../models/rtdetr_best.pt
MODEL_TYPE=rtdetr
```

## Troubleshooting

### iOS Build Issues

**Code signing errors on simulator:**
```bash
# Use xcodebuild with CODE_SIGNING_ALLOWED=NO instead of flutter run
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean build
```

**Stale build files:**
```bash
cd mobile/vehicle_damage_app
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
```

**CocoaPods issues:**
```bash
sudo gem install cocoapods
cd ios && pod repo update && pod install
```

### Backend Connection Issues

**iOS Simulator can't reach localhost:**
- Ensure backend is running on `0.0.0.0:8000` (not `127.0.0.1`)
- iOS Simulator uses `127.0.0.1` to reach host machine

**Physical device can't reach backend:**
- Use your Mac's LAN IP (e.g., `192.168.0.48`)
- Ensure both iPhone and Mac are on the same WiFi network
- Check firewall: `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`
- Verify server is accessible: `curl http://<lan-ip>:8000/health`
- Test from iPhone Safari: open `http://<lan-ip>:8000/health`

**Resource fork errors (OneDrive/cloud storage):**
```bash
# Copy project to local folder to avoid code signing issues
rsync -av --exclude='build' --exclude='Pods' --exclude='.dart_tool' mobile/vehicle_damage_app /tmp/
cd /tmp/vehicle_damage_app
xattr -rc .  # Remove extended attributes
flutter pub get && cd ios && pod install && cd ..
flutter run -d <device_id> --release --dart-define=API_BASE_URL=http://<lan-ip>:8000
```

**Debug vs Release mode on physical iPhone:**
- Debug builds can only be launched from Xcode/Flutter tooling
- Use `--release` flag to build apps that launch from home screen

## Technologies Used

- **Deep Learning**: PyTorch, Ultralytics YOLO
- **Backend**: FastAPI, Uvicorn, Pydantic
- **Frontend**: Flutter, Dart
- **Computer Vision**: OpenCV, PIL
- **Device Support**: CUDA, Apple MPS, CPU

## License

This project is for educational purposes as part of the UTS Master's program in Deep Learning and Convolutional Neural Networks (42028).

## Acknowledgments

- CarDD Dataset for vehicle damage images
- Ultralytics for YOLO implementations
- UTS Faculty of Engineering and IT
