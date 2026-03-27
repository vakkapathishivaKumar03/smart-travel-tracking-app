from typing import List, Optional

from sqlalchemy.orm import Session

from models.db_models import User, Trip, Expense, Memory, UserPreference


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()


def create_user(db: Session, name: str, email: str) -> User:
    user = User(name=name, email=email)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def create_trip(db: Session, user_id: int, destination: str, start_date: str = None, end_date: str = None) -> Trip:
    trip = Trip(user_id=user_id, destination=destination, start_date=start_date, end_date=end_date)
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip


def get_trip(db: Session, trip_id: int) -> Optional[Trip]:
    return db.query(Trip).filter(Trip.id == trip_id).first()


def list_trips(db: Session, user_id: int) -> List[Trip]:
    return db.query(Trip).filter(Trip.user_id == user_id).all()


def list_all_trips(db: Session) -> List[Trip]:
    return db.query(Trip).all()


def add_trip_status(db: Session, trip_id: int, location: str, status: str) -> "TravelStatus":
    from models.db_models import TravelStatus

    travel_status = TravelStatus(trip_id=trip_id, location=location, status=status)
    db.add(travel_status)
    db.commit()
    db.refresh(travel_status)
    return travel_status


def get_trip_statuses(db: Session, trip_id: int):
    from models.db_models import TravelStatus

    return db.query(TravelStatus).filter(TravelStatus.trip_id == trip_id).order_by(TravelStatus.timestamp.desc()).all()


def add_expense(db: Session, trip_id: Optional[int], amount: float, category: str = "general", description: str = "") -> Expense:
    expense = Expense(trip_id=trip_id, amount=amount, category=category, description=description)
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense


def get_expenses(db: Session, trip_id: Optional[int] = None) -> List[Expense]:
    query = db.query(Expense)
    if trip_id is not None:
        query = query.filter(Expense.trip_id == trip_id)
    return query.order_by(Expense.timestamp.desc()).all()


def add_memory(db: Session, note: str, trip_id: Optional[int] = None) -> Memory:
    memory = Memory(note=note, trip_id=trip_id)
    db.add(memory)
    db.commit()
    db.refresh(memory)
    return memory


def get_memories(db: Session, trip_id: Optional[int] = None) -> List[Memory]:
    query = db.query(Memory)
    if trip_id is not None:
        query = query.filter(Memory.trip_id == trip_id)
    return query.order_by(Memory.timestamp.desc()).all()


def add_user_preference(db: Session, key: str, value: str) -> UserPreference:
    pref = UserPreference(key=key, value=value)
    db.add(pref)
    db.commit()
    db.refresh(pref)
    return pref


def get_user_preferences(db: Session) -> List[UserPreference]:
    return db.query(UserPreference).all()

