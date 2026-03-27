import json
import os
import shutil
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from typing import Dict, Any, Optional
from sqlalchemy.orm import Session

from agents import TravelPlanningAgent, ContextAwarenessAgent, ExpenseTrackingAgent, ReminderAgent, MemoryAgent
from services.db import get_db
from services.db_service import (
    create_trip,
    add_expense,
    get_expenses,
    add_memory,
    get_memories,
    get_trip,
    get_user_by_email,
    create_user,
    list_trips,
    list_all_trips,
    get_user_preferences,
)
from services.decision_engine import DecisionEngine
from services.learning_engine import LearningEngine

router = APIRouter(prefix="/agents", tags=["agents"])

planning_agent = TravelPlanningAgent()
context_agent = ContextAwarenessAgent()
expense_agent = ExpenseTrackingAgent()
reminder_agent = ReminderAgent()
memory_agent = MemoryAgent()
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPLOADS_DIR = os.getenv(
    "UPLOADS_DIR",
    "/tmp/uploads" if os.getenv("VERCEL") == "1" else os.path.join(BASE_DIR, "uploads"),
)
MEMORIES_DIR = os.path.join(UPLOADS_DIR, "memories")


def success_response(data: dict, message: str = "") -> dict:
    return {"status": "success", "data": data, "message": message}


def error_response(message: str) -> dict:
    return {"status": "error", "message": message}


def serialize_memory(memory) -> dict:
    note_value = memory.note
    description = note_value
    media_path = None
    media_type = None
    original_filename = None

    try:
        parsed = json.loads(note_value)
        if isinstance(parsed, dict):
            description = parsed.get("description") or parsed.get("note") or ""
            media_path = parsed.get("media_path")
            media_type = parsed.get("media_type")
            original_filename = parsed.get("original_filename")
    except Exception:
        pass

    return {
        "id": memory.id,
        "trip_id": memory.trip_id,
        "note": description,
        "description": description,
        "media_path": media_path,
        "media_type": media_type,
        "original_filename": original_filename,
        "timestamp": memory.timestamp.isoformat(),
    }

@router.post("/planning")
async def run_planning(input_data: Dict[str, Any]):
    try:
        print("[AGENT] TravelPlanningAgent running")
        print("[API SEQUENCE] TripAgent syncing location status to Cloud.")
        result = planning_agent.run(input_data)
        return success_response(result)
    except Exception as e:
        print("[AGENT] Error in /agents/planning", e)
        return error_response(str(e))


@router.post("/context")
async def run_context(input_data: Dict[str, Any]):
    try:
        print("[AGENT] ContextAwarenessAgent running")
        result = context_agent.run(input_data)
        return success_response(result)
    except Exception as e:
        print("[AGENT] Error in /agents/context", e)
        return error_response(str(e))


@router.post("/expenses")
async def run_expenses(input_data: Dict[str, Any]):
    try:
        print("[AGENT] ExpenseTrackingAgent running")
        result = expense_agent.run(input_data)
        return success_response(result)
    except Exception as e:
        print("[AGENT] Error in /agents/expenses", e)
        return error_response(str(e))


@router.post("/reminders")
async def run_reminder(input_data: Dict[str, Any]):
    try:
        print("[AGENT] ReminderAgent running")
        result = reminder_agent.run(input_data)
        return success_response(result)
    except Exception as e:
        print("[AGENT] Error in /agents/reminders", e)
        return error_response(str(e))


@router.post("/memory")
async def run_memory(input_data: Dict[str, Any]):
    try:
        print("[AGENT] MemoryAgent running")
        result = memory_agent.run(input_data)
        return success_response(result)
    except Exception as e:
        print("[AGENT] Error in /agents/memory", e)
        return error_response(str(e))

# High-level endpoints
@router.post("/plan-trip")
async def plan_trip(input_data: Dict[str, Any], db: Session = Depends(get_db)):
    user_email = input_data.get("user_email")
    if not user_email:
        raise HTTPException(status_code=400, detail="user_email is required")

    user = get_user_by_email(db, user_email)
    if user is None:
        user = create_user(db, name=input_data.get("user_name", "Traveler"), email=user_email)

    destination = input_data.get("destination", "unknown")
    start_date = input_data.get("start_date")
    end_date = input_data.get("end_date")
    trip = create_trip(db, user_id=user.id, destination=destination, start_date=start_date, end_date=end_date)

    agent_info = planning_agent.run(input_data)
    return {"trip": {"id": trip.id, "destination": destination, "status": trip.status}, "plan": agent_info}

