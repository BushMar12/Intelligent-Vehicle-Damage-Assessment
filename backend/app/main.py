"""
FastAPI Main Application for Vehicle Damage Assessment.

This is the entry point for the backend API server.
"""

import os
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from .config import settings, get_device
from .routers import damage_router, cost_router, report_router
from .schemas import HealthCheckResponse


# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handle application startup and shutdown events.
    """
    # Startup
    print("=" * 60)
    print("Vehicle Damage Assessment API Starting...")
    print("=" * 60)
    print(f"App: {settings.APP_NAME}")
    print(f"Version: {settings.APP_VERSION}")
    print(f"Device: {get_device()}")
    print(f"Model Path: {settings.MODEL_PATH}")
    
    # Pre-load model (lazy loading on first request if this fails)
    try:
        from .models import get_detector
        detector = get_detector()
        print("✓ Model pre-loaded successfully")
    except FileNotFoundError:
        print("⚠ Model not found - will attempt to load on first request")
    except Exception as e:
        print(f"⚠ Model loading deferred: {e}")
    
    print("=" * 60)
    print("API Ready!")
    print("=" * 60)
    
    yield
    
    # Shutdown
    print("Shutting down...")


# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    description="""
    ## Vehicle Damage Assessment API
    
    AI-powered vehicle damage detection and repair cost estimation service.
    
    ### Features:
    - **Damage Detection**: Upload vehicle images to detect 6 types of damage
    - **Cost Estimation**: Get repair cost estimates based on detected damages
    - **Report Generation**: Generate comprehensive AI assessment reports
    
    ### Damage Categories:
    - Dent
    - Scratch
    - Crack
    - Glass Shatter
    - Lamp Broken
    - Tire Flat
    """,
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routers
app.include_router(damage_router)
app.include_router(cost_router)
app.include_router(report_router)


# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """
    Root endpoint - API information.
    """
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "description": "AI-powered vehicle damage detection and assessment",
        "endpoints": {
            "damage_detection": "/damage/predict",
            "cost_estimation": "/cost/predict",
            "report_generation": "/report/generate",
            "health_check": "/health",
            "documentation": "/docs"
        }
    }


# Health check endpoint
@app.get("/health", response_model=HealthCheckResponse, tags=["Health"])
async def health_check():
    """
    Health check endpoint for monitoring and load balancers.
    """
    model_loaded = False
    try:
        from .models import _detector
        model_loaded = _detector is not None
    except:
        pass
    
    return HealthCheckResponse(
        status="healthy",
        model_loaded=model_loaded,
        device=get_device(),
        version=settings.APP_VERSION,
        timestamp=datetime.now()
    )


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Handle unexpected exceptions gracefully.
    """
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "Internal server error",
            "detail": str(exc) if settings.DEBUG else "An unexpected error occurred"
        }
    )


# Create static directories if serving static files
if settings.DEBUG:
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    os.makedirs(settings.OUTPUT_DIR, exist_ok=True)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
