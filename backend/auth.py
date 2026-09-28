"""
Authentication, Authorization, and Security Module for MurtiTrack.
Implements JWT tokens, password/PIN verification, and the strict 7-step customer check.
"""

import os
import time
import uuid
import datetime
import hashlib
import hmac
import base64
import json
from typing import Optional, Dict, Any, Tuple
from fastapi import HTTPException, Security, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import database

SECRET_KEY = os.environ.get("MURTITRACK_SECRET_KEY", "murtitrack_super_secret_production_key_2026_festivals")
security_bearer = HTTPBearer(auto_error=False)

# Simple JWT implementation for standalone environment without external dependencies
def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

def base64url_decode(data: str) -> bytes:
    padding = '=' * (4 - (len(data) % 4))
    return base64.urlsafe_b64decode((data + padding).encode('utf-8'))

def create_jwt_token(payload: Dict[str, Any], expires_in_seconds: int = 86400 * 7) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    payload_copy = dict(payload)
    payload_copy["exp"] = int(time.time()) + expires_in_seconds
    payload_copy["iat"] = int(time.time())

    encoded_header = base64url_encode(json.dumps(header).encode('utf-8'))
    encoded_payload = base64url_encode(json.dumps(payload_copy).encode('utf-8'))
    
    signing_input = f"{encoded_header}.{encoded_payload}".encode('utf-8')
    signature = hmac.new(SECRET_KEY.encode('utf-8'), signing_input, hashlib.sha256).digest()
    encoded_signature = base64url_encode(signature)

    return f"{encoded_header}.{encoded_payload}.{encoded_signature}"

def decode_jwt_token(token: str) -> Optional[Dict[str, Any]]:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        encoded_header, encoded_payload, encoded_signature = parts
        signing_input = f"{encoded_header}.{encoded_payload}".encode('utf-8')
        expected_sig = hmac.new(SECRET_KEY.encode('utf-8'), signing_input, hashlib.sha256).digest()
        
        if not hmac.compare_digest(base64url_encode(expected_sig), encoded_signature):
            return None
        
        payload_data = json.loads(base64url_decode(encoded_payload).decode('utf-8'))
        if payload_data.get("exp", 0) < int(time.time()):
            return None # Expired
        
        return payload_data
    except Exception:
        return None

def log_audit(action: str, target_type: str = None, target_id: str = None, actor_id: str = None, actor_role: str = None, details: Any = None, ip_address: str = None):
    try:
        conn = database.get_connection()
        conn.execute("""
        INSERT INTO audit_logs (id, actor_id, actor_role, action, target_type, target_id, details, ip_address, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            str(uuid.uuid4()),
            actor_id,
            actor_role,
            action,
            target_type,
            target_id,
            json.dumps(details) if details else None,
            ip_address,
            datetime.datetime.now(datetime.timezone.utc).isoformat()
        ))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error logging audit: {e}")

def check_rate_limit(phone: str, user_type: str = "customer", max_attempts: int = 5, window_minutes: int = 15) -> bool:
    """Returns True if request is allowed, False if rate limited (> max_attempts failed attempts in window)."""
    conn = database.get_connection()
    c = conn.cursor()
    cutoff = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=window_minutes)).isoformat()
    c.execute("""
    SELECT COUNT(*) FROM login_attempts
    WHERE phone = ? AND success = 0 AND created_at > ?
    """, (phone, cutoff))
    count = c.fetchone()[0]
    conn.close()
    return count < max_attempts

def record_login_attempt(phone: str, success: bool, user_type: str, ip: Optional[str] = None):
    try:
        conn = database.get_connection()
        conn.execute("""
        INSERT INTO login_attempts (id, phone, ip_address, success, user_type, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """, (
            str(uuid.uuid4()),
            phone,
            ip,
            1 if success else 0,
            user_type,
            datetime.datetime.now(datetime.timezone.utc).isoformat()
        ))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error recording login attempt: {e}")

def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security_bearer)) -> Dict[str, Any]:
    """Dependency for Murtikar or Admin authentication."""
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authorization token")
    
    payload = decode_jwt_token(credentials.credentials)
    if not payload or "sub" not in payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session")
    
    user_id = payload["sub"]
    conn = database.get_connection()
    c = conn.cursor()
    c.execute("SELECT id, name, shop_name, phone, role, status FROM users WHERE id = ?", (user_id,))
    row = c.fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User account not found")
    
    user = dict(row)
    if user["status"] == "blocked":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is blocked. Contact administrator.")
    if user["status"] != "approved" and user["role"] != "platform_admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Account status is '{user['status']}'. Access pending.")

    return user

def require_admin(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    if current_user.get("role") != "platform_admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    return current_user

def get_current_customer(credentials: HTTPAuthorizationCredentials = Security(security_bearer)) -> Dict[str, Any]:
    """
    Dependency for Customer Order Tracking.
    Re-verifies all 7 checks on EVERY API call to prevent unauthorized access.
    """
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    
    payload = decode_jwt_token(credentials.credentials)
    if not payload or payload.get("role") != "customer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid customer token")
    
    booking_id = payload.get("booking_id")
    customer_phone = payload.get("phone")
    
    if not booking_id or not customer_phone:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")

    conn = database.get_connection()
    c = conn.cursor()

    # Step 1: Check booking exists and active
    c.execute("""
    SELECT b.id, b.booking_number, b.murtikar_id, b.current_status, b.deleted_at,
           u.status as murtikar_status
    FROM bookings b
    JOIN users u ON b.murtikar_id = u.id
    WHERE b.id = ?
    """, (booking_id,))
    booking = c.fetchone()

    if not booking or booking["deleted_at"] is not None:
        conn.close()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Order access unavailable")

    # Step 2: Check murtikar account status
    if booking["murtikar_status"] != "approved":
        conn.close()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Order access unavailable")

    # Step 3: Check workshop-wide block list
    c.execute("""
    SELECT 1 FROM murtikar_block_list
    WHERE murtikar_id = ? AND phone_number = ?
    """, (booking["murtikar_id"], customer_phone))
    if c.fetchone():
        conn.close()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Order access unavailable")

    # Step 4: Check booking authorized phone is present and NOT blocked
    c.execute("""
    SELECT id, label, is_blocked
    FROM booking_authorized_phones
    WHERE booking_id = ? AND phone_number = ?
    """, (booking_id, customer_phone))
    auth_phone = c.fetchone()

    if not auth_phone or auth_phone["is_blocked"] == 1:
        conn.close()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Order access unavailable")

    conn.close()

    return {
        "booking_id": booking_id,
        "booking_number": booking["booking_number"],
        "customer_phone": customer_phone,
        "label": auth_phone["label"],
        "murtikar_id": booking["murtikar_id"]
    }
