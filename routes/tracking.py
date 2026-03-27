from fastapi import APIRouter, Depends, HTTPException
from typing import List
from sqlalchemy.orm import Session

from models import tracking_models
from models.db_models import TravelStatus
from services.db import get_db
from services.db_service import add_trip_status, get_trip_statuses, get_trip

router = APIRouter(prefix="/tracking", tags=["tracking"])


def success_response(data: dict, message: str = "") -> dict:
    return {"status": "success", "data": data, "message": message}


def error_response(message: str) -> dict:
    return {"status": "error", "message": message}


@router.post("/")
async def create_status(status: tracking_models.TravelStatusCreate, db: Session = Depends(get_db)):
    try:
        print("Tracking create_status")
        trip = get_trip(db, status.trip_id)
        if not trip:
            return error_response("Trip not found")

        record = add_trip_status(db, trip_id=status.trip_id, location=status.location, status=status.status)
        data = {"id": record.id, "trip_id": record.trip_id, "location": record.location, "status": record.status, "timestamp": record.timestamp.isoformat()}
        return success_response(data)
    except Exception as e:
        print("Error in /tracking/", e)
        return error_response(str(e))

@router.get("/")
async def list_statuses(trip_id: int, db: Session = Depends(get_db)):
    try:
        statuses = get_trip_statuses(db, trip_id)
        result = [
            {"id": s.id, "trip_id": s.trip_id, "location": s.location, "status": s.status, "timestamp": s.timestamp.isoformat()}
            for s in statuses
        ]
        return success_response({"statuses": result})
    except Exception as e:
        print("Error in /tracking/ (list)", e)
        return error_response(str(e))


@router.get("/{status_id}")
async def get_status(status_id: int, db: Session = Depends(get_db)):
    try:
        status = db.query(TravelStatus).filter(TravelStatus.id == status_id).first()
        if status is None:
            return error_response("Status not found")
        data = {"id": status.id, "trip_id": status.trip_id, "location": status.location, "status": status.status, "timestamp": status.timestamp.isoformat()}
        return success_response(data)
    except Exception as e:
        print("Error in /tracking/{status_id}", e)
        return error_response(str(e))

