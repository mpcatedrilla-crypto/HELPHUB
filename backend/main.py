from fastapi import FastAPI, HTTPException
from typing import List
from models import ConcernReport, EmergencySOS
from priority_engine import calculate_priority_score, sort_priority_queue
from datetime import datetime, timezone

app = FastAPI(title="HelpHub Priority Engine")

# In-memory storage for demonstration purposes
reports_db: List[ConcernReport] = []

@app.post("/api/sos", response_model=ConcernReport)
async def trigger_emergency_sos(sos: EmergencySOS):
    """
    Emergency SOS override route. Automatically creates a critical report.
    """
    report = ConcernReport(
        id=sos.id,
        title=f"SOS EMERGENCY: {sos.emergencyType or 'Unknown'}",
        category="Emergency",
        description="Auto-generated SOS report from resident.",
        residentId=sos.residentId,
        latitude=sos.latitude,
        longitude=sos.longitude,
        affectedPopulationScale=5, # Max out
        vulnerableGroups=[],
        submissionTime=sos.timestamp,
        status="Submitted",
        isCriticalOverride=True
    )
    # Calculate score (will auto 100 due to override)
    processed_report = calculate_priority_score(report)
    reports_db.append(processed_report)
    return processed_report

@app.post("/api/reports", response_model=ConcernReport)
async def submit_report(report: ConcernReport):
    """
    Standard concern reporting route. Calculates score and estimates deadline.
    """
    processed_report = calculate_priority_score(report)
    reports_db.append(processed_report)
    return processed_report

@app.get("/api/admin/queue", response_model=List[ConcernReport])
async def get_priority_queue():
    """
    Returns the deterministically sorted queue for the Admin Dashboard.
    """
    return sort_priority_queue(reports_db)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
