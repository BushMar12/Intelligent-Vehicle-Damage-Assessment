# Intelligent Vehicle Damage Assessment Using Deep Learning

An end-to-end deep learning system for automatic vehicle damage detection and assessment, featuring model comparison, cost estimation in AUD, and web/mobile deployment.

## 🚗 Overview

This project implements a complete vehicle damage assessment pipeline that:
- Detects 6 types of vehicle damage using state-of-the-art object detection models
- Supports both **images and videos** for damage detection
- Compares YOLOv8m and YOLO11m architectures
- Provides repair cost estimation in **AUD** (Australian market rates) with 10% GST
- Generates AI-powered assessment reports
- Deploys as a Flutter web/mobile application with FastAPI backend

## 📁 Project Structure

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
│       └── build/web/              # Web build output
├── data/
│   └── CarDD/                      # CarDD Dataset
├── models/                         # Trained model weights
│   ├── yolov8m_best.pt            # YOLOv8m trained weights
│   └── yolo11m_best.pt            # YOLO11m trained weights
└── configs/
    └── training_config.yaml        # Training configuration
```

## 🏷️ Damage Categories

| ID | Category | Description | Base Cost (AUD) |
|----|----------|-------------|-----------------|
| 0 | Dent | Body panel deformation | $350 |
| 1 | Scratch | Surface paint damage | $250 |
| 2 | Crack | Structural cracks | $450 |
| 3 | Glass Shatter | Window/windshield damage | $650 |
| 4 | Lamp Broken | Headlight/taillight damage | $400 |
| 5 | Tire Flat | Tire damage/deflation | $250 |

*Costs are multiplied by severity (small: 1x, medium: 2x, large: 3.5x) plus labor and parts*

## 🛠️ Installation

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

### Flutter Web App Setup

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

## 📊 Model Comparison

The notebook trains and evaluates two models:

| Model | Architecture | Size | Best For |
|-------|-------------|------|----------|
| YOLOv8m | YOLO v8 Medium | 52MB | Balanced speed/accuracy |
| YOLO11m | YOLO v11 Medium | 41MB | Latest improvements |

## 🔌 API Endpoints

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

## 💰 Cost Estimation (AUD)

| Component | Rate |
|-----------|------|
| Labor | $120/hour |
| GST | 10% |
| Severity Multiplier (Small) | 1.0x |
| Severity Multiplier (Medium) | 2.0x |
| Severity Multiplier (Large) | 3.5x |

## 📱 App Features

- 📷 **Camera capture** for real-time damage assessment
- 🖼️ **Gallery upload** for existing images
- 🎥 **Video upload** for comprehensive vehicle scan
- 🔍 **Damage visualization** with annotated bounding boxes
- 💵 **Cost estimation** in AUD with GST breakdown
- 📊 **Key frame viewer** for video analysis results
- 📄 **Assessment reports** with severity ratings

## 🚀 Quick Start

```bash
# Terminal 1: Start backend
cd backend && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Serve frontend
cd mobile/vehicle_damage_app/build/web
python3 -m http.server 8080
```

Then open http://localhost:8080 in your browser.

## 🔧 Configuration

### Environment Variables (`backend/.env`)

```env
MODEL_PATH=../models/yolov8m_best.pt
MODEL_TYPE=yolov8          # yolov8, yolo11
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
```

## 📦 Technologies Used

- **Deep Learning**: PyTorch, Ultralytics YOLO
- **Backend**: FastAPI, Uvicorn, Pydantic
- **Frontend**: Flutter, Dart
- **Computer Vision**: OpenCV, PIL
- **Device Support**: CUDA, Apple MPS, CPU

## 📄 License

This project is for educational purposes as part of the UTS Master's program in Deep Learning and Convolutional Neural Networks (42028).

## 🙏 Acknowledgments

- CarDD Dataset for vehicle damage images
- Ultralytics for YOLO implementations
- UTS Faculty of Engineering and IT
