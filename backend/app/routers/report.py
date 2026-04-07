"""
Report Generation Router.
Handles AI-generated assessment reports.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse

from ..config import settings
from ..schemas import (
    Detection,
    CostEstimationResponse,
    ReportRequest,
    ReportResponse,
    AssessmentSummary,
)


router = APIRouter(prefix="/report", tags=["Report Generation"])


def generate_assessment_summary(
    detections: List[Detection],
    cost_info: Optional[CostEstimationResponse] = None
) -> AssessmentSummary:
    """
    Generate an AI-style assessment summary based on detections.
    
    This creates a human-readable analysis of the vehicle damage.
    """
    if not detections:
        return AssessmentSummary(
            overall_severity="none",
            primary_concerns=[],
            recommended_actions=["No damage detected. Vehicle appears to be in good condition."],
            safety_notes=[],
            summary_text="Vehicle inspection complete. No damage was detected in the analyzed image."
        )
    
    # Analyze detections
    damage_counts = {}
    severities = []
    
    for det in detections:
        damage_counts[det.class_name] = damage_counts.get(det.class_name, 0) + 1
        if det.severity:
            severities.append(det.severity)
    
    # Determine overall severity
    if "large" in severities or len(detections) > 5:
        overall_severity = "severe"
    elif "medium" in severities or len(detections) > 2:
        overall_severity = "moderate"
    else:
        overall_severity = "minor"
    
    # Generate primary concerns
    primary_concerns = []
    concern_templates = {
        "dent": "Body panel deformation detected",
        "scratch": "Surface paint damage identified",
        "crack": "Structural crack requiring attention",
        "glass shatter": "Glass damage requiring immediate replacement",
        "lamp broken": "Lighting system damage affecting visibility",
        "tire flat": "Tire damage affecting vehicle mobility",
    }
    
    for damage_type, count in sorted(damage_counts.items(), key=lambda x: -x[1]):
        concern = concern_templates.get(damage_type, f"{damage_type} damage detected")
        if count > 1:
            concern += f" ({count} instances)"
        primary_concerns.append(concern)
    
    # Generate recommended actions
    recommended_actions = []
    
    if "glass shatter" in damage_counts:
        recommended_actions.append("URGENT: Replace damaged glass immediately for safety")
    
    if "lamp broken" in damage_counts:
        recommended_actions.append("Replace broken lamp(s) before driving - required for road safety")
    
    if "tire flat" in damage_counts:
        recommended_actions.append("Replace or repair damaged tire(s) before driving")
    
    if "crack" in damage_counts:
        recommended_actions.append("Have structural cracks assessed by a professional")
    
    if "dent" in damage_counts:
        count = damage_counts["dent"]
        if count > 2:
            recommended_actions.append("Consider paintless dent repair for multiple dents")
        else:
            recommended_actions.append("Schedule dent repair at your convenience")
    
    if "scratch" in damage_counts:
        recommended_actions.append("Touch-up paint or professional refinishing recommended")
    
    if not recommended_actions:
        recommended_actions.append("Schedule repairs at your earliest convenience")
    
    # Safety notes
    safety_notes = []
    safety_critical = ["glass shatter", "lamp broken", "tire flat", "crack"]
    
    has_safety_critical = any(d in damage_counts for d in safety_critical)
    
    if has_safety_critical:
        safety_notes.append("Safety-critical damage detected. Address before driving.")
    
    if "glass shatter" in damage_counts:
        safety_notes.append("Broken glass may compromise structural integrity and visibility")
    
    if "lamp broken" in damage_counts:
        safety_notes.append("Driving with broken lights may violate traffic regulations")
    
    # Generate summary text
    total_damages = len(detections)
    damage_types = len(damage_counts)
    
    summary_parts = [
        f"Vehicle damage assessment identified {total_damages} damage instance(s) ",
        f"across {damage_types} category/categories. "
    ]
    
    if overall_severity == "severe":
        summary_parts.append(
            "The overall damage level is SEVERE. Immediate professional inspection is recommended. "
        )
    elif overall_severity == "moderate":
        summary_parts.append(
            "The overall damage level is MODERATE. Repairs should be scheduled soon. "
        )
    else:
        summary_parts.append(
            "The overall damage level is MINOR. Repairs can be scheduled at convenience. "
        )
    
    if cost_info and cost_info.total_cost > 0:
        summary_parts.append(
            f"Estimated repair cost: ${cost_info.estimate_range['low']:.2f} - "
            f"${cost_info.estimate_range['high']:.2f} {cost_info.currency}."
        )
    
    summary_text = "".join(summary_parts)
    
    return AssessmentSummary(
        overall_severity=overall_severity,
        primary_concerns=primary_concerns[:5],  # Limit to top 5
        recommended_actions=recommended_actions[:5],
        safety_notes=safety_notes,
        summary_text=summary_text
    )


@router.post("/generate", response_model=ReportResponse)
async def generate_report(request: ReportRequest):
    """
    Generate a comprehensive damage assessment report.
    
    - **detections**: List of damage detections from /damage/predict
    - **cost_estimation**: Optional cost estimation from /cost/predict
    - **vehicle_info**: Optional vehicle information (make, model, year)
    - **report_format**: Output format (json, pdf, html)
    
    Returns AI-generated assessment summary with recommendations.
    """
    # Generate report ID
    report_id = str(uuid.uuid4())[:8].upper()
    
    # Generate assessment summary
    summary = generate_assessment_summary(
        request.detections,
        request.cost_estimation
    )
    
    # Build report data
    report_data = {
        "report_id": report_id,
        "generated_at": datetime.now().isoformat(),
        "vehicle_info": request.vehicle_info or {},
        "damage_analysis": {
            "total_detections": len(request.detections),
            "detections": [det.dict() for det in request.detections],
            "damage_summary": {}
        },
        "assessment": summary.dict(),
    }
    
    # Add damage summary
    for det in request.detections:
        if det.class_name not in report_data["damage_analysis"]["damage_summary"]:
            report_data["damage_analysis"]["damage_summary"][det.class_name] = {
                "count": 0,
                "severities": [],
                "total_area_pct": 0.0
            }
        
        report_data["damage_analysis"]["damage_summary"][det.class_name]["count"] += 1
        if det.severity:
            report_data["damage_analysis"]["damage_summary"][det.class_name]["severities"].append(det.severity)
        if det.area_percentage:
            report_data["damage_analysis"]["damage_summary"][det.class_name]["total_area_pct"] += det.area_percentage
    
    # Add cost info if provided
    if request.cost_estimation:
        report_data["cost_estimation"] = request.cost_estimation.dict()
    
    return ReportResponse(
        success=True,
        message="Report generated successfully",
        report_id=report_id,
        generated_at=datetime.now(),
        assessment_summary=summary,
        damage_count=len(request.detections),
        total_cost=request.cost_estimation.total_cost if request.cost_estimation else None,
        report_data=report_data if request.report_format == "json" else None
    )


@router.get("/template")
async def get_report_template():
    """
    Get the report template structure.
    
    Returns the JSON structure used for reports.
    """
    return {
        "template_version": "1.0",
        "sections": [
            "report_id",
            "generated_at",
            "vehicle_info",
            "damage_analysis",
            "assessment",
            "cost_estimation"
        ],
        "damage_categories": settings.CLASS_NAMES,
        "severity_levels": ["small", "medium", "large"],
        "overall_severity_levels": ["none", "minor", "moderate", "severe"]
    }
