-- ============================================================================
-- MurtiTrack - Row-Level Security (RLS) Policies
-- Enforcing strict multi-tenant isolation at database level
-- ============================================================================

-- Enable RLS on all relevant tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_authorized_phones ENABLE ROW LEVEL SECURITY;
ALTER TABLE murtikar_block_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. USERS TABLE POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS users_murtikar_select ON users;
CREATE POLICY users_murtikar_select ON users
  FOR SELECT USING (
    (auth.uid() = id AND role = 'murtikar')
    OR
    (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'platform_admin'))
  );

DROP POLICY IF EXISTS users_murtikar_update ON users;
CREATE POLICY users_murtikar_update ON users
  FOR UPDATE USING (
    auth.uid() = id AND role = 'murtikar'
  )
  WITH CHECK (
    role = 'murtikar' AND status = 'approved'
  );

DROP POLICY IF EXISTS users_admin_all ON users;
CREATE POLICY users_admin_all ON users
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'platform_admin')
  );

-- ----------------------------------------------------------------------------
-- 2. BOOKINGS TABLE POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS bookings_murtikar ON bookings;
CREATE POLICY bookings_murtikar ON bookings
  FOR ALL USING (murtikar_id = auth.uid());

DROP POLICY IF EXISTS bookings_admin_read ON bookings;
CREATE POLICY bookings_admin_read ON bookings
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'platform_admin')
  );

-- ----------------------------------------------------------------------------
-- 3. BOOKING AUTHORIZED PHONES POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS auth_phones_murtikar ON booking_authorized_phones;
CREATE POLICY auth_phones_murtikar ON booking_authorized_phones
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 4. MURTIKAR BLOCK LIST POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS block_list_murtikar ON murtikar_block_list;
CREATE POLICY block_list_murtikar ON murtikar_block_list
  FOR ALL USING (murtikar_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. STATUS UPDATES POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS status_updates_murtikar ON status_updates;
CREATE POLICY status_updates_murtikar ON status_updates
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 6. BOOKING PHOTOS POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS booking_photos_murtikar ON booking_photos;
CREATE POLICY booking_photos_murtikar ON booking_photos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 7. CHANGE REQUESTS POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS change_requests_murtikar ON change_requests;
CREATE POLICY change_requests_murtikar ON change_requests
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 8. PAYMENTS POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS payments_murtikar ON payments;
CREATE POLICY payments_murtikar ON payments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 9. RATINGS POLICIES
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS ratings_murtikar_read ON ratings;
CREATE POLICY ratings_murtikar_read ON ratings
  FOR SELECT USING (
    visible_to_murtikar = true
    AND hidden_by_admin = false
    AND EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id AND b.murtikar_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ratings_admin_all ON ratings;
CREATE POLICY ratings_admin_all ON ratings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'platform_admin')
  );
