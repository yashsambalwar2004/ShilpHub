"""
MurtiTrack - Festival Idol Order Management & Customer Tracking Platform
Master Backend Application (FastAPI + SQLite/PostgreSQL)
"""

import os
import uuid
import secrets
import datetime
import json
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form, Query, Request, status, BackgroundTasks
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from pydantic import BaseModel, Field

import database
import auth
import cleanup_worker
import push_service

# Setup uploads directory
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Only these image types may be uploaded (blocks .html/.svg/.js etc.)
ALLOWED_PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".bmp"}
MAX_PHOTO_BYTES = 8 * 1024 * 1024  # 8 MB


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize Database & Seed
    database.init_db()
    # Start 14-day image cleanup background worker
    cleanup_worker.start_background_cleanup_scheduler(interval_seconds=3600)
    yield
    # Shutdown

app = FastAPI(
    title="MurtiTrack API",
    description="Digital business register and customer order-tracking platform for Indian idol makers.",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for all frontends (Flutter web, Next.js, mobile app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static uploads
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# ----------------------------------------------------------------------------
# PYDANTIC SCHEMAS
# ----------------------------------------------------------------------------

class MurtikarRegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    shop_name: str = Field(..., min_length=2, max_length=100)
    city: str = Field(..., min_length=2, max_length=50)
    area: Optional[str] = None
    phone: str = Field(..., pattern=r"^[6-9]\d{9}$")
    whatsapp_number: Optional[str] = None
    idol_types: List[str] = ["ganesha"]
    experience_years: int = Field(0, ge=0, le=99)
    password: str = Field(..., min_length=6)

class LoginRequest(BaseModel):
    phone: str
    password: str

class CustomerLoginRequest(BaseModel):
    booking_number: str
    phone: str
    credential: str  # PIN (4-6 digits) or password

class BookingCreateRequest(BaseModel):
    customer_name: str = Field(..., min_length=2)
    customer_phone: str = Field(..., pattern=r"^[6-9]\d{9}$")
    festival: str
    idol_type: str = "ganesha"
    size: str
    material: str = "clay"
    total_amount: float = Field(..., gt=0)
    advance_amount: float = Field(0, ge=0)
    advance_received_date: Optional[str] = None
    advance_mode: Optional[str] = "cash"
    advance_note: Optional[str] = None
    expected_delivery_date: str
    notes: Optional[str] = None
    manual_sequence: Optional[str] = None
    # Initial customer credential setup.
    # If no credential is sent, a random 6-digit PIN is generated and returned
    # once in the response so the murtikar can share it with the customer.
    customer_auth_type: str = "pin"  # pin or password
    customer_credential: Optional[str] = None

class BookingUpdateRequest(BaseModel):
    customer_name: Optional[str] = None
    size: Optional[str] = None
    material: Optional[str] = None
    total_amount: Optional[float] = None
    expected_delivery_date: Optional[str] = None
    notes: Optional[str] = None

class AuthorizedPhoneCreateRequest(BaseModel):
    phone_number: str = Field(..., pattern=r"^[6-9]\d{9}$")
    label: str = "buyer"  # buyer, family, friend, other
    auth_type: str = "pin"  # pin or password
    credential: str = Field(..., min_length=4)

class MurtikarBlockPhoneRequest(BaseModel):
    phone_number: str = Field(..., pattern=r"^[6-9]\d{9}$")
    reason: Optional[str] = None

class StatusUpdateRequest(BaseModel):
    status_stage: str
    note: Optional[str] = None

class PaymentCreateRequest(BaseModel):
    amount: float = Field(..., gt=0)
    payment_date: str
    payment_mode: str  # cash, upi, bank_transfer, other
    note: Optional[str] = None

class ChangeRequestCreate(BaseModel):
    change_type: str  # color, ornament, size_adjustment, face_expression, other
    description: str = Field(..., min_length=5, max_length=1000)

class ChangeRequestResponse(BaseModel):
    status: str  # accepted or rejected
    murtikar_response: Optional[str] = None
    extra_charge: float = 0.0

class RatingCreate(BaseModel):
    score: int = Field(..., ge=1, le=10)
    note: Optional[str] = Field(None, max_length=1000)

class MessageCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)

class DeviceTokenRequest(BaseModel):
    fcm_token: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

class AdminReviewRequest(BaseModel):
    reason: Optional[str] = None

# ----------------------------------------------------------------------------
# 1. AUTHENTICATION & REGISTRATION ENDPOINTS
# ----------------------------------------------------------------------------

@app.post("/api/murtikars/register")
def register_murtikar(req: MurtikarRegisterRequest, request: Request):
    """Murtikar self-registration. Sets account to pending for admin approval."""
    conn = database.get_connection()
    c = conn.cursor()

    # Check if phone already registered
    c.execute("SELECT id, status FROM users WHERE phone = ?", (req.phone,))
    existing = c.fetchone()
    if existing:
        conn.close()
        raise HTTPException(status_code=400, detail="An account with this mobile number already exists.")

    user_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    pass_hash = database.hash_credential(req.password)

    c.execute("""
    INSERT INTO users (
        id, name, shop_name, city, area, phone, whatsapp_number,
        idol_types, experience_years, status, role, password_hash,
        created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'murtikar', ?, ?, ?)
    """, (
        user_id, req.name, req.shop_name, req.city, req.area, req.phone,
        req.whatsapp_number or req.phone, json.dumps(req.idol_types),
        req.experience_years, pass_hash, now, now
    ))
    conn.commit()
    conn.close()

    auth.log_audit(
        action="murtikar_registered",
        target_type="user",
        target_id=user_id,
        details={"phone": req.phone, "shop_name": req.shop_name, "city": req.city},
        ip_address=request.client.host if request.client else None
    )

    return {
        "success": True,
        "message": "Registration submitted successfully. Your account is pending admin verification.",
        "user_id": user_id,
        "status": "pending"
    }

@app.post("/api/auth/login")
def login_murtikar_or_admin(req: LoginRequest, request: Request):
    """Login for Murtikars and Platform Admins."""
    ip = request.client.host if request.client else None

    # Check rate limiting
    if not auth.check_rate_limit(req.phone, user_type="murtikar", max_attempts=5, window_minutes=15):
        raise HTTPException(
            status_code=429,
            detail="Too many failed login attempts. Please wait 15 minutes before trying again."
        )

    conn = database.get_connection()
    c = conn.cursor()
    c.execute("""
    SELECT id, name, shop_name, city, phone, role, status, password_hash, rejected_reason
    FROM users WHERE phone = ?
    """, (req.phone,))
    user = c.fetchone()
    conn.close()

    if not user or not database.verify_credential(req.password, user["password_hash"]):
        auth.record_login_attempt(req.phone, success=False, user_type="murtikar", ip=ip)
        auth.log_audit("login_failed", target_type="user", details={"phone": req.phone}, ip_address=ip)
        raise HTTPException(status_code=401, detail="Invalid phone number or password.")

    # Status validation
    if user["status"] == "pending":
        auth.record_login_attempt(req.phone, success=False, user_type="murtikar", ip=ip)
        raise HTTPException(status_code=403, detail="Your account is under admin review. You will receive access once approved.")

    if user["status"] == "rejected":
        auth.record_login_attempt(req.phone, success=False, user_type="murtikar", ip=ip)
        reason = user["rejected_reason"] or "Application did not meet verification criteria."
        raise HTTPException(status_code=403, detail=f"Your account registration was rejected: {reason}")

    if user["status"] == "blocked":
        auth.record_login_attempt(req.phone, success=False, user_type="murtikar", ip=ip)
        raise HTTPException(status_code=403, detail="Your account has been suspended by platform administration.")

    # Success: record attempt and return JWT token
    auth.record_login_attempt(req.phone, success=True, user_type="murtikar", ip=ip)
    auth.log_audit("login_success", actor_id=user["id"], actor_role=user["role"], target_type="user", target_id=user["id"], ip_address=ip)

    token = auth.create_jwt_token({
        "sub": user["id"],
        "name": user["name"],
        "shop_name": user["shop_name"],
        "phone": user["phone"],
        "role": user["role"]
    })

    return {
        "success": True,
        "token": token,
        "user": {
            "id": user["id"],
            "name": user["name"],
            "shop_name": user["shop_name"],
            "phone": user["phone"],
            "role": user["role"],
            "status": user["status"]
        }
    }

@app.post("/api/murtikars/change-password")
def change_password(req: ChangePasswordRequest, current_user: dict = Depends(auth.get_current_user)):
    """Allows a logged-in user to change their password."""
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT password_hash FROM users WHERE id = ?", (current_user["id"],))
    user = c.fetchone()
    
    if not user or not database.verify_credential(req.old_password, user["password_hash"]):
        conn.close()
        raise HTTPException(status_code=400, detail="Incorrect old password.")
        
    new_hash = database.hash_credential(req.new_password)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    c.execute("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?", (new_hash, now, current_user["id"]))
    conn.commit()
    conn.close()
    
    return {"success": True, "message": "Password updated successfully."}

@app.post("/api/auth/customer/login")
def login_customer(req: CustomerLoginRequest, request: Request):
    """
    Customer Tracking Authentication with Strict 7-Step Validation.
    Returns GENERIC error messages on failures to prevent user and booking enumeration.
    """
    ip = request.client.host if request.client else None
    GENERIC_ERROR = "Invalid booking number, phone number, or credential."

    # Step 1: Rate limiting check
    if not auth.check_rate_limit(req.phone, user_type="customer", max_attempts=5, window_minutes=15):
        raise HTTPException(status_code=429, detail="Too many failed tracking attempts. Please wait 15 minutes.")

    conn = database.get_connection()
    c = conn.cursor()

    # Step 2: Lookup booking by booking_number
    c.execute("""
    SELECT b.id, b.booking_number, b.murtikar_id, b.customer_name, b.deleted_at,
           u.status as murtikar_status
    FROM bookings b
    JOIN users u ON b.murtikar_id = u.id
    WHERE UPPER(b.booking_number) = UPPER(?)
    """, (req.booking_number.strip(),))
    booking = c.fetchone()

    if not booking:
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    # Step 3: Check booking deleted_at is null
    if booking["deleted_at"] is not None:
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    # Step 4: Check murtikar account status
    if booking["murtikar_status"] != "approved":
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    # Step 5: Check murtikar workshop-wide block list
    c.execute("""
    SELECT 1 FROM murtikar_block_list
    WHERE murtikar_id = ? AND phone_number = ?
    """, (booking["murtikar_id"], req.phone.strip()))
    if c.fetchone():
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    # Step 6: Check phone in booking_authorized_phones and not blocked
    c.execute("""
    SELECT id, label, auth_type, password_hash, pin_hash, is_blocked
    FROM booking_authorized_phones
    WHERE booking_id = ? AND phone_number = ?
    """, (booking["id"], req.phone.strip()))
    auth_phone = c.fetchone()

    if not auth_phone or auth_phone["is_blocked"] == 1:
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    # Step 7: Verify credential hash
    stored_hash = auth_phone["pin_hash"] if auth_phone["auth_type"] == "pin" else auth_phone["password_hash"]
    if not stored_hash or not database.verify_credential(req.credential.strip(), stored_hash):
        auth.record_login_attempt(req.phone, success=False, user_type="customer", ip=ip)
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_ERROR)

    conn.close()

    # Successful customer authentication
    auth.record_login_attempt(req.phone, success=True, user_type="customer", ip=ip)
    auth.log_audit(
        action="customer_login_success",
        target_type="booking",
        target_id=booking["id"],
        details={"phone": req.phone, "booking_number": booking["booking_number"]},
        ip_address=ip
    )

    token = auth.create_jwt_token({
        "role": "customer",
        "booking_id": booking["id"],
        "booking_number": booking["booking_number"],
        "phone": req.phone.strip(),
        "label": auth_phone["label"]
    }, expires_in_seconds=86400 * 2)

    return {
        "success": True,
        "token": token,
        "booking_number": booking["booking_number"],
        "customer_name": booking["customer_name"],
        "phone": req.phone.strip()
    }

