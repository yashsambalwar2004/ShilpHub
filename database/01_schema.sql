-- ============================================================================
-- MurtiTrack - Master PostgreSQL & Supabase Database Schema
-- Deliverable 3 Implementation
-- ============================================================================

-- Enable pgcrypto for UUID generation if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. ENUM TYPES
-- ----------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('murtikar', 'platform_admin');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE account_status AS ENUM ('pending', 'approved', 'rejected', 'blocked', 'disabled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE auth_type AS ENUM ('password', 'pin');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_mode AS ENUM ('cash', 'upi', 'bank_transfer', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE production_stage AS ENUM (
    'booking_confirmed',
    'design_approved',
    'base_structure_ready',
    'painting_in_progress',
    'ornamentation',
    'quality_check',
    'ready_for_pickup',
    'delivered'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE change_request_status AS ENUM ('pending', 'accepted', 'rejected', 'completed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE change_type AS ENUM ('color', 'ornament', 'size_adjustment', 'face_expression', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE idol_type AS ENUM ('durga', 'ganesha', 'lakshmi', 'saraswati', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE material_type AS ENUM ('clay', 'plaster', 'fiber', 'marble', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE phone_label AS ENUM ('buyer', 'family', 'friend', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ----------------------------------------------------------------------------
-- 2. HELPER FUNCTIONS & TRIGGERS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 3. USERS TABLE (Murtikars & Platform Admins)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR(100) NOT NULL,
  shop_name       VARCHAR(100),
  city            VARCHAR(50),
  area            VARCHAR(100),
  phone           VARCHAR(10) NOT NULL UNIQUE,
  whatsapp_number VARCHAR(10),
  idol_types      idol_type[] NOT NULL DEFAULT '{}',
  experience_years SMALLINT CHECK (experience_years >= 0 AND experience_years <= 99),
  shop_photo_path  TEXT,                    -- Temporary storage path; deleted after 14 days
  id_proof_path    TEXT,                    -- Temporary storage path; deleted after 14 days
  status          account_status NOT NULL DEFAULT 'pending',
  role            user_role NOT NULL DEFAULT 'murtikar',
  password_hash   TEXT NOT NULL,
  rejected_reason TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users (phone);
CREATE INDEX IF NOT EXISTS idx_users_status ON users (status);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_city ON users (city);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ----------------------------------------------------------------------------
-- 4. FESTIVALS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS festivals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR(100) NOT NULL,
  display_name_en VARCHAR(100) NOT NULL,
  display_name_hi VARCHAR(100),
  display_name_mr VARCHAR(100),
  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_festival_name UNIQUE (name)
);

-- ----------------------------------------------------------------------------
-- 5. BOOKING COUNTERS (Per-murtikar sequential generator)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS booking_counters (
  murtikar_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_number INTEGER NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION generate_booking_number(p_murtikar_id UUID)
RETURNS VARCHAR(20) AS $$
DECLARE
  v_counter INTEGER;
  v_year TEXT;
BEGIN
  INSERT INTO booking_counters (murtikar_id, last_number)
  VALUES (p_murtikar_id, 1)
  ON CONFLICT (murtikar_id) DO UPDATE
    SET last_number = booking_counters.last_number + 1
  RETURNING last_number INTO v_counter;
  
  v_year := EXTRACT(YEAR FROM NOW())::TEXT;
  RETURN 'MUR-' || v_year || '-' || LPAD(v_counter::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 6. BOOKINGS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bookings (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_number        VARCHAR(20) NOT NULL UNIQUE,
  murtikar_id           UUID NOT NULL REFERENCES users(id),
  customer_name         VARCHAR(100) NOT NULL,
  customer_phone        VARCHAR(10) NOT NULL,
  festival              VARCHAR(100) NOT NULL,
  idol_type             idol_type NOT NULL,
  size                  VARCHAR(50) NOT NULL,
  material              material_type NOT NULL,
  total_amount          DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
  advance_amount        DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (advance_amount >= 0),
  advance_received_date DATE,
  advance_mode          payment_mode,
  advance_note          VARCHAR(500),
  current_status        production_stage NOT NULL DEFAULT 'booking_confirmed',
  expected_delivery_date DATE NOT NULL,
  notes                 TEXT,
  deleted_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_advance_lte_total CHECK (advance_amount <= total_amount)
);

CREATE INDEX IF NOT EXISTS idx_bookings_murtikar ON bookings (murtikar_id);
CREATE INDEX IF NOT EXISTS idx_bookings_festival ON bookings (murtikar_id, festival);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings (murtikar_id, current_status);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_phone ON bookings (murtikar_id, customer_phone);
CREATE INDEX IF NOT EXISTS idx_bookings_delivery_date ON bookings (murtikar_id, expected_delivery_date);
CREATE INDEX IF NOT EXISTS idx_bookings_created ON bookings (murtikar_id, created_at);
CREATE INDEX IF NOT EXISTS idx_bookings_number ON bookings (booking_number);
CREATE INDEX IF NOT EXISTS idx_bookings_active ON bookings (murtikar_id) WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_bookings_updated_at ON bookings;
CREATE TRIGGER trg_bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ----------------------------------------------------------------------------
-- 7. BOOKING AUTHORIZED PHONES TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS booking_authorized_phones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  phone_number  VARCHAR(10) NOT NULL,
  label         phone_label NOT NULL DEFAULT 'buyer',
  auth_type     auth_type NOT NULL DEFAULT 'password',
  password_hash TEXT,
  pin_hash      TEXT,
  is_primary    BOOLEAN NOT NULL DEFAULT false,
  is_blocked    BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_phone_per_booking UNIQUE (booking_id, phone_number),
  CONSTRAINT chk_credential_present CHECK (
    (auth_type = 'password' AND password_hash IS NOT NULL) OR
    (auth_type = 'pin' AND pin_hash IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_auth_phones_booking ON booking_authorized_phones (booking_id);
CREATE INDEX IF NOT EXISTS idx_auth_phones_phone ON booking_authorized_phones (phone_number);
CREATE INDEX IF NOT EXISTS idx_auth_phones_lookup ON booking_authorized_phones (phone_number, booking_id) WHERE is_blocked = false;
CREATE INDEX IF NOT EXISTS idx_auth_phones_login ON booking_authorized_phones (phone_number, booking_id, is_blocked);

DROP TRIGGER IF EXISTS trg_auth_phones_updated_at ON booking_authorized_phones;
CREATE TRIGGER trg_auth_phones_updated_at
  BEFORE UPDATE ON booking_authorized_phones
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ----------------------------------------------------------------------------
-- 8. MURTIKAR BLOCK LIST TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS murtikar_block_list (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  murtikar_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  phone_number  VARCHAR(10) NOT NULL,
  reason        VARCHAR(500),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_murtikar_block UNIQUE (murtikar_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_block_list_murtikar ON murtikar_block_list (murtikar_id);
CREATE INDEX IF NOT EXISTS idx_block_list_lookup ON murtikar_block_list (murtikar_id, phone_number);

-- ----------------------------------------------------------------------------
-- 9. STATUS UPDATES TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS status_updates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  status_stage  production_stage NOT NULL,
  note          VARCHAR(500),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_updates_booking ON status_updates (booking_id, created_at);

-- ----------------------------------------------------------------------------
-- 10. BOOKING PHOTOS TABLE (14-day auto retention)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS booking_photos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id       UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  status_update_id UUID REFERENCES status_updates(id) ON DELETE SET NULL,
  storage_path     TEXT NOT NULL,
  file_size_bytes  INTEGER NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 5242880),
  mime_type        VARCHAR(20) NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at       TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '14 days'),
  cleanup_status   VARCHAR(10) DEFAULT 'active',
  CONSTRAINT chk_cleanup_status CHECK (cleanup_status IN ('active', 'expired', 'deleted', 'retry'))
);

CREATE INDEX IF NOT EXISTS idx_photos_booking ON booking_photos (booking_id);
CREATE INDEX IF NOT EXISTS idx_photos_cleanup ON booking_photos (expires_at) WHERE cleanup_status = 'active';

-- ----------------------------------------------------------------------------
-- 11. CHANGE REQUESTS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS change_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  customer_phone    VARCHAR(10) NOT NULL,
  change_type       change_type NOT NULL,
  description       TEXT NOT NULL CHECK (LENGTH(description) >= 5 AND LENGTH(description) <= 1000),
  status            change_request_status NOT NULL DEFAULT 'pending',
  murtikar_response VARCHAR(500),
  extra_charge      DECIMAL(12,2) DEFAULT 0 CHECK (extra_charge >= 0),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_change_requests_booking ON change_requests (booking_id);
CREATE INDEX IF NOT EXISTS idx_change_requests_status ON change_requests (booking_id, status);

DROP TRIGGER IF EXISTS trg_change_requests_updated_at ON change_requests;
CREATE TRIGGER trg_change_requests_updated_at
  BEFORE UPDATE ON change_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ----------------------------------------------------------------------------
-- 12. PAYMENTS TABLE (Advance + Balance)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  amount        DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  payment_date  DATE NOT NULL,
  payment_mode  payment_mode NOT NULL,
  note          VARCHAR(500),
  is_advance    BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments (booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_mode ON payments (payment_mode);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments (payment_date);
CREATE INDEX IF NOT EXISTS idx_payments_summary ON payments (booking_id, payment_mode, payment_date);

DROP TRIGGER IF EXISTS trg_payments_updated_at ON payments;
CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Synchronize advance payment with payments table without double counting
CREATE OR REPLACE FUNCTION sync_advance_payment()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.advance_amount > 0 THEN
    INSERT INTO payments (booking_id, amount, payment_date, payment_mode, note, is_advance)
    VALUES (
      NEW.id,
      NEW.advance_amount,
      COALESCE(NEW.advance_received_date, CURRENT_DATE),
      COALESCE(NEW.advance_mode, 'cash'),
      NEW.advance_note,
      true
    );
  ELSIF TG_OP = 'UPDATE' AND (
    OLD.advance_amount IS DISTINCT FROM NEW.advance_amount OR
    OLD.advance_mode IS DISTINCT FROM NEW.advance_mode OR
    OLD.advance_received_date IS DISTINCT FROM NEW.advance_received_date OR
    OLD.advance_note IS DISTINCT FROM NEW.advance_note
  ) THEN
    UPDATE payments
    SET amount = NEW.advance_amount,
        payment_date = COALESCE(NEW.advance_received_date, payment_date),
        payment_mode = COALESCE(NEW.advance_mode, payment_mode),
        note = NEW.advance_note,
        updated_at = NOW()
    WHERE booking_id = NEW.id AND is_advance = true;
    
    IF NOT FOUND AND NEW.advance_amount > 0 THEN
      INSERT INTO payments (booking_id, amount, payment_date, payment_mode, note, is_advance)
      VALUES (
        NEW.id,
        NEW.advance_amount,
        COALESCE(NEW.advance_received_date, CURRENT_DATE),
        COALESCE(NEW.advance_mode, 'cash'),
        NEW.advance_note,
        true
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_advance ON bookings;
CREATE TRIGGER trg_sync_advance
  AFTER INSERT OR UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION sync_advance_payment();

-- Prevent overpayment beyond booking total amount
CREATE OR REPLACE FUNCTION check_payment_total()
RETURNS TRIGGER AS $$
DECLARE
  v_total_paid DECIMAL(12,2);
  v_total_amount DECIMAL(12,2);
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM payments
  WHERE booking_id = NEW.booking_id
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  
  v_total_paid := v_total_paid + NEW.amount;
  
  SELECT total_amount INTO v_total_amount
  FROM bookings WHERE id = NEW.booking_id;
  
  IF v_total_paid > v_total_amount THEN
    RAISE EXCEPTION 'Total payments (%.2f) would exceed booking total (%.2f)', 
      v_total_paid, v_total_amount;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_payment ON payments;
CREATE TRIGGER trg_check_payment
  BEFORE INSERT OR UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION check_payment_total();

-- ----------------------------------------------------------------------------
-- 13. RATINGS TABLE (Customer feedback post-delivery)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ratings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id          UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  customer_phone      VARCHAR(10) NOT NULL,
  score               SMALLINT NOT NULL CHECK (score >= 1 AND score <= 10),
  note                TEXT CHECK (LENGTH(note) <= 1000),
  visible_to_murtikar BOOLEAN NOT NULL DEFAULT true,
  flagged_by_admin    BOOLEAN NOT NULL DEFAULT false,
  flag_reason         VARCHAR(500),
  hidden_by_admin     BOOLEAN NOT NULL DEFAULT false,
  locked_at           TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_rating_per_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS idx_ratings_booking ON ratings (booking_id);

CREATE OR REPLACE FUNCTION set_rating_lock_time()
RETURNS TRIGGER AS $$
BEGIN
  NEW.locked_at := NOW() + INTERVAL '7 days';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_lock_time ON ratings;
CREATE TRIGGER trg_set_lock_time
  BEFORE INSERT ON ratings
  FOR EACH ROW EXECUTE FUNCTION set_rating_lock_time();

CREATE OR REPLACE FUNCTION lock_old_ratings()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.locked_at IS NOT NULL AND OLD.locked_at < NOW() THEN
    RAISE EXCEPTION 'Rating is locked and cannot be edited after 7 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lock_rating ON ratings;
CREATE TRIGGER trg_lock_rating
  BEFORE UPDATE ON ratings
  FOR EACH ROW EXECUTE FUNCTION lock_old_ratings();

-- ----------------------------------------------------------------------------
-- 14. AUDIT LOGS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID,
  actor_role  user_role,
  action      VARCHAR(100) NOT NULL,
  target_type VARCHAR(50),
  target_id   UUID,
  details     JSONB,
  ip_address  INET,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs (actor_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs (action, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_target ON audit_logs (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs (created_at);

-- ----------------------------------------------------------------------------
-- 15. LOGIN ATTEMPTS TABLE (Rate Limiting)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS login_attempts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       VARCHAR(10) NOT NULL,
  ip_address  INET,
  success     BOOLEAN NOT NULL DEFAULT false,
  user_type   VARCHAR(10) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_phone ON login_attempts (phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip ON login_attempts (ip_address, created_at DESC);

-- ----------------------------------------------------------------------------
-- 16. DEFAULT STAGES & CLEANUP LOGS
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS default_stages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_key     VARCHAR(50) NOT NULL UNIQUE,
  display_order SMALLINT NOT NULL,
  display_name_en VARCHAR(100) NOT NULL,
  display_name_hi VARCHAR(100),
  display_name_mr VARCHAR(100),
  icon_name     VARCHAR(50),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cleanup_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type        VARCHAR(50) NOT NULL,
  files_deleted   INTEGER NOT NULL DEFAULT 0,
  files_failed    INTEGER NOT NULL DEFAULT 0,
  duration_ms     INTEGER,
  error_details   JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
