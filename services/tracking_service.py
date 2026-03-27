from typing import List, Optional

from models.tracking_models import TravelStatusCreate, TravelStatus


def create_status(db: List[TravelStatus], status: TravelStatusCreate) -> TravelStatus:
    new_id = len(db) + 1
    record = TravelStatus(id=new_id, **status.dict())
    db.append(record)
    return record


def list_statuses(db: List[TravelStatus]) -> List[TravelStatus]:
    return db


def get_status(db: List[TravelStatus], status_id: int) -> Optional[TravelStatus]:
    return next((item for item in db if item.id == status_id), None)