def _resolve_push_identity(request: Request):
    """
    Works for BOTH murtikar and customer tokens.
    Returns (user_type, user_identifier):
      - murtikar -> ("murtikar", user_id)
      - customer -> ("customer", phone)
    Re-uses the real auth dependencies so all access checks still apply.
    """
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing authorization token")
    token = header.split(" ", 1)[1].strip()
    payload = auth.decode_jwt_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    if payload.get("role") == "customer":
        customer = auth.get_current_customer(creds)
        return "customer", customer["customer_phone"]

    user = auth.get_current_user(creds)
    return user["role"], user["id"]


@app.post("/api/auth/device-token")
def register_device_token(req: DeviceTokenRequest, request: Request):
    user_type, user_identifier = _resolve_push_identity(request)
    fcm_token = req.fcm_token.strip()
    if not fcm_token:
        raise HTTPException(status_code=400, detail="fcm_token is required")

    conn = database.get_connection()
    c = conn.cursor()
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()

    try:
        # A device token belongs to ONE logged-in user at a time. If someone else
        # was previously registered on this device, remove that association.
        c.execute(
            "DELETE FROM device_tokens WHERE fcm_token = ? AND user_identifier != ?",
            (fcm_token, user_identifier),
        )

        # Manual upsert: does not depend on a UNIQUE constraint existing in the table
        c.execute(
            "SELECT id FROM device_tokens WHERE user_identifier = ? AND fcm_token = ?",
            (user_identifier, fcm_token),
        )
        existing = c.fetchone()
        if existing:
            c.execute(
                "UPDATE device_tokens SET user_type = ?, updated_at = ? WHERE id = ?",
                (user_type, now_iso, existing["id"]),
            )
        else:
            c.execute("""
            INSERT INTO device_tokens (id, user_identifier, user_type, fcm_token, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """, (str(uuid.uuid4()), user_identifier, user_type, fcm_token, now_iso, now_iso))
        conn.commit()
    except Exception as e:
        print(f"[device-token] failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to register device token")
    finally:
        conn.close()
    return {"success": True, "message": "Device token registered"}


@app.post("/api/auth/device-token/remove")
def remove_device_token(req: DeviceTokenRequest, request: Request):
    """Called on logout so a shared phone stops receiving the previous user's notifications."""
    _, user_identifier = _resolve_push_identity(request)
    conn = database.get_connection()
    try:
        c = conn.cursor()
        c.execute(
            "DELETE FROM device_tokens WHERE fcm_token = ? AND user_identifier = ?",
            (req.fcm_token.strip(), user_identifier),
        )
        conn.commit()
    finally:
        conn.close()
    return {"success": True, "message": "Device token removed"}


# ----------------------------------------------------------------------------
# 2. PLATFORM ADMIN ENDPOINTS
# ----------------------------------------------------------------------------