@router.post("/add-expense")
async def add_expense_route(input_data: Dict[str, Any], db: Session = Depends(get_db)):
    amount = input_data.get("amount")
    category = input_data.get("category", "general")
    description = input_data.get("description", "")
    trip_id = input_data.get("trip_id")

    if amount is None:
        raise HTTPException(status_code=400, detail="amount is required")

    if not isinstance(amount, (float, int)):
        raise HTTPException(status_code=400, detail="amount must be numeric")

    if trip_id is not None:
        trip = get_trip(db, int(trip_id))
        if trip is None:
            raise HTTPException(status_code=404, detail="trip not found")
        expense = add_expense(db, trip_id=trip.id, amount=float(amount), category=category, description=description)
    else:
        expense = add_expense(db, trip_id=None, amount=float(amount), category=category, description=description)

    all_expenses = get_expenses(db)
    summary = expense_agent.run({"expenses": [e.amount for e in all_expenses], "budget": input_data.get("budget", 0)})
    print("[API SEQUENCE] ExpenseAgent persisting new transaction.")

    return {"expense": {"id": expense.id, "trip_id": expense.trip_id, "amount": expense.amount, "category": expense.category}, "summary": summary}

@router.get("/get-expenses")
async def get_expenses_route(db: Session = Depends(get_db)):
    try:
        expenses = get_expenses(db)
        total = sum(e.amount for e in expenses)
        rows = [{"id": e.id, "amount": e.amount, "category": e.category} for e in expenses]
        return success_response({"expenses": rows, "total": total})
    except Exception as e:
        print("[AGENT] Error in /agents/get-expenses", e)
        return error_response(str(e))


@router.get("/get-expenses-analysis")
async def get_expenses_analysis(db: Session = Depends(get_db)):
    try:
        expenses = get_expenses(db)
        input_expenses = [
            {"amount": e.amount, "category": e.category, "description": e.description or ""}
            for e in expenses
        ]
        analysis = expense_agent.run({"expenses": input_expenses})
        return success_response({"analysis": analysis})
    except Exception as e:
        print("[AGENT] Error in /agents/get-expenses-analysis", e)
        return error_response(str(e))


@router.post("/get-reminders")
async def get_reminders_route(db: Session = Depends(get_db)):
    try:
        trips = list_all_trips(db)
        trip_dicts = [
            {
                "destination": t.destination,
                "start_date": t.start_date if t.start_date else "",
            }
            for t in trips
        ]
        result = reminder_agent.run(trip_dicts)
        return success_response({"reminders": result})
    except Exception as e:
        print("[AGENT] Error in /agents/get-reminders", e)
        return error_response(str(e))

