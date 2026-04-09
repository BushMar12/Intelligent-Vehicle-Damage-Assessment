"""
Configuration settings for the Vehicle Damage Assessment Backend.
"""

import os
from pathlib import Path
from typing import Dict, List, Optional
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application configuration settings."""
    
    # Application settings
    APP_NAME: str = "Vehicle Damage Assessment API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Server settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # Model settings
    MODEL_PATH: str = Field(default="../models/best_model.pt")
    MODEL_TYPE: str = "yolo"  # yolo, faster_rcnn, rtdetr
    CONF_THRESHOLD: float = 0.25
    IOU_THRESHOLD: float = 0.45
    IMAGE_SIZE: int = 640
    
    # Class names
    CLASS_NAMES: List[str] = [
        "dent", "scratch", "crack", 
        "glass shatter", "lamp broken", "tire flat"
    ]
    
    # Cost estimation base costs (AUD — Australian market rates)
    COST_DENT: float = 350.0
    COST_SCRATCH: float = 250.0
    COST_CRACK: float = 450.0
    COST_GLASS_SHATTER: float = 650.0
    COST_LAMP_BROKEN: float = 400.0
    COST_TIRE_FLAT: float = 250.0

    # Currency
    CURRENCY: str = "AUD"
    CURRENCY_SYMBOL: str = "$"

    # Severity multipliers
    SEVERITY_SMALL: float = 1.0  # area < 5%
    SEVERITY_MEDIUM: float = 2.0  # 5% <= area < 15%
    SEVERITY_LARGE: float = 3.5  # area >= 15%
    
    # Labor rate (AUD per hour)
    LABOR_RATE_PER_HOUR: float = 120.0
    
    # File upload settings
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_EXTENSIONS: List[str] = [".jpg", ".jpeg", ".png", ".webp"]
    
    # Paths
    UPLOAD_DIR: str = "uploads"
    OUTPUT_DIR: str = "outputs"
    
    # Database
    DATABASE_URL: str = Field(default="postgresql+asyncpg://postgres:postgres@localhost:5432/vehicledamage")
    
    # GenAI (Defaults heavily to local Qwen via Ollama)
    LLM_BASE_URL: str = Field(default="http://localhost:11434/v1")
    LLM_API_KEY: str = Field(default="ollama")
    LLM_MODEL: str = Field(default="qwen2.5")
    
    @property
    def base_costs(self) -> Dict[str, float]:
        """Get base cost mapping for each damage type."""
        return {
            "dent": self.COST_DENT,
            "scratch": self.COST_SCRATCH,
            "crack": self.COST_CRACK,
            "glass shatter": self.COST_GLASS_SHATTER,
            "lamp broken": self.COST_LAMP_BROKEN,
            "tire flat": self.COST_TIRE_FLAT,
        }
    
    @property
    def severity_multipliers(self) -> Dict[str, float]:
        """Get severity multiplier mapping."""
        return {
            "small": self.SEVERITY_SMALL,
            "medium": self.SEVERITY_MEDIUM,
            "large": self.SEVERITY_LARGE,
        }
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Global settings instance
settings = Settings()


def get_device() -> str:
    """
    Automatically detect and return the best available device.
    Priority: CUDA (NVIDIA GPU) > MPS (Apple Silicon) > CPU
    """
    try:
        import torch
        
        if torch.cuda.is_available():
            return "cuda"
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return "mps"
        else:
            return "cpu"
    except ImportError:
        return "cpu"


# Ensure directories exist
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
os.makedirs(settings.OUTPUT_DIR, exist_ok=True)