@app.get("/api/admin/murtikars/pending")
def list_pending_murtikars(admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("""
    SELECT id, name, shop_name, city, area, phone, whatsapp_number, idol_types,
           experience_years, shop_photo_path, id_proof_path, created_at
    FROM users WHERE role = 'murtikar' AND status = 'pending'
    ORDER BY created_at ASC
    """)
    rows = c.fetchall()
    conn.close()
    return [{"id": r["id"], "name": r["name"], "shop_name": r["shop_name"], "city": r["city"],
             "area": r["area"], "phone": r["phone"], "whatsapp_number": r["whatsapp_number"],
             "idol_types": json.loads(r["idol_types"]) if r["idol_types"] else [],
             "experience_years": r["experience_years"], "created_at": r["created_at"]} for r in rows]

@app.get("/api/admin/murtikars")
def list_all_murtikars(
    status: Optional[str] = None,
    admin: Dict[str, Any] = Depends(auth.require_admin)
):
    conn = database.get_connection()
    c = conn.cursor()
    query = "SELECT id, name, shop_name, city, phone, status, experience_years, created_at FROM users WHERE role = 'murtikar'"
    params = []
    if status:
        query += " AND status = ?"
        params.append(status)
    query += " ORDER BY created_at DESC"
    c.execute(query, params)
    rows = c.fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/api/admin/murtikars/{user_id}/approve")
def approve_murtikar(user_id: str, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("UPDATE users SET status = 'approved', updated_at = ? WHERE id = ? AND role = 'murtikar'",
              (datetime.datetime.now(datetime.timezone.utc).isoformat(), user_id))
    conn.commit()
    conn.close()
    auth.log_audit("murtikar_approved", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id)
    return {"success": True, "message": "Murtikar account approved successfully."}

@app.post("/api/admin/murtikars/{user_id}/reject")
def reject_murtikar(user_id: str, req: AdminReviewRequest, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("UPDATE users SET status = 'rejected', rejected_reason = ?, updated_at = ? WHERE id = ? AND role = 'murtikar'",
              (req.reason or "Application rejected by admin.", datetime.datetime.now(datetime.timezone.utc).isoformat(), user_id))
    conn.commit()
    conn.close()
    auth.log_audit("murtikar_rejected", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id, details={"reason": req.reason})
    return {"success": True, "message": "Murtikar application rejected."}

@app.post("/api/admin/murtikars/{user_id}/block")
def block_murtikar(user_id: str, req: AdminReviewRequest, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("UPDATE users SET status = 'blocked', rejected_reason = ?, updated_at = ? WHERE id = ? AND role = 'murtikar'",
              (req.reason or "Account suspended.", datetime.datetime.now(datetime.timezone.utc).isoformat(), user_id))
    conn.commit()
    conn.close()
    auth.log_audit("murtikar_blocked", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id)
    return {"success": True, "message": "Murtikar account blocked."}

@app.post("/api/admin/murtikars/{user_id}/unblock")
def unblock_murtikar(user_id: str, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("UPDATE users SET status = 'approved', rejected_reason = NULL, updated_at = ? WHERE id = ? AND role = 'murtikar'",
              (datetime.datetime.now(datetime.timezone.utc).isoformat(), user_id))
    conn.commit()
    conn.close()
    auth.log_audit("murtikar_unblocked", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id)
    return {"success": True, "message": "Murtikar account unblocked."}

class AdminResetPasswordRequest(BaseModel):
    new_password: str

@app.post("/api/admin/murtikars/{user_id}/reset-password")
def admin_reset_password(user_id: str, req: AdminResetPasswordRequest, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT id FROM users WHERE id = ? AND role = 'murtikar'", (user_id,))
    if not c.fetchone():
        conn.close()
        raise HTTPException(status_code=404, detail="Murtikar not found.")
        
    new_pass = req.new_password.strip()
    if not new_pass:
        new_pass = "ShilpHub123"
        
    new_hash = database.hash_credential(new_pass)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    c.execute("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?", (new_hash, now, user_id))
    conn.commit()
    conn.close()
    
    auth.log_audit("murtikar_password_reset", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id)
    return {"success": True, "message": f"Password reset to '{new_pass}' successfully."}

@app.delete("/api/admin/murtikars/{user_id}")
def delete_murtikar(user_id: str, admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    
    # Fetch phone to clean up orphaned records
    c.execute("SELECT phone FROM users WHERE id = ? AND role = 'murtikar'", (user_id,))
    user = c.fetchone()
    if not user:
        conn.close()
        raise HTTPException(status_code=404, detail="Murtikar not found.")
        
    phone = user["phone"]
    
    # Explicitly clear orphaned data not covered by foreign keys
    c.execute("DELETE FROM device_tokens WHERE user_identifier = ? OR user_identifier = ?", (user_id, phone))
    c.execute("DELETE FROM login_attempts WHERE phone = ?", (phone,))
    c.execute("DELETE FROM booking_counters WHERE murtikar_id = ?", (user_id,))
    
    # Delete the user (ON DELETE CASCADE will handle bookings, etc.)
    c.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    
    auth.log_audit("murtikar_deleted", actor_id=admin["id"], actor_role="platform_admin", target_type="user", target_id=user_id, details={"phone": phone})
    return {"success": True, "message": "Murtikar account and all related data permanently deleted."}

@app.get("/api/admin/metrics")
def get_admin_metrics(admin: Dict[str, Any] = Depends(auth.require_admin)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM users WHERE role = 'murtikar'")
    total_murtikars = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM users WHERE role = 'murtikar' AND status = 'pending'")
    pending_murtikars = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM bookings WHERE deleted_at IS NULL")
    active_bookings = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM bookings WHERE current_status = 'delivered'")
    delivered_bookings = c.fetchone()[0]
    c.execute("SELECT COALESCE(SUM(total_amount), 0) FROM bookings WHERE deleted_at IS NULL")
    total_order_value = c.fetchone()[0]
    c.execute("SELECT COALESCE(SUM(amount), 0) FROM payments")
    total_collections = c.fetchone()[0]
    conn.close()

    return {
        "total_murtikars": total_murtikars,
        "pending_murtikars": pending_murtikars,
        "active_bookings": active_bookings,
        "delivered_bookings": delivered_bookings,
        "total_order_value": total_order_value,
        "total_collections": total_collections
    }

@app.get("/api/admin/audit-logs")
def get_audit_logs(
    limit: int = 50,
    admin: Dict[str, Any] = Depends(auth.require_admin)
):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT ?", (limit,))
    rows = c.fetchall()
    conn.close()
    return [dict(r) for r in rows]

# ----------------------------------------------------------------------------
# 3. MURTIKAR BOOKINGS ENDPOINTS
# ----------------------------------------------------------------------------

def generate_booking_number(murtikar_id: str, conn) -> str:
    """Generates per-murtikar sequential number MUR-YYYY-XXXXX ensuring global uniqueness."""
    c = conn.cursor()
    c.execute("INSERT OR IGNORE INTO booking_counters VALUES (?, 0)", (murtikar_id,))
    c.execute("UPDATE booking_counters SET last_number = last_number + 1 WHERE murtikar_id = ?", (murtikar_id,))
    c.execute("SELECT last_number FROM booking_counters WHERE murtikar_id = ?", (murtikar_id,))
    num = c.fetchone()[0]
    year = datetime.datetime.now().year

    candidate = f"MUR-{year}-{num:05d}"
    c.execute("SELECT 1 FROM bookings WHERE booking_number = ?", (candidate,))
    while c.fetchone():
        num += 1
        candidate = f"MUR-{year}-{num:05d}"
        c.execute("SELECT 1 FROM bookings WHERE booking_number = ?", (candidate,))

    c.execute("UPDATE booking_counters SET last_number = ? WHERE murtikar_id = ?", (num, murtikar_id))
    return candidate

@app.post("/api/bookings")
def create_booking(
    req: BookingCreateRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """Creates a new booking, generates booking number, registers primary phone, and syncs advance payment."""
    if req.advance_amount > req.total_amount:
        raise HTTPException(status_code=400, detail="Advance amount cannot exceed total booking amount.")

    # Validate / prepare the customer's login credential
    auth_type = req.customer_auth_type
    if auth_type not in ("pin", "password"):
        raise HTTPException(status_code=400, detail="customer_auth_type must be 'pin' or 'password'.")

    credential = (req.customer_credential or "").strip()
    generated_pin = None
    if not credential:
        if auth_type == "password":
            raise HTTPException(status_code=400, detail="Customer password is required.")
        # No PIN supplied: generate a random 6-digit PIN (returned once in the response)
        generated_pin = str(secrets.randbelow(900000) + 100000)
        credential = generated_pin
    elif auth_type == "pin" and not (credential.isdigit() and 4 <= len(credential) <= 6):
        raise HTTPException(status_code=400, detail="PIN must be 4 to 6 digits.")
    elif auth_type == "password" and len(credential) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters.")

    conn = database.get_connection()
    c = conn.cursor()

    booking_id = str(uuid.uuid4())
    if req.manual_sequence:
        if not req.manual_sequence.isdigit() or len(req.manual_sequence) > 10 or len(req.manual_sequence) == 0:
            raise HTTPException(status_code=400, detail="Manual sequence must be a number (1 to 10 digits).")
        year = datetime.datetime.now().year
        # Pad it to 5 digits so it matches MUR-YYYY-XXXXX format consistently.
        manual_num = int(req.manual_sequence)
        booking_number = f"MUR-{year}-{manual_num:05d}"
        c.execute("SELECT 1 FROM bookings WHERE booking_number = ?", (booking_number,))
        if c.fetchone():
            raise HTTPException(status_code=400, detail=f"Booking number {booking_number} already exists.")
            
        # Update the counter so auto-generation continues from this manual number
        c.execute("INSERT OR IGNORE INTO booking_counters VALUES (?, 0)", (current_user["id"],))
        c.execute("SELECT last_number FROM booking_counters WHERE murtikar_id = ?", (current_user["id"],))
        row = c.fetchone()
        current_max = row[0] if row else 0
        if manual_num > current_max:
            c.execute("UPDATE booking_counters SET last_number = ? WHERE murtikar_id = ?", (manual_num, current_user["id"]))
    else:
        booking_number = generate_booking_number(current_user["id"], conn)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    advance_date = req.advance_received_date or datetime.date.today().isoformat()

    c.execute("""
    INSERT INTO bookings (
        id, booking_number, murtikar_id, customer_name, customer_phone,
        festival, idol_type, size, material, total_amount, advance_amount,
        advance_received_date, advance_mode, advance_note, current_status,
        expected_delivery_date, notes, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'booking_confirmed', ?, ?, ?, ?)
    """, (
        booking_id, booking_number, current_user["id"], req.customer_name,
        req.customer_phone, req.festival, req.idol_type, req.size,
        req.material, req.total_amount, req.advance_amount, advance_date,
        req.advance_mode, req.advance_note, req.expected_delivery_date,
        req.notes, now, now
    ))

    # Auto-register advance payment in payments table
    if req.advance_amount > 0:
        c.execute("""
        INSERT INTO payments (id, booking_id, amount, payment_date, payment_mode, note, is_advance, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
        """, (
            str(uuid.uuid4()), booking_id, req.advance_amount, advance_date,
            req.advance_mode or "cash", req.advance_note or "Advance at booking", now, now
        ))

    # Register initial customer authorized phone
    cred_hash = database.hash_credential(credential)
    c.execute("""
    INSERT INTO booking_authorized_phones (
        id, booking_id, phone_number, label, auth_type, pin_hash, password_hash, is_primary, is_blocked, created_at, updated_at
    ) VALUES (?, ?, ?, 'buyer', ?, ?, ?, 1, 0, ?, ?)
    """, (
        str(uuid.uuid4()), booking_id, req.customer_phone, auth_type,
        cred_hash if auth_type == "pin" else None,
        cred_hash if auth_type == "password" else None,
        now, now
    ))

    # Initial status update record
    c.execute("""
    INSERT INTO status_updates (id, booking_id, status_stage, note, created_at)
    VALUES (?, ?, 'booking_confirmed', 'Order confirmed in register.', ?)
    """, (str(uuid.uuid4()), booking_id, now))

    conn.commit()
    conn.close()

    auth.log_audit("booking_created", actor_id=current_user["id"], actor_role=current_user["role"], target_type="booking", target_id=booking_id, details={"booking_number": booking_number})

    response = {
        "success": True,
        "booking_id": booking_id,
        "booking_number": booking_number,
        "message": f"Booking {booking_number} registered successfully."
    }
    if generated_pin:
        # Shown only once. Share this PIN with the customer for order tracking.
        response["customer_pin"] = generated_pin
        response["message"] += f" Customer tracking PIN: {generated_pin}"
    return response

@app.get("/api/bookings")
def list_bookings(
    festival: Optional[str] = None,
    stage: Optional[str] = None,
    search: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """Lists bookings for the authenticated murtikar with filtering & summary stats."""
    conn = database.get_connection()
    c = conn.cursor()

    query = """
    SELECT b.*,
           (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = b.id) as total_paid,
           (SELECT COUNT(*) FROM change_requests WHERE booking_id = b.id AND status = 'pending') as pending_changes
    FROM bookings b
    WHERE b.murtikar_id = ? AND b.deleted_at IS NULL
    """
    params = [current_user["id"]]

    if festival:
        query += " AND b.festival = ?"
        params.append(festival)
    if stage:
        query += " AND b.current_status = ?"
        params.append(stage)
    if search:
        search_pattern = f"%{search}%"
        query += " AND (b.customer_name LIKE ? OR b.customer_phone LIKE ? OR b.booking_number LIKE ?)"
        params.extend([search_pattern, search_pattern, search_pattern])

    query += " ORDER BY b.created_at DESC"
    c.execute(query, params)
    rows = c.fetchall()

    bookings = []
    total_revenue = 0.0
    total_received = 0.0

    for r in rows:
        d = dict(r)
        d["balance_due"] = max(0.0, d["total_amount"] - d["total_paid"])
        total_revenue += d["total_amount"]
        total_received += d["total_paid"]
        bookings.append(d)

    conn.close()

    return {
        "count": len(bookings),
        "total_revenue": total_revenue,
        "total_received": total_received,
        "total_pending_balance": max(0.0, total_revenue - total_received),
        "bookings": bookings
    }

@app.get("/api/bookings/{booking_id}")
def get_booking_details(
    booking_id: str,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """Returns complete booking record, authorized phones, payments, timeline, and change requests."""
    conn = database.get_connection()
    c = conn.cursor()

    c.execute("SELECT * FROM bookings WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL", (booking_id, current_user["id"]))
    booking = c.fetchone()
    if not booking:
        conn.close()
        raise HTTPException(status_code=404, detail="Booking not found.")

    booking_dict = dict(booking)

    # Authorized phones
    c.execute("SELECT id, phone_number, label, auth_type, is_primary, is_blocked, created_at FROM booking_authorized_phones WHERE booking_id = ?", (booking_id,))
    booking_dict["authorized_phones"] = [dict(r) for r in c.fetchall()]

    # Payments
    c.execute("SELECT * FROM payments WHERE booking_id = ? ORDER BY payment_date ASC", (booking_id,))
    payments = [dict(r) for r in c.fetchall()]
    booking_dict["payments"] = payments
    total_paid = sum(p["amount"] for p in payments)
    booking_dict["total_paid"] = total_paid
    booking_dict["balance_due"] = max(0.0, booking_dict["total_amount"] - total_paid)

    # Status updates
    c.execute("SELECT * FROM status_updates WHERE booking_id = ? ORDER BY created_at ASC", (booking_id,))
    booking_dict["status_history"] = [dict(r) for r in c.fetchall()]

    # Change requests
    c.execute("SELECT * FROM change_requests WHERE booking_id = ? ORDER BY created_at DESC", (booking_id,))
    booking_dict["change_requests"] = [dict(r) for r in c.fetchall()]

    # Rating if present
    c.execute("SELECT score, note, created_at FROM ratings WHERE booking_id = ? AND visible_to_murtikar = 1", (booking_id,))
    rating = c.fetchone()
    booking_dict["rating"] = dict(rating) if rating else None

    conn.close()
    return booking_dict

@app.put("/api/bookings/{booking_id}")
def update_booking(
    booking_id: str,
    req: BookingUpdateRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()

    updates = []
    params = []
    if req.customer_name is not None:
        updates.append("customer_name = ?")
        params.append(req.customer_name)
    if req.size is not None:
        updates.append("size = ?")
        params.append(req.size)
    if req.material is not None:
        updates.append("material = ?")
        params.append(req.material)
    if req.total_amount is not None:
        updates.append("total_amount = ?")
        params.append(req.total_amount)
    if req.expected_delivery_date is not None:
        updates.append("expected_delivery_date = ?")
        params.append(req.expected_delivery_date)
    if req.notes is not None:
        updates.append("notes = ?")
        params.append(req.notes)

    if not updates:
        conn.close()
        return {"success": True, "message": "No changes requested."}

    updates.append("updated_at = ?")
    params.append(datetime.datetime.now(datetime.timezone.utc).isoformat())
    params.extend([booking_id, current_user["id"]])

    query = f"UPDATE bookings SET {', '.join(updates)} WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL"
    c.execute(query, params)
    conn.commit()
    conn.close()

    auth.log_audit("booking_updated", actor_id=current_user["id"], target_type="booking", target_id=booking_id)
    return {"success": True, "message": "Booking details updated."}

@app.delete("/api/bookings/{booking_id}")
def delete_booking(
    booking_id: str,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """Soft deletes a booking."""
    conn = database.get_connection()
    c = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    c.execute("UPDATE bookings SET deleted_at = ? WHERE id = ? AND murtikar_id = ?", (now, booking_id, current_user["id"]))
    conn.commit()
    conn.close()
    auth.log_audit("booking_deleted", actor_id=current_user["id"], target_type="booking", target_id=booking_id)
    return {"success": True, "message": "Booking deleted successfully."}

# ----------------------------------------------------------------------------
# 4. AUTHORIZED PHONES MANAGEMENT
# ----------------------------------------------------------------------------

@app.post("/api/bookings/{booking_id}/phones")
def add_authorized_phone(
    booking_id: str,
    req: AuthorizedPhoneCreateRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()

    # Verify ownership
    c.execute("SELECT id FROM bookings WHERE id = ? AND murtikar_id = ?", (booking_id, current_user["id"]))
    if not c.fetchone():
        conn.close()
        raise HTTPException(status_code=404, detail="Booking not found.")

    cred_hash = database.hash_credential(req.credential)
    phone_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    try:
        c.execute("""
        INSERT INTO booking_authorized_phones (
            id, booking_id, phone_number, label, auth_type,
            pin_hash, password_hash, is_primary, is_blocked, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)
        """, (
            phone_id, booking_id, req.phone_number, req.label, req.auth_type,
            cred_hash if req.auth_type == "pin" else None,
            cred_hash if req.auth_type == "password" else None,
            now, now
        ))
        conn.commit()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=400, detail="This phone number is already authorized for this booking.")

    conn.close()
    auth.log_audit("phone_authorized", actor_id=current_user["id"], target_type="booking_authorized_phones", target_id=phone_id, details={"phone": req.phone_number, "label": req.label})
    return {"success": True, "message": f"Authorized access for {req.phone_number} ({req.label})."}

@app.delete("/api/bookings/{booking_id}/phones/{phone_id}")
def remove_authorized_phone(
    booking_id: str,
    phone_id: str,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("""
    DELETE FROM booking_authorized_phones
    WHERE id = ? AND booking_id IN (SELECT id FROM bookings WHERE id = ? AND murtikar_id = ?)
    """, (phone_id, booking_id, current_user["id"]))
    conn.commit()
    conn.close()
    auth.log_audit("phone_removed", actor_id=current_user["id"], target_type="booking_authorized_phones", target_id=phone_id)
    return {"success": True, "message": "Phone authorization removed."}

@app.post("/api/bookings/{booking_id}/phones/{phone_id}/toggle-block")
def toggle_phone_block(
    booking_id: str,
    phone_id: str,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("""
    SELECT is_blocked FROM booking_authorized_phones
    WHERE id = ? AND booking_id IN (SELECT id FROM bookings WHERE id = ? AND murtikar_id = ?)
    """, (phone_id, booking_id, current_user["id"]))
    row = c.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Phone authorization record not found.")

    new_val = 0 if row["is_blocked"] == 1 else 1
    c.execute("UPDATE booking_authorized_phones SET is_blocked = ?, updated_at = ? WHERE id = ?",
              (new_val, datetime.datetime.now(datetime.timezone.utc).isoformat(), phone_id))
    conn.commit()
    conn.close()
    status_str = "blocked" if new_val == 1 else "unblocked"
    auth.log_audit(f"phone_{status_str}", actor_id=current_user["id"], target_type="booking_authorized_phones", target_id=phone_id)
    return {"success": True, "is_blocked": bool(new_val), "message": f"Phone access {status_str}."}

# ----------------------------------------------------------------------------
# 5. WORKSHOP-WIDE BLOCK LIST
# ----------------------------------------------------------------------------

@app.get("/api/murtikar/block-list")
def list_blocked_phones(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM murtikar_block_list WHERE murtikar_id = ? ORDER BY created_at DESC", (current_user["id"],))
    rows = [dict(r) for r in c.fetchall()]
    conn.close()
    return rows

@app.post("/api/murtikar/block-list")
def block_phone_workshop_wide(
    req: MurtikarBlockPhoneRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()
    try:
        c.execute("""
        INSERT INTO murtikar_block_list (id, murtikar_id, phone_number, reason, created_at)
        VALUES (?, ?, ?, ?, ?)
        """, (
            str(uuid.uuid4()), current_user["id"], req.phone_number,
            req.reason or "Blocked by workshop owner",
            datetime.datetime.now(datetime.timezone.utc).isoformat()
        ))
        conn.commit()
    except Exception:
        conn.close()
        return {"success": True, "message": "Phone number is already on your block list."}

    conn.close()
    auth.log_audit("murtikar_wide_block", actor_id=current_user["id"], target_type="murtikar_block_list", details={"phone": req.phone_number})
    return {"success": True, "message": f"Phone {req.phone_number} blocked across all your orders."}

@app.delete("/api/murtikar/block-list/{phone_number}")
def unblock_phone_workshop_wide(
    phone_number: str,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("DELETE FROM murtikar_block_list WHERE murtikar_id = ? AND phone_number = ?", (current_user["id"], phone_number))
    conn.commit()
    conn.close()
    auth.log_audit("murtikar_wide_unblock", actor_id=current_user["id"], target_type="murtikar_block_list", details={"phone": phone_number})
    return {"success": True, "message": f"Phone {phone_number} removed from workshop block list."}

# ----------------------------------------------------------------------------
# 6. PRODUCTION STATUS & TIMELINE
# ----------------------------------------------------------------------------

@app.post("/api/bookings/{booking_id}/status")
async def update_production_status(
    booking_id: str,
    background_tasks: BackgroundTasks,
    status_stage: str = Form(...),
    note: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    # Validate the photo BEFORE touching the database
    photo_ext = None
    photo_contents = None
    if photo and photo.filename:
        raw_ext = os.path.splitext(photo.filename)[1].lower()
        if raw_ext in ALLOWED_PHOTO_EXTENSIONS:
            photo_ext = raw_ext
        else:
            photo_ext = ".jpg"  # Default extension for cache files from mobile image pickers

        # Accept image/* as well as application/octet-stream (standard for Flutter/mobile multipart file pickers)
        ct = (photo.content_type or "").lower()
        if ct and not ct.startswith("image/") and ct not in {"application/octet-stream", "binary/octet-stream", "application/x-www-form-urlencoded"}:
            raise HTTPException(status_code=400, detail="Uploaded file must be an image.")

        photo_contents = await photo.read()
        if len(photo_contents) > MAX_PHOTO_BYTES:
            raise HTTPException(status_code=400, detail="Image is too large (max 8 MB).")
        if len(photo_contents) == 0:
            photo_contents = None
            photo_ext = None

    conn = database.get_connection()
    c = conn.cursor()

    # Validate ownership
    c.execute("SELECT id, booking_number, customer_phone FROM bookings WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL", (booking_id, current_user["id"]))
    booking = c.fetchone()
    if not booking:
        conn.close()
        raise HTTPException(status_code=404, detail="Booking not found.")

    photo_url = None
    now = datetime.datetime.now(datetime.timezone.utc)
    now_iso = now.isoformat()

    # Save photo if uploaded (with 14-day retention tracking)
    if photo_contents is not None:
        photo_filename = f"{uuid.uuid4()}{photo_ext}"
        save_path = os.path.join(UPLOAD_DIR, photo_filename)
        with open(save_path, "wb") as f:
            f.write(photo_contents)
        photo_url = f"/uploads/{photo_filename}"

        expires_at = (now + datetime.timedelta(days=14)).isoformat()
        c.execute("""
        INSERT INTO booking_photos (id, booking_id, storage_path, file_size_bytes, mime_type, uploaded_at, expires_at, cleanup_status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'active')
        """, (
            str(uuid.uuid4()), booking_id, save_path, len(photo_contents), photo.content_type or "image/jpeg",
            now_iso, expires_at
        ))

    # Record status update
    update_id = str(uuid.uuid4())
    c.execute("""
    INSERT INTO status_updates (id, booking_id, status_stage, note, photo_url, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
    """, (update_id, booking_id, status_stage, note, photo_url, now_iso))

    c.execute("UPDATE bookings SET current_status = ?, updated_at = ? WHERE id = ?", (status_stage, now_iso, booking_id))
    conn.commit()
    conn.close()

    auth.log_audit("status_updated", actor_id=current_user["id"], target_type="status_update", target_id=update_id, details={"stage": status_stage})

    # TRIGGER PUSH NOTIFICATION (real FCM, sent in the background)
    stage_labels = {"ready_for_pickup": "ready for pickup", "delivered": "delivered"}
    if status_stage in stage_labels:
        try:
            conn = database.get_connection()
            c = conn.cursor()
            c.execute(
                """
                SELECT dt.fcm_token FROM device_tokens dt
                JOIN booking_authorized_phones p ON p.phone_number = dt.user_identifier
                WHERE p.booking_id = ? AND p.is_blocked = 0 AND dt.user_type = 'customer'
                """,
                (booking_id,),
            )
            tokens = [r["fcm_token"] for r in c.fetchall()]
            conn.close()
            if tokens:
                background_tasks.add_task(
                    push_service.send_push,
                    tokens,
                    "Order update",
                    f"Your idol {booking['booking_number']} is {stage_labels[status_stage]}.",
                    {"type": "status", "booking_id": booking_id, "recipient_type": "customer"},
                )
        except Exception as e:
            print(f"[push] status notification lookup failed: {e}")

    return {"success": True, "current_status": status_stage, "message": "Production stage updated successfully."}

# ----------------------------------------------------------------------------
# 7. PAYMENTS MANAGEMENT & SUMMARY
# ----------------------------------------------------------------------------

@app.post("/api/bookings/{booking_id}/payments")
def record_payment(
    booking_id: str,
    req: PaymentCreateRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    conn = database.get_connection()
    c = conn.cursor()

    # Verify ownership and check total amount
    c.execute("SELECT total_amount FROM bookings WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL", (booking_id, current_user["id"]))
    booking = c.fetchone()
    if not booking:
        conn.close()
        raise HTTPException(status_code=404, detail="Booking not found.")

    total_amount = booking["total_amount"]

    # Calculate already paid
    c.execute("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = ?", (booking_id,))
    total_paid_so_far = c.fetchone()[0]

    if total_paid_so_far + req.amount > total_amount:
        conn.close()
        max_allowed = max(0.0, total_amount - total_paid_so_far)
        raise HTTPException(
            status_code=400,
            detail=f"Payment of ₹{req.amount:,.2f} exceeds remaining balance. Maximum payable is ₹{max_allowed:,.2f}."
        )

    payment_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    c.execute("""
    INSERT INTO payments (id, booking_id, amount, payment_date, payment_mode, note, is_advance, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
    """, (
        payment_id, booking_id, req.amount, req.payment_date, req.payment_mode,
        req.note, now, now
    ))
    conn.commit()
    conn.close()

    auth.log_audit("payment_created", actor_id=current_user["id"], target_type="payment", target_id=payment_id, details={"amount": req.amount, "mode": req.payment_mode})
    return {"success": True, "message": f"Payment of ₹{req.amount:,.2f} recorded via {req.payment_mode.upper()}."}

@app.get("/api/murtikar/payment-summaries")
def get_payment_summaries(
    festival: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """
    Mode-wise aggregated payment summary for the murtikar.
    Uses unified payments table to ensure NO DOUBLE COUNTING of advance payments.
    """
    conn = database.get_connection()
    c = conn.cursor()

    query = """
    SELECT p.payment_mode,
           COUNT(*) as transaction_count,
           SUM(p.amount) as total_amount
    FROM payments p
    JOIN bookings b ON p.booking_id = b.id
    WHERE b.murtikar_id = ? AND b.deleted_at IS NULL
    """
    params = [current_user["id"]]

    if festival:
        query += " AND b.festival = ?"
        params.append(festival)

    query += " GROUP BY p.payment_mode ORDER BY total_amount DESC"
    c.execute(query, params)
    rows = c.fetchall()

    mode_summaries = {}
    grand_total = 0.0
    for r in rows:
        mode = r["payment_mode"]
        tot = r["total_amount"]
        mode_summaries[mode] = {
            "transactions": r["transaction_count"],
            "total": tot
        }
        grand_total += tot

    conn.close()
    return {
        "grand_total": grand_total,
        "mode_breakdown": mode_summaries
    }

# ----------------------------------------------------------------------------
# 8. CUSTOMER ORDER TRACKING PORTAL (Read-Only)
# ----------------------------------------------------------------------------

@app.get("/api/customer/booking")
def get_customer_booking_view(customer: Dict[str, Any] = Depends(auth.get_current_customer)):
    """
    Strictly isolated read-only customer tracking view.
    Re-verifies all 7 checks on every request via get_current_customer dependency.
    """
    conn = database.get_connection()
    c = conn.cursor()

    # Booking information
    c.execute("""
    SELECT b.id, b.booking_number, b.customer_name, b.festival, b.idol_type,
           b.size, b.material, b.total_amount, b.current_status, b.expected_delivery_date,
           b.notes,
           u.name as murtikar_name, u.shop_name, u.city, u.area, u.phone as murtikar_phone,
           u.whatsapp_number
    FROM bookings b
    JOIN users u ON b.murtikar_id = u.id
    WHERE b.id = ?
    """, (customer["booking_id"],))
    booking = dict(c.fetchone())

    # Payments summary (read-only)
    c.execute("SELECT amount, payment_date, payment_mode, note, is_advance FROM payments WHERE booking_id = ? ORDER BY payment_date ASC", (customer["booking_id"],))
    payments = [dict(r) for r in c.fetchall()]
    total_paid = sum(p["amount"] for p in payments)
    booking["payments"] = payments
    booking["total_paid"] = total_paid
    booking["balance_due"] = max(0.0, booking["total_amount"] - total_paid)

    # Timeline of status updates
    c.execute("""
    SELECT su.status_stage, su.note, su.photo_url, su.created_at,
           ds.display_name_en, ds.display_name_hi, ds.display_name_mr, ds.icon_name
    FROM status_updates su
    LEFT JOIN default_stages ds ON su.status_stage = ds.stage_key
    WHERE su.booking_id = ?
    ORDER BY su.created_at ASC
    """, (customer["booking_id"],))
    booking["status_history"] = [dict(r) for r in c.fetchall()]

    # Active change requests submitted by customer
    c.execute("SELECT * FROM change_requests WHERE booking_id = ? ORDER BY created_at DESC", (customer["booking_id"],))
    booking["change_requests"] = [dict(r) for r in c.fetchall()]

    # Rating if submitted
    c.execute("SELECT score, note, created_at FROM ratings WHERE booking_id = ?", (customer["booking_id"],))
    rating = c.fetchone()
    booking["rating"] = dict(rating) if rating else None

    conn.close()
    return booking

@app.post("/api/customer/change-requests")
async def submit_change_request(
    request: Request,
    background_tasks: BackgroundTasks,
    customer: Dict[str, Any] = Depends(auth.get_current_customer)
):
    """Customer submits a design-change request (supports JSON or multipart form-data with reference photo)."""
    change_type = None
    description = None
    photo_file = None

    ct_header = (request.headers.get("content-type") or "").lower()

    if "multipart/form-data" in ct_header:
        form = await request.form()
        change_type = form.get("change_type")
        description = form.get("description")
        uploaded = form.get("image") or form.get("photo")
        if uploaded and hasattr(uploaded, "filename") and uploaded.filename:
            photo_file = uploaded
    else:
        try:
            body = await request.json()
            change_type = body.get("change_type")
            description = body.get("description")
        except Exception:
            form = await request.form()
            change_type = form.get("change_type")
            description = form.get("description")
            uploaded = form.get("image") or form.get("photo")
            if uploaded and hasattr(uploaded, "filename") and uploaded.filename:
                photo_file = uploaded

    if not change_type or not description:
        raise HTTPException(status_code=422, detail="change_type and description are required.")

    photo_url = None
    if photo_file:
        raw_ext = os.path.splitext(photo_file.filename)[1].lower()
        if raw_ext in ALLOWED_PHOTO_EXTENSIONS:
            photo_ext = raw_ext
        else:
            photo_ext = ".jpg"

        ct = (photo_file.content_type or "").lower()
        if ct and not ct.startswith("image/") and ct not in {"application/octet-stream", "binary/octet-stream", "application/x-www-form-urlencoded"}:
            raise HTTPException(status_code=400, detail="Uploaded file must be an image.")

        photo_contents = await photo_file.read()
        if len(photo_contents) > MAX_PHOTO_BYTES:
            raise HTTPException(status_code=400, detail="Image is too large (max 8 MB).")

        if len(photo_contents) > 0:
            photo_filename = f"{uuid.uuid4()}{photo_ext}"
            save_path = os.path.join(UPLOAD_DIR, photo_filename)
            with open(save_path, "wb") as f:
                f.write(photo_contents)
            photo_url = f"/uploads/{photo_filename}"

    conn = database.get_connection()
    c = conn.cursor()

    req_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    c.execute("""
    INSERT INTO change_requests (id, booking_id, customer_phone, change_type, description, status, extra_charge, photo_url, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, 'pending', 0, ?, ?, ?)
    """, (
        req_id, customer["booking_id"], customer["customer_phone"],
        change_type, description, photo_url, now, now
    ))
    
    # Get Murtikar device tokens to send push notification
    c.execute("SELECT murtikar_id FROM bookings WHERE id = ?", (customer["booking_id"],))
    b = c.fetchone()
    if b:
        c.execute("SELECT fcm_token FROM device_tokens WHERE user_identifier = ? AND user_type = 'murtikar'", (b["murtikar_id"],))
        tokens = [row["fcm_token"] for row in c.fetchall()]
        if tokens:
            background_tasks.add_task(
                push_service.send_push,
                tokens,
                "New Change Request",
                f"Customer {customer['customer_phone']} requested a {change_type} change.",
                {"booking_id": customer["booking_id"], "type": "change_request"}
            )
            
    conn.commit()
    conn.close()

    auth.log_audit("change_request_submitted", target_type="change_request", target_id=req_id, details={"booking_id": customer["booking_id"], "type": change_type})
    return {"success": True, "message": "Change request sent to murtikar for review."}


@app.post("/api/customer/ratings")
def submit_rating(
    req: RatingCreate,
    background_tasks: BackgroundTasks,
    customer: Dict[str, Any] = Depends(auth.get_current_customer)
):
    """Customer rates booking post-delivery (1-10 stars, 7-day lock)."""
    conn = database.get_connection()
    c = conn.cursor()

    # Check booking status is delivered
    c.execute("SELECT current_status FROM bookings WHERE id = ?", (customer["booking_id"],))
    booking = c.fetchone()
    if not booking or booking["current_status"] != "delivered":
        conn.close()
        raise HTTPException(status_code=400, detail="Ratings can only be submitted after idol delivery.")

    # Check if rating already exists
    c.execute("SELECT id, locked_at FROM ratings WHERE booking_id = ?", (customer["booking_id"],))
    existing = c.fetchone()
    now = datetime.datetime.now(datetime.timezone.utc)

    if existing:
        if existing["locked_at"] and now > datetime.datetime.fromisoformat(existing["locked_at"]):
            conn.close()
            raise HTTPException(status_code=400, detail="Rating is locked and cannot be edited after 7 days.")
        c.execute("UPDATE ratings SET score = ?, note = ?, updated_at = ? WHERE id = ?",
                  (req.score, req.note, now.isoformat(), existing["id"]))
    else:
        locked_at = (now + datetime.timedelta(days=7)).isoformat()
        c.execute("""
        INSERT INTO ratings (id, booking_id, customer_phone, score, note, locked_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            str(uuid.uuid4()), customer["booking_id"], customer["customer_phone"],
            req.score, req.note, locked_at, now.isoformat(), now.isoformat()
        ))

    # Send Push Notification to Murtikar
    c.execute("SELECT murtikar_id FROM bookings WHERE id = ?", (customer["booking_id"],))
    b = c.fetchone()
    if b:
        c.execute("SELECT fcm_token FROM device_tokens WHERE user_identifier = ? AND user_type = 'murtikar'", (b["murtikar_id"],))
        tokens = [row["fcm_token"] for row in c.fetchall()]
        if tokens:
            stars = "⭐" * req.score
            background_tasks.add_task(
                push_service.send_push,
                tokens,
                "New Rating Received!",
                f"A customer just rated their idol {req.score}/10 {stars}",
                {"booking_id": customer["booking_id"], "type": "rating"}
            )

    conn.commit()
    conn.close()
    return {"success": True, "message": "Thank you! Your rating has been recorded with blessings."}
# ----------------------------------------------------------------------------
# 9. MURTIKAR CHANGE REQUESTS MANAGEMENT
# ----------------------------------------------------------------------------

@app.post("/api/bookings/{booking_id}/change-requests/{cr_id}/respond")
def respond_to_change_request(
    booking_id: str,
    cr_id: str,
    req: ChangeRequestResponse,
    background_tasks: BackgroundTasks,
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    if req.status not in ("accepted", "rejected"):
        raise HTTPException(status_code=400, detail="Status must be 'accepted' or 'rejected'.")
    if req.extra_charge < 0:
        raise HTTPException(status_code=400, detail="Extra charge cannot be negative.")

    conn = database.get_connection()
    try:
        c = conn.cursor()

        # Verify ownership
        c.execute(
            "SELECT total_amount, customer_phone FROM bookings WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL",
            (booking_id, current_user["id"]),
        )
        booking = c.fetchone()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        # The request must exist and still be pending
        c.execute(
            "SELECT status, change_type FROM change_requests WHERE id = ? AND booking_id = ?",
            (cr_id, booking_id),
        )
        cr = c.fetchone()
        if not cr:
            raise HTTPException(status_code=404, detail="Change request not found.")
        if cr["status"] != "pending":
            raise HTTPException(status_code=400, detail="This change request was already answered.")

        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        extra = req.extra_charge if req.status == "accepted" else 0.0

        c.execute(
            """
            UPDATE change_requests
            SET status = ?, murtikar_response = ?, extra_charge = ?, updated_at = ?
            WHERE id = ? AND booking_id = ?
            """,
            (req.status, req.murtikar_response, extra, now, cr_id, booking_id),
        )

        # If accepted with extra charges, update total booking amount (only once)
        if extra > 0:
            c.execute(
                "UPDATE bookings SET total_amount = ?, updated_at = ? WHERE id = ?",
                (booking["total_amount"] + extra, now, booking_id),
            )

        # Push notification to customer in background
        if booking["customer_phone"]:
            c.execute("SELECT fcm_token FROM device_tokens WHERE user_identifier = ? AND user_type = 'customer'", (booking["customer_phone"],))
            tokens = [row["fcm_token"] for row in c.fetchall()]
            if tokens:
                background_tasks.add_task(
                    push_service.send_push,
                    tokens,
                    "Adjustment Request Updated",
                    f"Artisan marked your '{cr['change_type']}' request as {req.status.upper()}.",
                    {"booking_id": booking_id, "type": "change_request"}
                )

        conn.commit()
    finally:
        conn.close()

    auth.log_audit(
        "change_request_responded",
        actor_id=current_user["id"],
        target_type="change_request",
        target_id=cr_id,
        details={"status": req.status, "extra_charge": req.extra_charge},
    )
    return {"success": True, "message": f"Change request marked as {req.status}."}

# ----------------------------------------------------------------------------
# 10. CUSTOMER SUPPORT MESSAGES
# ----------------------------------------------------------------------------

def _get_chat_actor(request: Request, booking_id: str, conn) -> str:
    """
    Verifies the caller may use this booking's support chat.
    Returns 'customer' or 'murtikar'. Raises HTTPException otherwise.
    The sender type is decided HERE from the token, never from client input.
    Re-uses auth.get_current_customer / auth.get_current_user so every access
    check (blocks, deleted booking, approved account) runs on each request.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth token")

    token = auth_header.split(" ", 1)[1].strip()
    # decode_jwt_token returns None (does not raise) for a bad/expired token
    payload = auth.decode_jwt_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    if payload.get("role") == "customer":
        customer = auth.get_current_customer(creds)
        if customer["booking_id"] != booking_id:
            raise HTTPException(status_code=403, detail="Not your booking")
        return "customer"

    user = auth.get_current_user(creds)
    if user.get("role") != "murtikar":
        raise HTTPException(status_code=403, detail="Chat is only available to the workshop and its customers")

    c = conn.cursor()
    c.execute(
        "SELECT 1 FROM bookings WHERE id = ? AND murtikar_id = ? AND deleted_at IS NULL",
        (booking_id, user["id"]),
    )
    if not c.fetchone():
        raise HTTPException(status_code=404, detail="Booking not found")
    return "murtikar"


@app.get("/api/bookings/{booking_id}/messages")
def get_support_messages(booking_id: str, request: Request):
    conn = database.get_connection()
    try:
        _get_chat_actor(request, booking_id, conn)
        c = conn.cursor()
        c.execute(
            "SELECT * FROM support_messages WHERE booking_id = ? ORDER BY created_at ASC",
            (booking_id,),
        )
        messages = [dict(row) for row in c.fetchall()]
        return {"messages": messages}
    finally:
        conn.close()


@app.post("/api/bookings/{booking_id}/messages")
def send_support_message(
    booking_id: str,
    req: MessageCreate,
    request: Request,
    background_tasks: BackgroundTasks,
):
    content = req.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    conn = database.get_connection()
    try:
        sender_type = _get_chat_actor(request, booking_id, conn)

        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        msg_id = str(uuid.uuid4())

        c = conn.cursor()
        c.execute(
            """
            INSERT INTO support_messages (id, booking_id, sender_type, content, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (msg_id, booking_id, sender_type, content, now),
        )
        conn.commit()

        # Notify the OTHER side. A push problem must never make the send fail.
        try:
            c.execute(
                """
                SELECT b.customer_name, b.booking_number, b.murtikar_id, u.shop_name
                FROM bookings b JOIN users u ON b.murtikar_id = u.id
                WHERE b.id = ?
                """,
                (booking_id,),
            )
            info = c.fetchone()
            if info:
                if sender_type == "customer":
                    c.execute(
                        "SELECT fcm_token FROM device_tokens WHERE user_identifier = ? AND user_type = 'murtikar'",
                        (info["murtikar_id"],),
                    )
                    title = f"{info['customer_name']} - {info['booking_number']}"
                    recipient_type = "murtikar"
                else:
                    c.execute(
                        """
                        SELECT dt.fcm_token FROM device_tokens dt
                        JOIN booking_authorized_phones p ON p.phone_number = dt.user_identifier
                        WHERE p.booking_id = ? AND p.is_blocked = 0 AND dt.user_type = 'customer'
                          AND p.phone_number NOT IN (
                              SELECT phone_number FROM murtikar_block_list WHERE murtikar_id = ?
                          )
                        """,
                        (booking_id, info["murtikar_id"]),
                    )
                    title = info["shop_name"] or "Your idol maker"
                    recipient_type = "customer"

                tokens = [r["fcm_token"] for r in c.fetchall()]
                if tokens:
                    preview = content if len(content) <= 120 else content[:117] + "..."
                    background_tasks.add_task(
                        push_service.send_push,
                        tokens,
                        title,
                        preview,
                        {"type": "chat", "booking_id": booking_id, "recipient_type": recipient_type},
                    )
        except Exception as e:
            print(f"[push] chat notification lookup failed: {e}")

        return {"success": True, "message_id": msg_id, "created_at": now}
    finally:
        conn.close()

@app.get("/api/test-push")
def test_push():
    import push_service
    conn = database.get_connection()
    try:
        c = conn.cursor()
        c.execute("SELECT fcm_token, user_identifier FROM device_tokens")
        rows = c.fetchall()
        tokens = [r["fcm_token"] for r in rows]
        if not tokens:
            return {"status": "error", "message": "No tokens found in database. The app has not successfully saved its FCM token."}
        
        # Test initialization
        is_ready = push_service.init_push()
        if not is_ready:
            return {"status": "error", "message": "Firebase Admin failed to initialize. Check FIREBASE_SERVICE_ACCOUNT_JSON."}

        # Send test message
        try:
            from firebase_admin import messaging
            messages = [
                messaging.Message(
                    token=t,
                    notification=messaging.Notification(title="Test Push", body="If you see this, push works!"),
                    data={"type": "test"},
                ) for t in tokens
            ]
            resp = messaging.send_each(messages)
            
            results = []
            for token, r in zip(tokens, resp.responses):
                if r.success:
                    results.append({"token": token[:10] + "...", "status": "success"})
                else:
                    results.append({"token": token[:10] + "...", "status": "failed", "error": str(r.exception)})
            
            return {"status": "success", "total_tokens": len(tokens), "results": results}
        except Exception as e:
            return {"status": "error", "message": f"Exception during send_each: {str(e)}"}
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 11. FESTIVALS & DEFAULT STAGES (Public)
# ----------------------------------------------------------------------------

@app.get("/api/festivals")
def get_active_festivals():
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM festivals WHERE is_active = 1 ORDER BY start_date ASC")
    rows = [dict(r) for r in c.fetchall()]
    conn.close()
    return rows

@app.get("/api/default-stages")
def get_default_stages():
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM default_stages WHERE is_active = 1 ORDER BY display_order ASC")
    rows = [dict(r) for r in c.fetchall()]
    conn.close()
    return rows

@app.get("/api/murtikar/ratings")
def get_murtikar_ratings(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("""
    SELECT r.score, r.note, r.created_at, b.booking_number, b.customer_name, b.festival
    FROM ratings r
    JOIN bookings b ON r.booking_id = b.id
    WHERE b.murtikar_id = ? AND r.visible_to_murtikar = 1 AND r.hidden_by_admin = 0
    ORDER BY r.created_at DESC
    """, (current_user["id"],))
    rows = [dict(row) for row in c.fetchall()]

    avg_score = (sum(r["score"] for r in rows) / len(rows)) if rows else 0.0
    conn.close()

    return {
        "average_score": round(avg_score, 1),
        "total_reviews": len(rows),
        "reviews": rows
    }

@app.get("/api/murtikar/profile")
def get_murtikar_profile(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    return {
        "id": current_user["id"],
        "name": current_user.get("name", "Master Artisan"),
        "shop_name": current_user.get("shop_name", "Shree Ganesh Kalakendra"),
        "phone": current_user.get("phone", ""),
        "role": current_user.get("role", "murtikar"),
    }

# ----------------------------------------------------------------------------
# 12. WEB PORTAL ROUTES (FastAPI Direct HTML View)
# ----------------------------------------------------------------------------

@app.get("/", response_class=HTMLResponse)
def root_index():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>MurtiTrack - Idol Order Management & Tracking</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=Noto+Sans+Devanagari:wght@400;600;700&display=swap" rel="stylesheet">
        <style>
            :root {
                --primary: #D35400;
                --gold: #F39C12;
                --dark: #1A1A24;
                --card: #242436;
                --text: #F8F9FA;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
            body { background: linear-gradient(135deg, #12121A 0%, #1A1828 100%); color: var(--text); min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
            .hero-card { background: rgba(36, 36, 54, 0.85); backdrop-filter: blur(16px); border: 1px solid rgba(243, 156, 18, 0.3); border-radius: 24px; padding: 40px; max-width: 650px; width: 100%; box-shadow: 0 20px 50px rgba(0,0,0,0.6); text-align: center; }
            .badge { display: inline-block; background: linear-gradient(90deg, #D35400, #E67E22); color: white; padding: 6px 16px; border-radius: 50px; font-size: 13px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 20px; }
            h1 { font-size: 32px; font-weight: 800; background: linear-gradient(90deg, #F39C12, #E74C3C); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 12px; }
            p { color: #A0A5B5; font-size: 16px; line-height: 1.6; margin-bottom: 30px; }
            .btn-group { display: flex; flex-direction: column; gap: 14px; }
            .btn { display: block; text-decoration: none; padding: 14px 24px; border-radius: 12px; font-weight: 600; font-size: 16px; transition: all 0.3s; text-align: center; }
            .btn-primary { background: linear-gradient(135deg, #D35400, #F39C12); color: white; box-shadow: 0 4px 15px rgba(211, 84, 0, 0.4); }
            .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(211, 84, 0, 0.6); }
            .btn-secondary { background: rgba(255,255,255,0.08); color: white; border: 1px solid rgba(255,255,255,0.15); }
            .btn-secondary:hover { background: rgba(255,255,255,0.15); }
            .footer-info { margin-top: 30px; font-size: 13px; color: #6E7487; }
        </style>
    </head>
    <body>
        <div class="hero-card">
            <span class="badge">॥ श्री गणेशाय नमः ॥</span>
            <h1>MurtiTrack Platform</h1>
            <p>Digital Business Register & Customer Tracking for Indian Festival Idol Makers</p>
            <div class="btn-group">
                <a href="/tracking" class="btn btn-primary">🔍 Customer Order Tracking Portal</a>
                <a href="/admin" class="btn btn-secondary">🛡️ Platform Admin Dashboard</a>
                <a href="/docs" class="btn btn-secondary">⚡ OpenAPI Interactive Docs</a>
            </div>
            <div class="footer-info">
                Ganesh Utsav • Navratri & Durga Puja • Lakshmi Puja • Saraswati Puja
            </div>
        </div>
    </body>
    </html>
    """

@app.get("/tracking", response_class=HTMLResponse)
def tracking_portal_view():
    tracking_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "customer_web", "index.html")
    if os.path.exists(tracking_file):
        with open(tracking_file, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Customer Tracking Portal is being prepared.</h1>"

@app.get("/admin", response_class=HTMLResponse)
def admin_portal_view():
    admin_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "customer_web", "admin.html")
    if os.path.exists(admin_file):
        with open(admin_file, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Admin Dashboard is being prepared.</h1>"

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
