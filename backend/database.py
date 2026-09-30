"""
Database layer for MurtiTrack backend.
Supports SQLite (zero-config local out of the box) and PostgreSQL (Supabase / Production).
"""

import os
import sqlite3
import datetime
import hashlib
import json
from typing import Optional, List, Dict, Any

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    psycopg2 = None

DB_PATH = os.environ.get("MURTITRACK_DB_PATH", os.path.join(os.path.dirname(__file__), "murtitrack.db"))
SUPABASE_URL = os.environ.get("SUPABASE_URL")

class PgCursorWrapper:
    def __init__(self, cursor):
        self.cursor = cursor
        
    def execute(self, query, params=None):
        query = query.replace("?", "%s")
        if "INSERT OR REPLACE INTO booking_counters" in query:
            if params is None:
                query = query.replace("INSERT OR REPLACE INTO booking_counters VALUES", "INSERT INTO booking_counters (murtikar_id, last_number) VALUES")
                query += " ON CONFLICT (murtikar_id) DO UPDATE SET last_number = EXCLUDED.last_number"
            else:
                query = """INSERT INTO booking_counters (murtikar_id, last_number) 
                           VALUES (%s, %s) 
                           ON CONFLICT (murtikar_id) DO UPDATE SET last_number = EXCLUDED.last_number"""
        elif "INSERT OR IGNORE" in query:
            query = query.replace("INSERT OR IGNORE", "INSERT").replace(")", ") ON CONFLICT DO NOTHING", 1)
        
        if "PRAGMA" in query:
            return self
            
        if params is None:
            self.cursor.execute(query)
        else:
            self.cursor.execute(query, params)
        return self
            
    def fetchone(self):
        return self.cursor.fetchone()
        
    def fetchall(self):
        return self.cursor.fetchall()
        
    def executemany(self, query, params_list):
        query = query.replace("?", "%s")
        self.cursor.executemany(query, params_list)
        return self

class PgConnectionWrapper:
    def __init__(self, conn):
        self.conn = conn
        
    def cursor(self):
        return PgCursorWrapper(self.conn.cursor(cursor_factory=psycopg2.extras.DictCursor))
        
    def commit(self):
        self.conn.commit()
        
    def close(self):
        self.conn.close()

def get_connection():
    if SUPABASE_URL and psycopg2:
        clean_url = SUPABASE_URL.split("?")[0] if "?" in SUPABASE_URL else SUPABASE_URL
        conn = psycopg2.connect(clean_url)
        return PgConnectionWrapper(conn)
    else:
        conn = sqlite3.connect(DB_PATH, timeout=15)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute("PRAGMA journal_mode = WAL;")
        conn.execute("PRAGMA synchronous = NORMAL;")
        conn.execute("PRAGMA temp_store = MEMORY;")
        return conn

def hash_credential(text: str) -> str:
    """Hashes passwords and PINs with SHA-256 for local portability."""
    salt = "murtitrack_secure_salt_2026_"
    return hashlib.sha256((salt + text).hexdigest() if hasattr(salt, 'hexdigest') else (salt + text).encode('utf-8')).hexdigest()

def verify_credential(plain_text: str, stored_hash: str) -> bool:
    return hash_credential(plain_text) == stored_hash

