from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class ConcernReport(BaseModel):
    id: str
    title: str
    category: str
    description: str
    residentId: str
    latitude: float
    longitude: float
    affectedPopulationScale: int = Field(..., ge=1, le=5)
    vulnerableGroups: List[str]
    submissionTime: datetime
    status: str = "Submitted"
    priorityScore: int = 0
    isCriticalOverride: bool = False
    responseDeadline: Optional[datetime] = None

class EmergencySOS(BaseModel):
    id: str
    residentId: str
    latitude: float
    longitude: float
    timestamp: datetime
    emergencyType: Optional[str] = None
    isCriticalOverride: bool = True
