"""
Damage Detection Router.
Handles image and video upload and damage prediction endpoints.
"""

import os
import uuid
import tempfile
from typing import Optional, List
from datetime import datetime

from fastapi import APIRouter, File, UploadFile, HTTPException, Form, Query
from fastapi.responses import JSONResponse

from ..config import settings
from ..schemas import (
    DamageDetectionRequest,
    DamageDetectionResponse,
    VideoDetectionResponse,
    Detection,
)
from ..models import get_detector, DamageDetector
from ..utils import image_to_base64, base64_to_image


router = APIRouter(prefix="/damage", tags=["Damage Detection"])

# Allowed video extensions
VIDEO_EXTENSIONS = [".mp4", ".avi", ".mov", ".mkv", ".webm"]


@router.post("/predict", response_model=DamageDetectionResponse)
async def predict_damage(
    file: UploadFile = File(..., description="Image file to analyze"),
    conf_threshold: float = Query(0.25, ge=0.0, le=1.0, description="Confidence threshold"),
    return_annotated: bool = Query(True, description="Return annotated image")
):
    """
    Detect vehicle damage in an uploaded image.
    
    - **file**: Image file (JPEG, PNG, WebP)
    - **conf_threshold**: Minimum confidence for detections (default: 0.25)
    - **return_annotated**: Whether to include annotated image in response
    
    Returns detected damages with bounding boxes, confidence scores, and severity levels.
    """
    # Validate file extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {settings.ALLOWED_EXTENSIONS}"
        )
    
    # Read file content
    try:
        contents = await file.read()
        
        # Check file size
        if len(contents) > settings.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"File too large. Maximum size: {settings.MAX_FILE_SIZE / 1024 / 1024:.1f}MB"
            )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error reading file: {str(e)}")
    
    # Get detector and run inference
    try:
        detector = get_detector()
        detections, annotated_img, inference_time = detector.predict(
            contents,
            conf_threshold=conf_threshold,
            return_annotated=return_annotated
        )
    except FileNotFoundError as e:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please ensure the model file exists."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")
    
    # Prepare response
    annotated_base64 = None
    if return_annotated and annotated_img is not None:
        annotated_base64 = image_to_base64(annotated_img)
    
    # Get image dimensions
    from PIL import Image
    from io import BytesIO
    img = Image.open(BytesIO(contents))
    image_size = {"width": img.width, "height": img.height}
    
    return DamageDetectionResponse(
        success=True,
        message=f"Detected {len(detections)} damage(s)" if detections else "No damage detected",
        detections=detections,
        num_detections=len(detections),
        annotated_image=annotated_base64,
        inference_time_ms=round(inference_time, 2),
        image_size=image_size
    )


@router.post("/predict/base64", response_model=DamageDetectionResponse)
async def predict_damage_base64(request: DamageDetectionRequest):
    """
    Detect vehicle damage from a base64 encoded image.
    
    - **image_base64**: Base64 encoded image string
    - **conf_threshold**: Minimum confidence for detections
    - **return_annotated**: Whether to include annotated image
    
    Returns detected damages with bounding boxes, confidence scores, and severity levels.
    """
    if not request.image_base64:
        raise HTTPException(status_code=400, detail="No image provided")
    
    try:
        # Decode and validate image
        image_array = base64_to_image(request.image_base64)
        h, w = image_array.shape[:2]
        
        # Get detector and run inference
        detector = get_detector()
        detections, annotated_img, inference_time = detector.predict(
            image_array,
            conf_threshold=request.conf_threshold,
            return_annotated=request.return_annotated
        )
    except FileNotFoundError as e:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please ensure the model file exists."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")
    
    # Prepare response
    annotated_base64 = None
    if request.return_annotated and annotated_img is not None:
        annotated_base64 = image_to_base64(annotated_img)
    
    return DamageDetectionResponse(
        success=True,
        message=f"Detected {len(detections)} damage(s)" if detections else "No damage detected",
        detections=detections,
        num_detections=len(detections),
        annotated_image=annotated_base64,
        inference_time_ms=round(inference_time, 2),
        image_size={"width": w, "height": h}
    )


@router.get("/classes")
async def get_damage_classes():
    """
    Get list of supported damage classes.
    
    Returns the damage categories the model can detect.
    """
    return {
        "classes": [
            {"id": i, "name": name}
            for i, name in enumerate(settings.CLASS_NAMES)
        ],
        "total": len(settings.CLASS_NAMES)
    }


@router.get("/thresholds")
async def get_default_thresholds():
    """
    Get default detection thresholds.
    
    Returns confidence and IoU thresholds used by the model.
    """
    return {
        "confidence_threshold": settings.CONF_THRESHOLD,
        "iou_threshold": settings.IOU_THRESHOLD,
        "image_size": settings.IMAGE_SIZE
    }