def init_db():
    """Initializes tables and seeds default data if not already present."""
    conn = get_connection()
    c = conn.cursor()

    # 1. Users (Murtikars & Platform Admins)
    c.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        shop_name TEXT,
        city TEXT,
        area TEXT,
        phone TEXT NOT NULL UNIQUE,
        whatsapp_number TEXT,
        idol_types TEXT DEFAULT '[]',
        experience_years INTEGER DEFAULT 0,
        shop_photo_path TEXT,
        id_proof_path TEXT,
        status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected, blocked
        role TEXT NOT NULL DEFAULT 'murtikar',   -- murtikar, platform_admin
        password_hash TEXT NOT NULL,
        rejected_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """)

    # 2. Festivals
    c.execute("""
    CREATE TABLE IF NOT EXISTS festivals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        display_name_en TEXT NOT NULL,
        display_name_hi TEXT,
        display_name_mr TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
    );
    """)

    # 3. Booking Counters
    c.execute("""
    CREATE TABLE IF NOT EXISTS booking_counters (
        murtikar_id TEXT PRIMARY KEY,
        last_number INTEGER NOT NULL DEFAULT 0
    );
    """)

    # 4. Bookings
    c.execute("""
    CREATE TABLE IF NOT EXISTS bookings (
        id TEXT PRIMARY KEY,
        booking_number TEXT NOT NULL UNIQUE,
        murtikar_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        festival TEXT NOT NULL,
        idol_type TEXT NOT NULL,
        size TEXT NOT NULL,
        material TEXT NOT NULL,
        total_amount REAL NOT NULL,
        advance_amount REAL NOT NULL DEFAULT 0,
        advance_received_date TEXT,
        advance_mode TEXT,
        advance_note TEXT,
        current_status TEXT NOT NULL DEFAULT 'booking_confirmed',
        expected_delivery_date TEXT NOT NULL,
        notes TEXT,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (murtikar_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # 5. Booking Authorized Phones
    c.execute("""
    CREATE TABLE IF NOT EXISTS booking_authorized_phones (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT 'buyer',
        auth_type TEXT NOT NULL DEFAULT 'pin',
        password_hash TEXT,
        pin_hash TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0,
        is_blocked INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(booking_id, phone_number),
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 6. Murtikar Block List
    c.execute("""
    CREATE TABLE IF NOT EXISTS murtikar_block_list (
        id TEXT PRIMARY KEY,
        murtikar_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(murtikar_id, phone_number),
        FOREIGN KEY (murtikar_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # 7. Status Updates
    c.execute("""
    CREATE TABLE IF NOT EXISTS status_updates (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        status_stage TEXT NOT NULL,
        note TEXT,
        photo_url TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 8. Booking Photos (with 14-day TTL)
    c.execute("""
    CREATE TABLE IF NOT EXISTS booking_photos (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        status_update_id TEXT,
        storage_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        uploaded_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        cleanup_status TEXT DEFAULT 'active',
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 9. Change Requests
    c.execute("""
    CREATE TABLE IF NOT EXISTS change_requests (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        change_type TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        murtikar_response TEXT,
        extra_charge REAL DEFAULT 0,
        photo_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)
    try:
        c.execute("ALTER TABLE change_requests ADD COLUMN photo_url TEXT")
    except Exception:
        pass

    # 10. Payments
    c.execute("""
    CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        note TEXT,
        is_advance INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 11. Ratings
    c.execute("""
    CREATE TABLE IF NOT EXISTS ratings (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL UNIQUE,
        customer_phone TEXT NOT NULL,
        score INTEGER NOT NULL,
        note TEXT,
        visible_to_murtikar INTEGER NOT NULL DEFAULT 1,
        flagged_by_admin INTEGER NOT NULL DEFAULT 0,
        flag_reason TEXT,
        hidden_by_admin INTEGER NOT NULL DEFAULT 0,
        locked_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 12. Audit Logs
    c.execute("""
    CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        actor_id TEXT,
        actor_role TEXT,
        action TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT,
        details TEXT,
        ip_address TEXT,
        created_at TEXT NOT NULL
    );
    """)

    # 13. Login Attempts (Rate Limiting)
    c.execute("""
    CREATE TABLE IF NOT EXISTS login_attempts (
        id TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        ip_address TEXT,
        success INTEGER NOT NULL,
        user_type TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """)

    # 14. Default Stages
    c.execute("""
    CREATE TABLE IF NOT EXISTS default_stages (
        stage_key TEXT PRIMARY KEY,
        display_order INTEGER NOT NULL,
        display_name_en TEXT NOT NULL,
        display_name_hi TEXT,
        display_name_mr TEXT,
        icon_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
    );
    """)

    # 15. Cleanup Logs
    c.execute("""
    CREATE TABLE IF NOT EXISTS cleanup_logs (
        id TEXT PRIMARY KEY,
        job_type TEXT NOT NULL,
        files_deleted INTEGER NOT NULL DEFAULT 0,
        files_failed INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER,
        details TEXT,
        created_at TEXT NOT NULL
    );
    """)

    # 16. Support Messages
    c.execute("""
    CREATE TABLE IF NOT EXISTS support_messages (
        id TEXT PRIMARY KEY,
        booking_id TEXT NOT NULL,
        sender_type TEXT NOT NULL, -- 'customer' or 'murtikar'
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        read_at TEXT,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
    );
    """)

    # 17. Device Tokens for Push Notifications
    c.execute("""
    CREATE TABLE IF NOT EXISTS device_tokens (
        id TEXT PRIMARY KEY,
        user_identifier TEXT NOT NULL, -- phone number or murtikar_id
        user_type TEXT NOT NULL, -- 'customer' or 'murtikar'
        fcm_token TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_identifier, fcm_token)
    );
    """)

    # Performance Indexes for sub-10ms queries
    c.execute("CREATE INDEX IF NOT EXISTS idx_bookings_murtikar ON bookings(murtikar_id);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_bookings_customer_phone ON bookings(customer_phone);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_change_requests_booking ON change_requests(booking_id);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_status_updates_booking ON status_updates(booking_id);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_device_tokens_lookup ON device_tokens(user_identifier, user_type);")
    c.execute("CREATE INDEX IF NOT EXISTS idx_authorized_phones_lookup ON booking_authorized_phones(booking_id, phone_number);")

    conn.commit()

    # Seed Defaults if empty
    c.execute("SELECT COUNT(*) FROM festivals")
    if c.fetchone()[0] == 0:
        festivals = [
            ("fest-1", "ganesh_utsav_2026", "Ganesh Utsav 2026", "गणेश उत्सव 2026", "गणेशोत्सव 2026", "2026-09-14", "2026-09-24", 1),
            ("fest-2", "navratri_2026", "Navratri / Durga Puja 2026", "नवरात्रि / दुर्गा पूजा 2026", "नवरात्री / दुर्गा पूजा 2026", "2026-10-11", "2026-10-20", 1),
            ("fest-3", "lakshmi_puja_2026", "Diwali & Lakshmi Puja 2026", "दिवाली व लक्ष्मी पूजा 2026", "दिवाळी व लक्ष्मीपूजन 2026", "2026-11-08", "2026-11-12", 1),
            ("fest-4", "saraswati_puja_2027", "Saraswati Puja 2027", "सरस्वती पूजा 2027", "सरस्वती पूजा 2027", "2027-02-11", "2027-02-12", 1),
        ]
        c.executemany("INSERT INTO festivals VALUES (?,?,?,?,?,?,?,?)", festivals)

    c.execute("SELECT COUNT(*) FROM default_stages")
    if c.fetchone()[0] == 0:
        stages = [
            ("booking_confirmed", 1, "Booking Confirmed", "बुकिंग पक्की", "बुकिंग निश्चित", "check_circle", 1),
            ("design_approved", 2, "Design Approved", "डिज़ाइन स्वीकृत", "डिझाइन मंजूर", "design_services", 1),
            ("base_structure_ready", 3, "Base Structure Ready", "आधार ढांचा तैयार", "मूळ रचना तयार", "foundation", 1),
            ("painting_in_progress", 4, "Painting in Progress", "रंगाई जारी", "रंगकाम सुरू", "brush", 1),
            ("ornamentation", 5, "Ornamentation & Shringar", "आभूषण व श्रृंगार", "अलंकार व शृंगार", "diamond", 1),
            ("quality_check", 6, "Quality Check Complete", "गुणवत्ता जांच पूर्ण", "गुणवत्ता तपासणी पूर्ण", "verified", 1),
            ("ready_for_pickup", 7, "Ready for Pickup", "लेने के लिए तैयार", "नेण्यासाठी तयार", "local_shipping", 1),
            ("delivered", 8, "Delivered with Blessings", "शुभ विसर्जन / वितरित", "वितरित", "celebration", 1),
        ]
        c.executemany("INSERT INTO default_stages VALUES (?,?,?,?,?,?,?)", stages)

    # Seed or Update Admin User
    admin_phone = os.environ.get("ADMIN_PHONE", "9999999999")
    admin_pass = hash_credential(os.environ.get("ADMIN_PASSWORD", "Admin@Murti2026"))
    
    c.execute("SELECT COUNT(*) FROM users WHERE role = 'platform_admin'")
    if c.fetchone()[0] == 0:
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        c.execute("""
        INSERT INTO users (id, name, shop_name, city, area, phone, whatsapp_number, idol_types, experience_years, status, role, password_hash, created_at, updated_at)
        VALUES ('admin-001', 'MurtiTrack Platform Admin', 'MurtiTrack HQ', 'Mumbai', 'Dadar', ?, ?, '["ganesha","durga"]', 15, 'approved', 'platform_admin', ?, ?, ?)
        """, (admin_phone, admin_phone, admin_pass, now, now))
    else:
        c.execute("UPDATE users SET phone = ?, whatsapp_number = ?, password_hash = ? WHERE role = 'platform_admin'", (admin_phone, admin_phone, admin_pass))

    # Seed Sample Murtikar (Phone: 9823012345, Password: Murtikar@123)
    c.execute("SELECT COUNT(*) FROM users WHERE phone = '9823012345'")
    if c.fetchone()[0] == 0:
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        murtikar_pass = hash_credential("Murtikar@123")
        c.execute("""
        INSERT INTO users (id, name, shop_name, city, area, phone, whatsapp_number, idol_types, experience_years, status, role, password_hash, created_at, updated_at)
        VALUES ('murtikar-001', 'Ramesh Chandra Pal', 'Shree Ganesh Kalakendra', 'Pune', 'Kasba Peth', '9823012345', '9823012345', '["ganesha","durga","lakshmi"]', 22, 'approved', 'murtikar', ?, ?, ?)
        """, (murtikar_pass, now, now))

        # Seed sample booking
        c.execute("SELECT COUNT(*) FROM bookings WHERE booking_number = 'MUR-2026-00001'")
        if c.fetchone()[0] == 0:
            booking_id = "book-001"
            c.execute("""
            INSERT INTO bookings (id, booking_number, murtikar_id, customer_name, customer_phone, festival, idol_type, size, material, total_amount, advance_amount, advance_received_date, advance_mode, advance_note, current_status, expected_delivery_date, notes, created_at, updated_at)
            VALUES (?, 'MUR-2026-00001', 'murtikar-001', 'Anand Deshmukh (Sarvajanik Mandal)', '9850123456', 'ganesh_utsav_2026', 'ganesha', '8 feet (Lalbaugcha Raja Style)', 'clay', 45000.0, 15000.0, '2026-06-15', 'upi', 'Google Pay Ref: UPI/9382103810', 'painting_in_progress', '2026-09-12', 'Traditional saffron pitambar, gold mukut with pearl border.', ?, ?)
            """, (booking_id, now, now))

            # Set booking counter
            if SUPABASE_URL and psycopg2:
                c.execute("INSERT INTO booking_counters (murtikar_id, last_number) VALUES ('murtikar-001', 1) ON CONFLICT (murtikar_id) DO UPDATE SET last_number = 1")
            else:
                c.execute("INSERT OR REPLACE INTO booking_counters VALUES ('murtikar-001', 1)")

            # Seed advance payment in payments table
            c.execute("""
            INSERT INTO payments (id, booking_id, amount, payment_date, payment_mode, note, is_advance, created_at, updated_at)
            VALUES ('pay-001', ?, 15000.0, '2026-06-15', 'upi', 'Google Pay Ref: UPI/9382103810', 1, ?, ?)
            """, (booking_id, now, now))

            # Seed authorized customer phone (PIN: 1234)
            pin_hash = hash_credential("1234")
            c.execute("""
            INSERT INTO booking_authorized_phones (id, booking_id, phone_number, label, auth_type, pin_hash, is_primary, is_blocked, created_at, updated_at)
            VALUES ('auth-001', ?, '9850123456', 'buyer', 'pin', ?, 1, 0, ?, ?)
            """, (booking_id, pin_hash, now, now))

            # Seed status history
            past_30 = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).isoformat()
            past_20 = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=20)).isoformat()
            past_10 = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=10)).isoformat()
            past_2 = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=2)).isoformat()

            c.execute("INSERT INTO status_updates VALUES ('su-1', ?, 'booking_confirmed', 'Order booked with token advance received.', NULL, ?)", (booking_id, past_30))
            c.execute("INSERT INTO status_updates VALUES ('su-2', ?, 'design_approved', 'Sketch & pose finalized with Mandal trustees.', NULL, ?)", (booking_id, past_20))
            c.execute("INSERT INTO status_updates VALUES ('su-3', ?, 'base_structure_ready', 'Eco-friendly clay sculpting completed.', NULL, ?)", (booking_id, past_10))
            c.execute("INSERT INTO status_updates VALUES ('su-4', ?, 'painting_in_progress', 'First layer natural color shading ongoing.', NULL, ?)", (booking_id, past_2))

    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    print("MurtiTrack SQLite Database initialized and seeded successfully.")
