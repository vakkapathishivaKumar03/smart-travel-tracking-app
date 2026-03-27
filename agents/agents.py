from datetime import datetime, timedelta
from typing import Dict, Any, List

from services.ai_service import generate_ai_response


class TravelPlanningAgent:
    def __init__(self):
        self.name = "TravelPlanningAgent"

    def run(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        destination = input_data.get("destination", "goa")

        # Rule-based default plan
        suggestions = {
            "goa": ["Beach sunset", "Water sports", "Night market"],
            "hyderabad": ["Visit Charminar", "Try local biryani", "Explore historic sites"],
        }

        activities = suggestions.get(destination.lower(), ["Relax", "Explore local cuisine", "Take a walking tour"])

        ai_plan = ""
        try:
            prompt = f"Generate a 1-day travel itinerary for {destination} for a student traveler."
            print(f"TravelPlanningAgent calling AI with prompt: {prompt}")
            ai_text = generate_ai_response(prompt)
            ai_plan = ai_text or "No AI plan generated."
        except Exception as e:
            print(f"TravelPlanningAgent AI failed: {e}")
            ai_plan = "AI unavailable, using rule-based itinerary."

        return {
            "agent": self.name,
            "destination": destination,
            "activities": activities,
            "ai_insight": ai_plan,
        }


class ContextAwarenessAgent:
    def __init__(self):
        self.name = "ContextAwarenessAgent"

    def run(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        location = input_data.get("location", "unknown")
        timestamp = input_data.get("timestamp", "unknown")
        latitude = input_data.get("latitude")
        longitude = input_data.get("longitude")

        if (not location or location == "unknown") and latitude is not None and longitude is not None:
            location = f"lat={latitude},lon={longitude}"

        message = "Context unknown"

        if isinstance(location, str):
            if "airport" in location.lower():
                message = "You are at airport, check-in soon"
            elif "hotel" in location.lower():
                message = "You are at hotel, maybe rest and prepare itinerary"
            elif "station" in location.lower():
                message = "You are at station, get ready for departure"

        if latitude is not None and longitude is not None:
            try:
                lat_val = float(latitude)
                lon_val = float(longitude)
                if 12.0 <= lat_val <= 13.0 and 74.0 <= lon_val <= 75.0:
                    message = "You are near Goa region; plan beach activities."
                elif 28.5 <= lat_val <= 29.5 and 77.0 <= lon_val <= 78.0:
                    message = "You are near Delhi; consider cultural heritage visits."
                elif 19.0 <= lat_val <= 20.5 and 72.0 <= lon_val <= 73.5:
                    message = "You are near Mumbai; explore local markets and cuisine."
            except Exception:
                pass

        if timestamp:
            message += f" (time {timestamp})"

        ai_advice = ""
        try:
            prompt = f"User is at {location} at {timestamp}, what should they do next?"
            print(f"ContextAwarenessAgent calling AI with prompt: {prompt}")
            ai_text = generate_ai_response(prompt)
            ai_advice = ai_text or "No AI context advice."
        except Exception as e:
            print(f"ContextAwarenessAgent AI failed: {e}")
            ai_advice = "AI unavailable, using rule-based context advice."

        return {
            "agent": self.name,
            "message": message,
            "ai_insight": ai_advice,
        }


class ExpenseTrackingAgent:
    def __init__(self):
        self.name = "ExpenseTrackingAgent"

    def categorize(self, desc: str) -> str:
        d = desc.lower() if isinstance(desc, str) else ""
        if any(term in d for term in ["food", "restaurant", "dinner", "lunch", "breakfast"]):
            return "food"
        if any(term in d for term in ["taxi", "uber", "flight", "train", "bus", "travel"]):
            return "travel"
        if any(term in d for term in ["hotel", "hostel", "stay", "accommodation"]):
            return "stay"
        return "other"

    def run(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        expenses = input_data.get("expenses", [])

        total = 0.0
        breakdown = {"food": 0.0, "travel": 0.0, "stay": 0.0, "other": 0.0}

        for e in expenses:
            amount = float(e.get("amount", 0))
            desc = e.get("description", "")
            category = e.get("category") or self.categorize(desc)

            if category not in breakdown:
                category = "other"

            breakdown[category] += amount
            total += amount

        suggestion = "Spending looks balanced"
        high_category = max(breakdown, key=breakdown.get)

        if total > 0 and breakdown[high_category] > total * 0.4:
            suggestion = f"Too much spending on {high_category}"

        # AI insight
        ai_advice = ""
        try:
            prompt = (
                f"Analyze this user's expenses and give smart financial advice:\n"
                f"Total: {total}\n"
                f"Breakdown: " + ", ".join([f"{k}={v}" for k, v in breakdown.items()])
            )
            print(f"ExpenseTrackingAgent calling AI with prompt: {prompt}")
            ai_text = generate_ai_response(prompt)
            ai_advice = ai_text or "No AI advice produced."
        except Exception as e:
            print(f"ExpenseTrackingAgent AI failed: {e}")
            ai_advice = "AI unavailable, using rule-based suggestion."

        return {
            "agent": self.name,
            "total": total,
            "breakdown": breakdown,
            "suggestion": suggestion,
            "ai_insight": ai_advice,
        }


class ReminderAgent:
    def __init__(self):
        self.name = "ReminderAgent"

    def run(self, trips: List[Dict[str, Any]]) -> Dict[str, Any]:
        now = datetime.utcnow()
        reminders = []

        for t in trips:
            start_str = t.get("start_date")
            if not start_str:
                continue

            try:
                start = datetime.fromisoformat(start_str)
            except Exception:
                continue

            diff = start - now
            if timedelta(0) <= diff <= timedelta(hours=3):
                reminders.append(f"Trip '{t.get('destination', 'Unknown')}' starts in {diff.seconds//3600}h")

        message = "No immediate trip reminders" if not reminders else "; ".join(reminders)
        return {"agent": self.name, "reminders": reminders, "message": message}


class MemoryAgent:
    def __init__(self):
        self.name = "MemoryAgent"

    def run(self, memories: List[Dict[str, Any]]) -> Dict[str, Any]:
        organized = {}

        for m in memories:
            when = m.get("timestamp")
            date = when[:10] if isinstance(when, str) and len(when) >= 10 else "unknown"
            organized.setdefault(date, []).append(m)

        return {"agent": self.name, "organized": organized, "count": len(memories)}
