import sys
import traceback
from database import SessionLocal
from routes.auth import register, RegisterRequest

try:
    db = SessionLocal()
    req = RegisterRequest(name="Test3", phone="5554443322", password="mypwd")
    register(req, db)
    print("Success")
except Exception as e:
    with open("error_trace.txt", "w") as f:
        traceback.print_exc(file=f)
