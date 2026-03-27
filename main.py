import os

from typing import List, Dict, Any
from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from routes import tracking

app = FastAPI(
    title="Smart Travel Tracking System",
    description="Backend service for travel status tracking and agent coordination.",
    version="0.1.0",
)

allowed_origins_env = os.getenv("ALLOWED_ORIGINS", "*")
allowed_origins = [origin.strip() for origin in allowed_origins_env.split(",")] if allowed_origins_env != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True if "*" not in allowed_origins else False,
    allow_methods=["*"],
    allow_headers=["*"],
)

from routes import agents
from routes import auth

from services.db import engine
from models import db_models

# Create tables on startup
db_models.Base.metadata.create_all(bind=engine)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOADS_DIR = os.getenv(
    "UPLOADS_DIR",
    "/tmp/uploads" if os.getenv("VERCEL") == "1" else os.path.join(BASE_DIR, "uploads"),
)
MEMORIES_DIR = os.path.join(UPLOADS_DIR, "memories")

os.makedirs(MEMORIES_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.include_router(tracking.router)
app.include_router(agents.router)
app.include_router(auth.router)

def process_trip(trip: dict):
    trip_name = trip.get('Trip Name', trip.get('trip_name', trip.get('name', 'Unknown')))
    print(f"Agentic AI is analyzing: {trip_name}")

@app.post("/sync-agent")
async def sync_agent(data: dict):
    print("[AGENT] Agentic processing started...")
    return {"status": "success", "message": "Agentic processing started"}

@app.post("/sync-trips")
async def sync_trips(trips: List[dict], background_tasks: BackgroundTasks):
    for trip in trips:
        background_tasks.add_task(process_trip, trip)
    return {"status": "success", "message": "Trips received and processing started"}

@app.get("/")
async def root():
    return {"status": "success", "data": {"message": "Smart Travel Tracking System API is running"}, "message": ""}
