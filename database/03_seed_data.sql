-- ============================================================================
-- MurtiTrack - Seed Data
-- ============================================================================

-- 1. Default Festivals
INSERT INTO festivals (name, display_name_en, display_name_hi, display_name_mr, start_date, end_date, is_active)
VALUES
  ('ganesh_utsav_2026', 'Ganesh Utsav 2026', 'गणेश उत्सव 2026', 'गणेशोत्सव 2026', '2026-09-14', '2026-09-24', true),
  ('navratri_2026', 'Navratri / Durga Puja 2026', 'नवरात्रि / दुर्गा पूजा 2026', 'नवरात्री / दुर्गा पूजा 2026', '2026-10-11', '2026-10-20', true),
  ('lakshmi_puja_2026', 'Diwali & Lakshmi Puja 2026', 'दिवाली व लक्ष्मी पूजा 2026', 'दिवाळी व लक्ष्मीपूजन 2026', '2026-11-08', '2026-11-12', true),
  ('saraswati_puja_2027', 'Saraswati Puja / Vasant Panchami 2027', 'सरस्वती पूजा 2027', 'सरस्वती पूजा 2027', '2027-02-11', '2027-02-12', true)
ON CONFLICT (name) DO NOTHING;

-- 2. Default Production Stages
INSERT INTO default_stages (stage_key, display_order, display_name_en, display_name_hi, display_name_mr, icon_name, is_active)
VALUES
  ('booking_confirmed', 1, 'Booking Confirmed', 'बुकिंग पक्की', 'बुकिंग निश्चित', 'check_circle', true),
  ('design_approved', 2, 'Design Approved', 'डिज़ाइन स्वीकृत', 'डिझाइन मंजूर', 'design_services', true),
  ('base_structure_ready', 3, 'Base Structure Ready', 'आधार ढांचा तैयार', 'मूळ रचना तयार', 'foundation', true),
  ('painting_in_progress', 4, 'Painting in Progress', 'रंगाई जारी', 'रंगकाम सुरू', 'brush', true),
  ('ornamentation', 5, 'Ornamentation & Shringar', 'आभूषण व श्रृंगार', 'अलंकार व शृंगार', 'diamond', true),
  ('quality_check', 6, 'Quality Check Complete', 'गुणवत्ता जांच पूर्ण', 'गुणवत्ता तपासणी पूर्ण', 'verified', true),
  ('ready_for_pickup', 7, 'Ready for Pickup / Delivery', 'लेने के लिए तैयार', 'नेण्यासाठी तयार', 'local_shipping', true),
  ('delivered', 8, 'Delivered with Blessings', 'शुभ विसर्जन / वितरित', 'वितरित', 'celebration', true)
ON CONFLICT (stage_key) DO NOTHING;

-- 3. Initial Platform Admin User (Password: Admin@Murti2026)
-- Hash generated via bcrypt / SHA256 standard
INSERT INTO users (id, name, shop_name, city, area, phone, whatsapp_number, idol_types, experience_years, status, role, password_hash)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'MurtiTrack Platform Admin',
  'MurtiTrack HQ',
  'Mumbai',
  'Dadar',
  '9999999999',
  '9999999999',
  ARRAY['ganesha'::idol_type, 'durga'::idol_type],
  15,
  'approved',
  'platform_admin',
  'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec'
)
ON CONFLICT (phone) DO NOTHING;

-- 4. Initial Sample Murtikar (Password: Murtikar@123)
INSERT INTO users (id, name, shop_name, city, area, phone, whatsapp_number, idol_types, experience_years, status, role, password_hash)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Ramesh Chandra Pal',
  'Shree Ganesh Kalakendra',
  'Pune',
  'Kasba Peth',
  '9823012345',
  '9823012345',
  ARRAY['ganesha'::idol_type, 'durga'::idol_type, 'lakshmi'::idol_type],
  22,
  'approved',
  'murtikar',
  'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec'
)
ON CONFLICT (phone) DO NOTHING;

-- 5. Sample Booking
INSERT INTO bookings (
  id,
  booking_number,
  murtikar_id,
  customer_name,
  customer_phone,
  festival,
  idol_type,
  size,
  material,
  total_amount,
  advance_amount,
  advance_received_date,
  advance_mode,
  advance_note,
  current_status,
  expected_delivery_date,
  notes
)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  'MUR-2026-00001',
  '11111111-1111-1111-1111-111111111111',
  'Anand Deshmukh (Sarvajanik Mandal)',
  '9850123456',
  'ganesh_utsav_2026',
  'ganesha',
  '8 feet (Lalbaugcha Raja Style)',
  'clay',
  45000.00,
  15000.00,
  '2026-06-15',
  'upi',
  'Google Pay Ref: UPI/9382103810',
  'painting_in_progress',
  '2026-09-12',
  'Traditional saffron pitambar, gold mukut with pearl border.'
)
ON CONFLICT (booking_number) DO NOTHING;

-- 6. Sample Authorized Phone for Customer Tracking (PIN: 1234)
INSERT INTO booking_authorized_phones (
  id,
  booking_id,
  phone_number,
  label,
  auth_type,
  pin_hash,
  is_primary,
  is_blocked
)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  '22222222-2222-2222-2222-222222222222',
  '9850123456',
  'buyer',
  'pin',
  '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
  true,
  false
)
ON CONFLICT (booking_id, phone_number) DO NOTHING;

-- 7. Initial Status Updates
INSERT INTO status_updates (booking_id, status_stage, note, created_at)
VALUES
  ('22222222-2222-2222-2222-222222222222', 'booking_confirmed', 'Order booked with token advance received.', NOW() - INTERVAL '30 days'),
  ('22222222-2222-2222-2222-222222222222', 'design_approved', 'Sketch & pose finalized with Mandal trustees.', NOW() - INTERVAL '22 days'),
  ('22222222-2222-2222-2222-222222222222', 'base_structure_ready', 'Eco-friendly clay sculpting completed.', NOW() - INTERVAL '14 days'),
  ('22222222-2222-2222-2222-222222222222', 'painting_in_progress', 'First layer natural color shading ongoing.', NOW() - INTERVAL '2 days');
