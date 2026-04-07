"""
Pydantic schemas for API request/response models.
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime


# ============================================================================
# Detection Schemas
# ============================================================================

class BoundingBox(BaseModel):
    """Bounding box coordinates."""
    x_min: float = Field(..., description="Left x coordinate")
    y_min: float = Field(..., description="Top y coordinate")
    x_max: float = Field(..., description="Right x coordinate")
    y_max: float = Field(..., description="Bottom y coordinate")
    
    @property
    def width(self) -> float:
        return self.x_max - self.x_min
    
    @property
    def height(self) -> float:
        return self.y_max - self.y_min
    
    @property
    def area(self) -> float:
        return self.width * self.height
    
    @property
    def center(self) -> tuple:
        return ((self.x_min + self.x_max) / 2, (self.y_min + self.y_max) / 2)


class Detection(BaseModel):
    """Single damage detection result."""
    class_id: int = Field(..., description="Class ID (0-5)")
    class_name: str = Field(..., description="Damage type name")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Detection confidence")
    bbox: BoundingBox = Field(..., description="Bounding box coordinates")
    area_percentage: Optional[float] = Field(None, description="Area as percentage of image")
    severity: Optional[str] = Field(None, description="Damage severity (small/medium/large)")


class DamageDetectionRequest(BaseModel):
    """Request for damage detection (when sending base64 image)."""
    image_base64: Optional[str] = Field(None, description="Base64 encoded image")
    conf_threshold: float = Field(0.25, ge=0.0, le=1.0, description="Confidence threshold")
    return_annotated: bool = Field(True, description="Return annotated image")


class DamageDetectionResponse(BaseModel):
    """Response from damage detection endpoint."""
    success: bool = Field(..., description="Whether detection was successful")
    message: str = Field(..., description="Status message")
    detections: List[Detection] = Field(default_factory=list, description="List of detected damages")
    num_detections: int = Field(0, description="Total number of detections")
    annotated_image: Optional[str] = Field(None, description="Base64 encoded annotated image")
    inference_time_ms: float = Field(0.0, description="Inference time in milliseconds")
    image_size: Optional[Dict[str, int]] = Field(None, description="Image dimensions")


class VideoDetectionResponse(BaseModel):
    """Response from video damage detection endpoint."""
    success: bool = Field(..., description="Whether detection was successful")
    message: str = Field(..., description="Status message")
    video_info: Dict[str, Any] = Field(default_factory=dict, description="Video metadata")
    aggregated_detections: List[Detection] = Field(default_factory=list, description="Unique damages found")
    frame_results: List[Dict[str, Any]] = Field(default_factory=list, description="Per-frame detection results")
    total_detections: int = Field(0, description="Total detections across all frames")
    unique_detections: int = Field(0, description="Number of unique damage areas")
    total_inference_time_ms: float = Field(0.0, description="Total inference time")


# ============================================================================
# Cost Estimation Schemas
# ============================================================================

class DamageCostItem(BaseModel):
    """Cost breakdown for a single damage."""
    damage_type: str = Field(..., description="Type of damage")
    severity: str = Field(..., description="Damage severity")
    base_cost: float = Field(..., description="Base repair cost")
    severity_multiplier: float = Field(..., description="Severity multiplier applied")
    labor_hours: float = Field(..., description="Estimated labor hours")
    labor_cost: float = Field(..., description="Labor cost")
    parts_cost: float = Field(..., description="Estimated parts cost")
    total_cost: float = Field(..., description="Total cost for this damage")


class CostEstimationRequest(BaseModel):
    """Request for cost estimation."""
    detections: List[Detection] = Field(..., description="List of damage detections")
    include_labor: bool = Field(True, description="Include labor costs")
    currency: str = Field("USD", description="Currency for cost display")


class CostEstimationResponse(BaseModel):
    """Response from cost estimation endpoint."""
    success: bool = Field(..., description="Whether estimation was successful")
    message: str = Field(..., description="Status message")
    damages: List[DamageCostItem] = Field(default_factory=list, description="Cost breakdown per damage")
    subtotal: float = Field(0.0, description="Subtotal before tax")
    tax_rate: float = Field(0.0, description="Tax rate applied")
    tax_amount: float = Field(0.0, description="Tax amount")
    total_cost: float = Field(0.0, description="Total estimated repair cost")
    currency: str = Field("USD", description="Currency")
    estimate_range: Dict[str, float] = Field(
        default_factory=dict, 
        description="Low/high estimate range"
    )


# ============================================================================
# Report Generation Schemas
# ============================================================================

class ReportRequest(BaseModel):
    """Request for report generation."""
    detections: List[Detection] = Field(..., description="List of damage detections")
    cost_estimation: Optional[CostEstimationResponse] = Field(None, description="Cost estimation results")
    vehicle_info: Optional[Dict[str, Any]] = Field(None, description="Vehicle information")
    include_image: bool = Field(True, description="Include annotated image in report")
    report_format: str = Field("json", description="Report format (json/pdf/html)")


class AssessmentSummary(BaseModel):
    """AI-generated assessment summary."""
    overall_severity: str = Field(..., description="Overall damage severity rating")
    primary_concerns: List[str] = Field(default_factory=list, description="Main areas of concern")
    recommended_actions: List[str] = Field(default_factory=list, description="Recommended repair actions")
    safety_notes: List[str] = Field(default_factory=list, description="Safety-related notes")
    summary_text: str = Field(..., description="Human-readable summary")


class ReportResponse(BaseModel):
    """Response from report generation endpoint."""
    success: bool = Field(..., description="Whether report was generated successfully")
    message: str = Field(..., description="Status message")
    report_id: str = Field(..., description="Unique report identifier")
    generated_at: datetime = Field(..., description="Report generation timestamp")
    assessment_summary: AssessmentSummary = Field(..., description="AI assessment summary")
    damage_count: int = Field(0, description="Total damages detected")
    total_cost: Optional[float] = Field(None, description="Total estimated cost")
    report_url: Optional[str] = Field(None, description="URL to download full report")
    report_data: Optional[Dict[str, Any]] = Field(None, description="Full report data")


# ============================================================================
# Health Check Schema
# ============================================================================

class HealthCheckResponse(BaseModel):
    """Health check response."""
    status: str = Field(..., description="Service status")
    model_loaded: bool = Field(..., description="Whether model is loaded")
    device: str = Field(..., description="Compute device being used")
    version: str = Field(..., description="API version")
    timestamp: datetime = Field(..., description="Current timestamp")
