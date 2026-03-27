from datetime import datetime
from pydantic import BaseModel, Field

class TravelStatusBase(BaseModel):
    trip_id: str = Field(..., example="trip_123")
    location: str = Field(..., example="LAX Airport")
    status: str = Field(..., example="departed")
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class TravelStatusCreate(TravelStatusBase):
    pass

class TravelStatus(TravelStatusBase):
    id: int

    class Config:
        orm_mode = True
