"""
Cost Estimation Router.
Handles repair cost estimation based on detected damages.
"""

from typing import List, Optional
from fastapi import APIRouter, HTTPException

from ..config import settings
from ..schemas import (
    Detection,
    CostEstimationRequest,
    CostEstimationResponse,
    DamageCostItem,
)


router = APIRouter(prefix="/cost", tags=["Cost Estimation"])


def calculate_labor_hours(damage_type: str, severity: str) -> float:
    """
    Estimate labor hours based on damage type and severity.
    
    Returns estimated hours for repair.
    """
    base_hours = {
        "dent": 2.0,
        "scratch": 1.5,
        "crack": 3.0,
        "glass_shatter": 2.5,
        "lamp_broken": 1.5,
        "tire_flat": 0.5,
    }
    
    severity_multipliers = {
        "small": 0.75,
        "medium": 1.0,
        "large": 1.5,
    }
    
    return base_hours.get(damage_type, 2.0) * severity_multipliers.get(severity, 1.0)


def calculate_parts_cost(damage_type: str, severity: str) -> float:
    """
    Estimate parts cost based on damage type and severity.
    
    Returns estimated parts cost in AUD (Australian market rates).
    """
    base_parts = {
        "dent": 80.0,       # Paint, filler, materials
        "scratch": 50.0,    # Touch-up paint, clear coat
        "crack": 150.0,     # Filler, structural materials
        "glass_shatter": 450.0,  # Replacement windscreen/glass
        "lamp_broken": 220.0,    # Replacement lamp assembly
        "tire_flat": 180.0,      # New tire (mid-range)
    }
    
    severity_multipliers = {
        "small": 0.5,
        "medium": 1.0,
        "large": 2.0,
    }
    
    return base_parts.get(damage_type, 80.0) * severity_multipliers.get(severity, 1.0)


@router.post("/predict", response_model=CostEstimationResponse)
async def estimate_repair_cost(request: CostEstimationRequest):
    """
    Estimate repair costs based on detected damages.
    
    - **detections**: List of damage detections from /damage/predict
    - **include_labor**: Whether to include labor costs (default: True)
    - **currency**: Currency for cost display (default: USD)
    
    Returns detailed cost breakdown with total estimate.
    """
    if not request.detections:
        return CostEstimationResponse(
            success=True,
            message="No damages to estimate",
            damages=[],
            subtotal=0.0,
            total_cost=0.0,
            currency=request.currency,
            estimate_range={"low": 0.0, "high": 0.0}
        )
    
    damages = []
    subtotal = 0.0
    
    for det in request.detections:
        # Get base cost
        base_cost = settings.base_costs.get(det.class_name, 200.0)
        
        # Get severity (use provided or default to medium)
        severity = det.severity or "medium"
        severity_mult = settings.severity_multipliers.get(severity, 1.0)
        
        # Calculate labor
        labor_hours = calculate_labor_hours(det.class_name, severity)
        labor_cost = labor_hours * settings.LABOR_RATE_PER_HOUR if request.include_labor else 0.0
        
        # Calculate parts
        parts_cost = calculate_parts_cost(det.class_name, severity)
        
        # Total for this damage
        damage_cost = (base_cost * severity_mult) + labor_cost + parts_cost
        
        damage_item = DamageCostItem(
            damage_type=det.class_name,
            severity=severity,
            base_cost=round(base_cost, 2),
            severity_multiplier=severity_mult,
            labor_hours=round(labor_hours, 2),
            labor_cost=round(labor_cost, 2),
            parts_cost=round(parts_cost, 2),
            total_cost=round(damage_cost, 2)
        )
        
        damages.append(damage_item)
        subtotal += damage_cost
    
    # Calculate GST (Australian: 10%)
    tax_rate = 0.10
    tax_amount = subtotal * tax_rate
    total = subtotal + tax_amount
    
    # Calculate estimate range (±20%)
    estimate_range = {
        "low": round(total * 0.8, 2),
        "high": round(total * 1.2, 2)
    }
    
    return CostEstimationResponse(
        success=True,
        message=f"Estimated repair cost for {len(damages)} damage(s)",
        damages=damages,
        subtotal=round(subtotal, 2),
        tax_rate=tax_rate,
        tax_amount=round(tax_amount, 2),
        total_cost=round(total, 2),
        currency=request.currency,
        estimate_range=estimate_range
    )


@router.get("/rates")
async def get_cost_rates():
    """
    Get current cost rates for estimation.
    
    Returns base costs, severity multipliers, and labor rate in AUD.
    """
    return {
        "base_costs": settings.base_costs,
        "severity_multipliers": settings.severity_multipliers,
        "labor_rate_per_hour": settings.LABOR_RATE_PER_HOUR,
        "currency": settings.CURRENCY,
        "currency_symbol": settings.CURRENCY_SYMBOL,
        "tax_name": "GST",
        "tax_rate": 0.10
    }


@router.post("/quick-estimate")
async def quick_estimate(detections: List[Detection]):
    """
    Get a quick cost estimate without detailed breakdown.
    
    - **detections**: List of damage detections
    
    Returns total estimated cost range in AUD.
    """
    if not detections:
        return {"estimate_low": 0.0, "estimate_high": 0.0, "currency": settings.CURRENCY}
    
    total = 0.0
    for det in detections:
        base_cost = settings.base_costs.get(det.class_name, 350.0)
        severity = det.severity or "medium"
        severity_mult = settings.severity_multipliers.get(severity, 1.0)
        
        # Simple estimate: base + labor + parts
        labor = calculate_labor_hours(det.class_name, severity) * settings.LABOR_RATE_PER_HOUR
        parts = calculate_parts_cost(det.class_name, severity)
        
        total += (base_cost * severity_mult) + labor + parts
    
    # Add GST (10%)
    total *= 1.10
    
    return {
        "estimate_low": round(total * 0.8, 2),
        "estimate_high": round(total * 1.2, 2),
        "estimate_mid": round(total, 2),
        "currency": settings.CURRENCY,
        "currency_symbol": settings.CURRENCY_SYMBOL,
        "num_damages": len(detections)
    }