@router.post("/predict/video", response_model=VideoDetectionResponse)
async def predict_damage_video(
    file: UploadFile = File(..., description="Video file to analyze"),
    conf_threshold: float = Query(0.25, ge=0.0, le=1.0, description="Confidence threshold"),
    frame_interval: int = Query(30, ge=1, le=300, description="Process every Nth frame"),
    max_frames: int = Query(50, ge=1, le=200, description="Maximum frames to process")
):
    """
    Detect vehicle damage in an uploaded video.
    
    - **file**: Video file (MP4, AVI, MOV, MKV, WebM)
    - **conf_threshold**: Minimum confidence for detections (default: 0.25)
    - **frame_interval**: Process every Nth frame (default: 30, i.e., ~1 per second for 30fps)
    - **max_frames**: Maximum number of frames to analyze (default: 50)
    
    Returns aggregated detections across all analyzed frames with key frames.
    """
    import cv2
    import numpy as np
    
    # Validate file extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in VIDEO_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid video type. Allowed: {VIDEO_EXTENSIONS}"
        )
    
    # Save video temporarily
    try:
        contents = await file.read()
        
        # Check file size (50MB limit for videos)
        max_video_size = 50 * 1024 * 1024
        if len(contents) > max_video_size:
            raise HTTPException(
                status_code=400,
                detail=f"Video too large. Maximum size: {max_video_size / 1024 / 1024:.0f}MB"
            )
        
        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=file_ext, delete=False) as tmp:
            tmp.write(contents)
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error reading video: {str(e)}")
    
    try:
        # Open video
        cap = cv2.VideoCapture(tmp_path)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Could not open video file")
        
        # Get video properties
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = total_frames / fps if fps > 0 else 0
        
        detector = get_detector()
        all_detections = []
        frame_results = []
        frames_processed = 0
        total_inference_time = 0
        
        frame_idx = 0
        while frames_processed < max_frames:
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()
            
            if not ret:
                break
            
            # Convert BGR to RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Run inference
            detections, annotated_img, inference_time = detector.predict(
                frame_rgb,
                conf_threshold=conf_threshold,
                return_annotated=True
            )
            
            total_inference_time += inference_time
            
            if detections:
                # Store frame result with annotated image
                annotated_base64 = image_to_base64(annotated_img) if annotated_img is not None else None
                
                frame_results.append({
                    "frame_number": frame_idx,
                    "timestamp_sec": round(frame_idx / fps, 2) if fps > 0 else 0,
                    "detections": [d.model_dump() for d in detections],
                    "annotated_frame": annotated_base64
                })
                
                all_detections.extend(detections)
            
            frames_processed += 1
            frame_idx += frame_interval
            
            if frame_idx >= total_frames:
                break
        
        cap.release()
        
        # Aggregate unique detections (merge similar ones)
        aggregated = _aggregate_detections(all_detections)
        
        return VideoDetectionResponse(
            success=True,
            message=f"Processed {frames_processed} frames, found {len(aggregated)} unique damage(s)",
            video_info={
                "duration_sec": round(duration, 2),
                "fps": round(fps, 2),
                "total_frames": total_frames,
                "frames_analyzed": frames_processed,
                "width": width,
                "height": height
            },
            aggregated_detections=aggregated,
            frame_results=frame_results[:10],  # Limit to 10 key frames in response
            total_detections=len(all_detections),
            unique_detections=len(aggregated),
            total_inference_time_ms=round(total_inference_time, 2)
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Video processing error: {str(e)}")
    finally:
        # Clean up temp file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def _aggregate_detections(detections: List[Detection]) -> List[Detection]:
    """
    Aggregate detections across frames, merging similar ones.
    Returns unique detections with highest confidence for each damage type/location.
    """
    if not detections:
        return []
    
    # Group by class and approximate location
    from collections import defaultdict
    groups = defaultdict(list)
    
    for det in detections:
        # Create a key based on class and rough location (grid-based)
        center_x = (det.bbox.x_min + det.bbox.x_max) / 2
        center_y = (det.bbox.y_min + det.bbox.y_max) / 2
        
        # Divide image into 4x4 grid for grouping
        grid_x = int(center_x // 160)  # Assuming ~640 width
        grid_y = int(center_y // 160)
        
        key = (det.class_name, grid_x, grid_y)
        groups[key].append(det)
    
    # Take highest confidence detection from each group
    aggregated = []
    for key, group in groups.items():
        best = max(group, key=lambda d: d.confidence)
        aggregated.append(best)
    
    # Sort by confidence
    aggregated.sort(key=lambda d: d.confidence, reverse=True)
    
    return aggregated
