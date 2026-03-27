from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, ForeignKey, Text, DateTime
from sqlalchemy.orm import relationship

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=True)
    phone = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=True)
    auth_provider = Column(String, default="local")
    created_at = Column(DateTime, default=datetime.utcnow)

    trips = relationship("Trip", back_populates="user")


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    destination = Column(String, nullable=False)
    start_date = Column(String, nullable=True)
    end_date = Column(String, nullable=True)
    status = Column(String, default="planned")

    user = relationship("User", back_populates="trips")
    expenses = relationship("Expense", back_populates="trip")
    memories = relationship("Memory", back_populates="trip")
    statuses = relationship("TravelStatus", back_populates="trip")


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=True)
    amount = Column(Float, nullable=False)
    category = Column(String, default="general")
    description = Column(Text, default="")
    timestamp = Column(DateTime, default=datetime.utcnow)

    trip = relationship("Trip", back_populates="expenses")


class TravelStatus(Base):
    __tablename__ = "travel_statuses"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=False)
    location = Column(String, nullable=False)
    status = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    trip = relationship("Trip", back_populates="statuses")


class Memory(Base):
    __tablename__ = "memories"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=True)
    note = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    trip = relationship("Trip", back_populates="memories")


class UserPreference(Base):
    __tablename__ = "user_preferences"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, nullable=False, index=True)
    value = Column(String, nullable=False)


class OTPRequest(Base):
    __tablename__ = "otp_requests"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, nullable=False, index=True)
    otp_code = Column(String, nullable=False)
    expires_at = Column(DateTime, nullable=False)

