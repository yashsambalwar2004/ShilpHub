"""
Firebase Cloud Messaging helper for MurtiTrack.

Setup:
  1. pip install firebase-admin
  2. Put your Firebase service-account key at backend/firebase-service-account.json
     (Firebase Console -> Project settings -> Service accounts -> Generate new private key)
  3. NEVER commit or share that file.

If the package or key is missing, push is simply disabled and the rest of the
backend keeps working.
"""

import os
from typing import Dict, List, Optional

import database

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:  # firebase-admin not installed
    firebase_admin = None
    credentials = None
    messaging = None

KEY_PATH = os.path.join(os.path.dirname(__file__), "firebase-service-account.json")

_ready = False
_warned = False


def init_push() -> bool:
    """Initializes Firebase Admin once (lazy). Returns True if push is available."""
    global _ready, _warned
    if _ready:
        return True

    if firebase_admin is None:
        if not _warned:
            print("[push] firebase-admin is not installed. Run: pip install firebase-admin")
            _warned = True
        return False

    cred = None
    env_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    
    if env_json:
        try:
            import json
            cred_dict = json.loads(env_json)
            cred = credentials.Certificate(cred_dict)
        except Exception as e:
            if not _warned:
                print(f"[push] Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON: {e}")
                _warned = True
            return False
    elif os.path.exists(KEY_PATH):
        cred = credentials.Certificate(KEY_PATH)
    else:
        if not _warned:
            print(f"[push] Key file not found: {KEY_PATH} and FIREBASE_SERVICE_ACCOUNT_JSON is not set. Push disabled.")
            _warned = True
        return False

    try:
        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(cred)
        _ready = True
        print("[push] Firebase Admin initialized")
        return True
    except Exception as e:
        if not _warned:
            print(f"[push] Failed to initialize Firebase Admin: {e}")
            _warned = True
        return False


def _delete_tokens(tokens: List[str]) -> None:
    if not tokens:
        return
    conn = database.get_connection()
    try:
        c = conn.cursor()
        for t in tokens:
            c.execute("DELETE FROM device_tokens WHERE fcm_token = ?", (t,))
        conn.commit()
    finally:
        conn.close()


def send_push(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> None:
    """
    Sends a notification to the given FCM device tokens.
    Signature matches the calls in main.py. Never raises: it runs as a
    FastAPI background task. Dead tokens are removed from the database.
    """
    try:
        tokens = list(dict.fromkeys(t for t in (tokens or []) if t))
        if not tokens:
            return
        if not init_push():
            return

        payload = {k: str(v) for k, v in (data or {}).items()}
        messages = [
            messaging.Message(
                token=t,
                notification=messaging.Notification(title=title, body=body),
                data=payload,
                android=messaging.AndroidConfig(priority="high"),
            )
            for t in tokens
        ]

        response = messaging.send_each(messages)

        dead = []
        for token, resp in zip(tokens, response.responses):
            if resp.success:
                continue
            print(f"[push] delivery failed: {resp.exception}")
            if isinstance(resp.exception, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
                dead.append(token)
        _delete_tokens(dead)

        print(f"[push] sent {response.success_count}/{len(tokens)}")
    except Exception as e:
        print(f"[push] error: {e}")
