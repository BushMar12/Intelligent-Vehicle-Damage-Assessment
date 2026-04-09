from sqlalchemy import Column, String, DateTime, JSON
from datetime import datetime
import uuid
from .database import Base

class Assessment(Base):
    __tablename__ = "assessments"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    image_path = Column(String, nullable=True)
    detections_json = Column(JSON, default=list)
    cost_estimation_json = Column(JSON, default=dict)
    report_json = Column(JSON, default=dict)
    chat_history = Column(JSON, default=list)
