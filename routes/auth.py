from datetime import timedelta, datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from models.db_models import User, OTPRequest
from services.auth import (
    verify_password, 
    get_password_hash, 
    create_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    verify_google_token,
    generate_otp,
    send_sms_otp
)

router = APIRouter(prefix="/auth", tags=["Authentication"])

class RegisterRequest(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None

class LoginRequest(BaseModel):
    phone: Optional[str] = None
    email: Optional[str] = None
    password: str

class SendOTPRequest(BaseModel):
    phone: str

class VerifyOTPRequest(BaseModel):
    phone: str
    otp_code: str

class GoogleLoginRequest(BaseModel):
    id_token: str

@router.post("/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    if not req.phone and not req.email:
        raise HTTPException(status_code=400, detail="Must provide either phone or email.")
    
    # Check existing user
    if req.email:
        existing = db.query(User).filter(User.email == req.email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered.")
    if req.phone:
        existing = db.query(User).filter(User.phone == req.phone).first()
        if existing:
            raise HTTPException(status_code=400, detail="Phone already registered.")
            
    hashed_pwd = get_password_hash(req.password) if req.password else None
    
    new_user = User(
        name=req.name,
        email=req.email,
        phone=req.phone,
        password_hash=hashed_pwd,
        auth_provider="local"
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User registered successfully", "user_id": new_user.id}

@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    if not req.phone and not req.email:
        raise HTTPException(status_code=400, detail="Must provide email or phone.")
        
    user = None
    if req.email:
        user = db.query(User).filter(User.email == req.email).first()
    elif req.phone:
        user = db.query(User).filter(User.phone == req.phone).first()
        
    if not user:
        raise HTTPException(status_code=400, detail="Incorrect credentials")
        
    if not user.password_hash or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect credentials")
        
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "user": {"id": user.id, "name": user.name}}

@router.post("/send-otp")
def send_otp(req: SendOTPRequest, db: Session = Depends(get_db)):
    # Delete old OTPs for this phone
    db.query(OTPRequest).filter(OTPRequest.phone == req.phone).delete()
    
    otp_code = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    
    otp_req = OTPRequest(
        phone=req.phone,
        otp_code=otp_code,
        expires_at=expires_at
    )
    db.add(otp_req)
    db.commit()
    
    # Send SMS via Twilio (or fallback to mock)
    send_sms_otp(req.phone, otp_code)
    
    return {"message": "OTP sent successfully"}

@router.post("/verify-otp")
def verify_otp(req: VerifyOTPRequest, db: Session = Depends(get_db)):
    otp_req = db.query(OTPRequest).filter(
        OTPRequest.phone == req.phone,
        OTPRequest.otp_code == req.otp_code
    ).first()
    
    if not otp_req:
        raise HTTPException(status_code=400, detail="Invalid OTP code")
        
    if datetime.utcnow() > otp_req.expires_at:
        raise HTTPException(status_code=400, detail="OTP code expired")
        
    # Valid OTP. Find user or return error (We could auto-create a user if we wanted, but the prompt says Login using Phone + OTP and Register separately. If user doesn't exist, we send 404).
    user = db.query(User).filter(User.phone == req.phone).first()
    if not user:
        # Instead of erroring, we can return a flag that they need to register
        return {"status": "needs_registration", "phone": req.phone}
        
    # Clean up OTP
    db.delete(otp_req)
    db.commit()
    
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": access_token, "token_type": "bearer", "user": {"id": user.id, "name": user.name}}

@router.post("/google-login")
def google_login(req: GoogleLoginRequest, db: Session = Depends(get_db)):
    idinfo = verify_google_token(req.id_token)
    if not idinfo:
        raise HTTPException(status_code=400, detail="Invalid Google Token")
        
    email = idinfo.get("email")
    name = idinfo.get("name", "Google User")
    
    if not email:
        raise HTTPException(status_code=400, detail="Google token does not contain email")
        
    user = db.query(User).filter(User.email == email).first()
    if not user:
        # Auto register Google user
        user = User(
            name=name,
            email=email,
            auth_provider="google"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": access_token, "token_type": "bearer", "user": {"id": user.id, "name": user.name}}
