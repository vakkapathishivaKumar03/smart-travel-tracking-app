import os
import random
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
import bcrypt
from google.oauth2 import id_token
from google.auth.transport import requests
from dotenv import load_dotenv
from twilio.rest import Client

load_dotenv()

# Optional: Load from environment variables
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

def verify_google_token(token: str) -> dict:
    try:
        if not GOOGLE_CLIENT_ID:
            print("[WARNING] GOOGLE_CLIENT_ID is not set on the backend. Verification might fail or be bypassed for testing.")
            # For testing purposes if Client ID isn't set, we might just try to decode without verification, 
            # BUT google.oauth2 requires audience or skip verification.
            idinfo = id_token.verify_oauth2_token(token, requests.Request())
            return idinfo
            
        idinfo = id_token.verify_oauth2_token(token, requests.Request(), GOOGLE_CLIENT_ID)
        return idinfo
    except ValueError as e:
        print(f"Google Token Verification Failed: {e}")
        return None

def generate_otp() -> str:
    """Generate a 6-digit numeric OTP. Defaults to 123456 if Twilio is unconfigured."""
    if not os.getenv("TWILIO_ACCOUNT_SID"):
        return "123456"
    return str(random.randint(100000, 999999))

def send_sms_otp(phone_number: str, otp_code: str) -> bool:
    """Send OTP via Twilio if configured, else fallback to mock console output."""
    twilio_sid = os.getenv("TWILIO_ACCOUNT_SID")
    twilio_token = os.getenv("TWILIO_AUTH_TOKEN")
    twilio_phone = os.getenv("TWILIO_PHONE_NUMBER")

    if not twilio_sid or not twilio_token or not twilio_phone:
        print(f"\n{'='*40}\n[TWILIO NOT CONFIGURED - MOCK SMS] OTP for {phone_number} is: {otp_code}\n{'='*40}\n")
        return False

    try:
        client = Client(twilio_sid, twilio_token)
        message = client.messages.create(
            body=f"Your TravelPilot verification code is {otp_code}. Valid for 5 minutes.",
            from_=twilio_phone,
            to=phone_number
        )
        print(f"[TWILIO SMS] Successfully sent to {phone_number} (SID: {message.sid})")
        return True
    except Exception as e:
        print(f"[TWILIO ERROR] Failed to send SMS: {e}")
        # Fallback to mock so we're not blocked during dev
        print(f"\n{'='*40}\n[FALLBACK MOCK SMS] OTP for {phone_number} is: {otp_code}\n{'='*40}\n")
        return False