@router.post("/run-all")
async def run_all_agents(input_data: Dict[str, Any], db: Session = Depends(get_db)):
    """Orchestrate all agents and return a unified AI response."""
    try:
        print("[AGENT] run-all agents start")

        expenses_db = get_expenses(db)
        trips_db = list_all_trips(db)
        memories_db = get_memories(db)

        expense_items = [
            {"amount": e.amount, "category": e.category, "description": e.description or ""}
            for e in expenses_db
        ]

        trip_items = [{"destination": t.destination, "start_date": t.start_date or ""} for t in trips_db]

        memory_items = [
            {"note": m.note, "timestamp": m.timestamp.isoformat(), "trip_id": m.trip_id}
            for m in memories_db
        ]

        print("[AGENT] Expense agent call")
        expense_analysis = expense_agent.run({"expenses": expense_items})

        print("[AGENT] Reminder agent call")
        reminders = reminder_agent.run(trip_items)

        print("[AGENT] Travel planning agent call")
        travel_plan = planning_agent.run({"destination": input_data.get("location", "unknown")})

        latitude = input_data.get("latitude")
        longitude = input_data.get("longitude")

        print("[AGENT] Context awareness agent call")
        context = context_agent.run({
            "location": input_data.get("location", "unknown"),
            "timestamp": input_data.get("time", ""),
            "latitude": latitude,
            "longitude": longitude,
        })

        print("[AGENT] Memory agent call")
        memories = memory_agent.run(memory_items)

        ai_insights = {
            "expense_analysis": expense_analysis.get("ai_insight", ""),
            "travel_plan": travel_plan.get("ai_insight", ""),
            "context": context.get("ai_insight", ""),
        }

        decision_engine = DecisionEngine()
        decision_output = decision_engine.decide({
            'expense_analysis': expense_analysis,
            'reminders': reminders,
            'travel_plan': travel_plan,
            'context': context,
            'memories': memories,
            'ai_insights': ai_insights,
        })

        learning_engine = LearningEngine(db)
        prefs = learning_engine.analyze_preferences(expense_items, trip_items, memory_items)
        adaptation = learning_engine.personalize_decision(decision_output, prefs.get('preferences', {}))

        data = {
            "rule_based": {
                "expense_analysis": expense_analysis,
                "reminders": reminders,
                "travel_plan": travel_plan,
                "context": context,
                "memories": memories,
            },
            "ai_insights": ai_insights,
            "final_decision_engine": decision_output,
            "personalization": adaptation,
        }

        return success_response(data)
    except Exception as e:
        print("[AGENT] Error in /agents/run-all", e)
        return error_response(str(e))

@router.post("/upload-memory")
async def upload_memory_route(
    request: Request,
    note: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    trip_id: Optional[int] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    input_data: Dict[str, Any] = {}
    if note is None and description is None and file is None:
        try:
            input_data = await request.json()
        except Exception:
            input_data = {}

    note = description or note or input_data.get("description") or input_data.get("note")
    trip_id = trip_id if trip_id is not None else input_data.get("trip_id")

    if not note:
        raise HTTPException(status_code=400, detail="note is required")

    if trip_id is not None and get_trip(db, int(trip_id)) is None:
        raise HTTPException(status_code=404, detail="trip not found")

    media_path = None
    media_type = None
    original_filename = None

    if file is not None and file.filename:
        os.makedirs(MEMORIES_DIR, exist_ok=True)
        extension = os.path.splitext(file.filename)[1]
        generated_name = f"{uuid4().hex}{extension}"
        absolute_path = os.path.join(MEMORIES_DIR, generated_name)

        with open(absolute_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        media_path = f"/uploads/memories/{generated_name}"
        original_filename = file.filename
        media_type = "video" if (file.content_type or "").startswith("video/") else "image"

    stored_note = json.dumps(
        {
            "description": note,
            "media_path": media_path,
            "media_type": media_type,
            "original_filename": original_filename,
        }
    )

    memory = add_memory(
        db,
        note=stored_note,
        trip_id=int(trip_id) if trip_id is not None else None,
    )
    memory_response = memory_agent.run({"note": note, "timestamp": memory.timestamp.isoformat()})
    print("[API SEQUENCE] AlbumAgent archiving generated media.")
    
    print("[API SEQUENCE] AlbumAgent archiving generated media.")
    
    return success_response({"memory": serialize_memory(memory), "agent": memory_response})

@router.get("/get-memories")
async def get_memories_route(trip_id: Optional[int] = None, db: Session = Depends(get_db)):
    try:
        memories = get_memories(db, trip_id=trip_id)
        rows = [serialize_memory(m) for m in memories]
        return success_response({"memories": rows, "count": len(rows)})
    except Exception as e:
        print("[AGENT] Error in /agents/get-memories", e)
        return error_response(str(e))


@router.get("/get-preferences")
async def get_preferences_route(db: Session = Depends(get_db)):
    try:
        preferences = get_user_preferences(db)
        rows = [{"id": p.id, "key": p.key, "value": p.value} for p in preferences]
        return success_response({"preferences": rows, "count": len(rows)})
    except Exception as e:
        print("[AGENT] Error in /agents/get-preferences", e)
        return error_response(str(e))
