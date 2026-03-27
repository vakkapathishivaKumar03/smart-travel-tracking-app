import os

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker


def _default_sqlite_url() -> str:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    if os.getenv("VERCEL") == "1":
        db_path = "/tmp/smart_travel.db"
    else:
        db_path = os.path.join(base_dir, "smart_travel.db")
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    return f"sqlite:///{db_path}"


SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", _default_sqlite_url())

connect_args = {}
if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
