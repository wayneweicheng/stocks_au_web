from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
import secrets
import base64
from dotenv import load_dotenv
import os

load_dotenv()

router = APIRouter(prefix="/auth", tags=["auth"])

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    success: bool
    message: str

def get_credentials():
    return {
        "username": os.getenv("ADMIN_USERNAME", "admin"),
        "password": os.getenv("ADMIN_PASSWORD", "password123")
    }

@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest):
    credentials = get_credentials()
    
    if (request.username == credentials["username"] and 
        request.password == credentials["password"]):
        return LoginResponse(success=True, message="Login successful")
    else:
        return LoginResponse(success=False, message="Invalid credentials")

def verify_credentials(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Basic "):
        raise HTTPException(
            status_code=401,
            detail="Missing or invalid authorization header",
            headers={"WWW-Authenticate": "Basic"},
        )
    
    try:
        encoded_credentials = authorization.split(" ")[1]
        decoded_credentials = base64.b64decode(encoded_credentials).decode("utf-8")
        username, password = decoded_credentials.split(":", 1)
    except (ValueError, IndexError):
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header format",
            headers={"WWW-Authenticate": "Basic"},
        )
    
    creds = get_credentials()
    is_correct_username = secrets.compare_digest(username, creds["username"])
    is_correct_password = secrets.compare_digest(password, creds["password"])
    
    if not (is_correct_username and is_correct_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return username