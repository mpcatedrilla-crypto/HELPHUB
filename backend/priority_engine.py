from datetime import timedelta
from typing import List
from models import ConcernReport, EmergencySOS

def calculate_priority_score(report: ConcernReport) -> ConcernReport:
    """Calculates the priority score out of 100 based on standard factors."""
    if report.isCriticalOverride:
        report.priorityScore = 100
        return report

    score = 0
    # 1. Affected Population (Max 40 points)
    # Scale 1-5 maps to (1: 8, 2: 16, 3: 24, 4: 32, 5: 40)
    score += report.affectedPopulationScale * 8

    # 2. Vulnerable Groups (Max 40 points)
    # Each group adds 10 points up to 4 groups
    vulnerable_score = min(len(report.vulnerableGroups) * 10, 40)
    score += vulnerable_score
    
    # 3. Base Urgency by Category (Max 20 points)
    category_weights = {
        "Peace & Order": 20,
        "Health": 20,
        "Fire Hazard": 20,
        "Infrastructure": 10,
        "Flooding": 15,
        "Sanitation": 10,
        "Noise Complaint": 5,
        "Utilities": 10,
    }
    score += category_weights.get(report.category, 5)

    # Cap at 100
    report.priorityScore = min(score, 100)

    # Estimate Response Deadline (simple heuristic based on score)
    if report.priorityScore >= 80:
        report.responseDeadline = report.submissionTime + timedelta(hours=2)
    elif report.priorityScore >= 50:
        report.responseDeadline = report.submissionTime + timedelta(hours=24)
    else:
        report.responseDeadline = report.submissionTime + timedelta(days=3)

    return report

def sort_priority_queue(reports: List[ConcernReport]) -> List[ConcernReport]:
    """
    Sorts reports deterministically:
    1. Override rank descending (Confirmed SOS / Critical)
    2. Priority score descending
    3. Response deadline ascending
    4. Submission time ascending
    5. Report ID ascending
    """
    # Using python's sorted with a complex key
    # For descending booleans/numbers, we can negate them if they are numeric.
    # For datetime ascending, it's just the timestamp.
    # We use a large future date for None deadlines so they sort last.
    max_date = datetime.max
    
    sorted_reports = sorted(
        reports,
        key=lambda r: (
            not r.isCriticalOverride,  # False (0) comes before True (1), so 'not' puts True first
            -r.priorityScore,          # Descending score
            r.responseDeadline or max_date, # Ascending deadline (None goes to end)
            r.submissionTime,          # Ascending submission time
            r.id                       # Ascending ID as final tiebreaker
        )
    )
    return sorted_reports
