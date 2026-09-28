"""
MurtiTrack 14-Day Automated Image Cleanup Worker.
Purges expired media from storage and database records, preserving business text data permanently.
"""

import os
import time
import uuid
import datetime
import threading
import database

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

def purge_expired_images_job():
    """Finds photos whose expires_at is past and deletes them from disk and database."""
    conn = database.get_connection()
    c = conn.cursor()
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    start_time = time.time()
    
    files_deleted = 0
    files_failed = 0

    try:
        # 1. Fetch expired active photos
        c.execute("""
        SELECT id, storage_path FROM booking_photos
        WHERE expires_at < ? AND (cleanup_status = 'active' OR cleanup_status = 'retry')
        LIMIT 100
        """, (now_iso,))
        expired_photos = c.fetchall()

        for p in expired_photos:
            photo_id = p["id"]
            file_path = p["storage_path"]

            try:
                # Remove from disk if file exists
                if os.path.exists(file_path):
                    os.remove(file_path)
                
                # Mark as deleted in DB
                c.execute("UPDATE booking_photos SET cleanup_status = 'deleted' WHERE id = ?", (photo_id,))
                files_deleted += 1
            except Exception as ex:
                print(f"Failed to delete {file_path}: {ex}")
                c.execute("UPDATE booking_photos SET cleanup_status = 'retry' WHERE id = ?", (photo_id,))
                files_failed += 1

        duration_ms = int((time.time() - start_time) * 1000)

        if files_deleted > 0 or files_failed > 0:
            c.execute("""
            INSERT INTO cleanup_logs (id, job_type, files_deleted, files_failed, duration_ms, details, created_at)
            VALUES (?, 'image_cleanup', ?, ?, ?, ?, ?)
            """, (
                str(uuid.uuid4()),
                files_deleted,
                files_failed,
                duration_ms,
                f"Purged {files_deleted} expired photos with 14-day TTL rule",
                now_iso
            ))
            conn.commit()

    except Exception as e:
        print(f"Error in image cleanup job: {e}")
    finally:
        conn.close()

def start_background_cleanup_scheduler(interval_seconds: int = 3600):
    """Runs the cleanup job in a daemon background thread."""
    def run_loop():
        while True:
            try:
                purge_expired_images_job()
            except Exception as e:
                print(f"Background cleanup error: {e}")
            time.sleep(interval_seconds)

    thread = threading.Thread(target=run_loop, daemon=True)
    thread.start()
    print(f"14-Day Image auto-cleanup worker started (running every {interval_seconds}s).")
