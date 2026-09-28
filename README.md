# 🪔 MurtiTrack — Festival Idol Order Management & Customer Tracking Platform

A dedicated **digital business register and customer order-tracking platform** designed specifically for Indian murtikars (idol makers) crafting deities of **Lord Ganesha, Goddess Durga, Goddess Lakshmi, and Goddess Saraswati** during peak festival seasons (Ganesh Utsav, Navratri, Diwali, and Saraswati Puja).

---

## 🌟 Key Architecture & Highlights

1. **Digital Business Register (Not an eCommerce or Payment App)**
   - Replaces handwritten paper registers with a secure, cloud-enabled register.
   - All financial settlements occur **directly between customer and artisan** in cash or UPI.
   - No payment gateway integration or SMS/OTP fees; costs are minimized for artisans.

2. **Strict Multi-Tenant Isolation**
   - Each artisan accesses only their own bookings, payments, and customer tracking numbers.
   - Sequential booking numbers are generated per-murtikar (`MUR-YYYY-XXXXX`), preventing enumeration across workshops.
   - PostgreSQL Row-Level Security (RLS) policies enforce database-level tenant isolation.

3. **7-Step Customer Authorization Check**
   - Access to order tracking requires:
     1. Rate-limiting check (<5 failed attempts / 15 min)
     2. Valid booking number
     3. Active booking (not deleted)
     4. Approved artisan account
     5. Workshop block list verification
     6. Authorized phone number check
     7. Password / 4-6 digit PIN cryptographic hash check
   - Returns **generic error messages** on any failure to prevent phone and booking enumeration.

4. **14-Day Image Auto-Deletion Worker**
   - Status photos and design references are automatically purged from storage and database after 14 days.
   - **Business text records, status history, and payment details are preserved permanently.**

5. **Trilingual Localization**
   - Native support for **English**, **हिन्दी (Hindi)**, and **मराठी (Marathi)**.

---

## 📂 Repository Structure

```
d:/idol_app/
├── database/                        -- PostgreSQL & Supabase Database Assets
│   ├── 01_schema.sql                -- 15 Tables, enums, triggers, and functions
│   ├── 02_rls_policies.sql          -- Row-Level Security tenant isolation policies
│   ├── 03_seed_data.sql             -- Festivals, 8 production stages, admin, demo murtikar
│   └── 04_cleanup_cron.sql          -- 14-day image cleanup and maintenance cron jobs
│
├── backend/                         -- Master FastAPI REST API Engine
│   ├── main.py                      -- Complete API endpoints (Auth, Bookings, Payments, Tracking)
│   ├── database.py                  -- SQLite / PostgreSQL DB layer with auto-migration
│   ├── auth.py                      -- JWT tokens, 7-step customer authorization, audit logging
│   ├── cleanup_worker.py            -- Background daemon for 14-day media TTL purging
│   ├── test_api.py                  -- 15 End-to-end acceptance tests (all passing)
│   ├── requirements.txt             -- Python dependencies
│   └── uploads/                     -- Local media uploads directory
│
├── customer_web/                    -- Responsive Web Portals
│   ├── index.html                   -- Customer Order Tracking Portal (8-stage stepper, receipt)
│   └── admin.html                   -- Platform Admin Console (Murtikar approval, metrics, audit)
│
├── murtikar_app/                    -- Full-Featured Flutter Application
│   ├── pubspec.yaml                 -- Flutter dependencies (http, intl, shared_preferences)
│   └── lib/
│       ├── main.dart                -- App entry point & Material 3 festive dark theme
│       ├── services/
│       │   ├── api_service.dart     -- REST API client
│       │   └── localization_service.dart -- English, Hindi, Marathi dictionary & formatters
│       └── screens/
│           ├── login_screen.dart    -- Artisan login & registration
│           ├── dashboard_screen.dart-- Register cards, financial totals, festival chips
│           ├── new_booking_screen.dart -- Booking creation form & customer tracking setup
│           ├── booking_detail_screen.dart -- Status stepper, payments, authorized phones, changes
│           ├── payment_summary_screen.dart -- Cash vs UPI vs Bank breakdown
│           ├── workshop_blocklist_screen.dart -- Workshop-wide phone blocking
│           └── ratings_screen.dart  -- Customer review & blessings scores
│
├── start_backend.bat                -- 1-Click launcher for Backend server
└── start_flutter_app.bat            -- 1-Click launcher for Flutter app (Windows desktop)
```

---

## 🚀 How to Run

### Step 1: Start the Backend Server

Open PowerShell or Command Prompt:

```powershell
cd d:\idol_app\backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

*Or simply double-click `start_backend.bat`!*

The backend will start at:
- **API Base URL**: `http://10.201.44.176:8000`
- **Interactive OpenAPI Documentation**: `http://10.201.44.176:8000/docs`
- **Customer Order Tracking Web Portal**: `http://10.201.44.176:8000/tracking`
- **Platform Admin Dashboard**: `http://10.201.44.176:8000/admin`

---

### Step 2: Run the Flutter Application

In another terminal:

```powershell
cd d:\idol_app\murtikar_app
flutter run -d windows
```

*(You can also run on Android by plugging in an Android device or emulator with `flutter run`)*

*Or simply double-click `start_flutter_app.bat`!*

---

## 🔑 Default Credentials for Testing

### 1. Master Artisan (Murtikar)
- **Mobile**: `9823012345`
- **Password**: `Murtikar@123`
- **Artisan**: Ramesh Chandra Pal (*Shree Ganesh Kalakendra, Pune*)
- **Sample Booking**: `MUR-2026-00001`

### 2. Customer Order Tracking (Customer / Devotee)
- **Portal URL**: `http://10.201.44.176:8000/tracking`
- **Booking Number**: `MUR-2026-00001`
- **Mobile Number**: `9850123456`
- **Security PIN**: `1234`

### 3. Platform Admin
- **Console URL**: `http://10.201.44.176:8000/admin`
- **Mobile**: `9999999999`
- **Password**: `Admin@Murti2026`

---

## 🧪 Automated Test Suite

To verify all 15 acceptance criteria:

```powershell
cd d:\idol_app\backend
python test_api.py
```

Expected output:
```
=== STARTING MURTITRACK VERIFICATION TESTS ===
[PASS] Test 1: Admin login successful
[PASS] Test 2: Murtikar self-registration creates pending account
[PASS] Test 3: Unapproved murtikar blocked from logging in with 403
[PASS] Test 4: Admin successfully approved murtikar
[PASS] Test 5: Approved murtikar logged in successfully
[PASS] Test 6: Booking created with sequential number: MUR-2026-00002
[PASS] Test 7: Invalid PIN rejected with generic anti-enumeration error
[PASS] Test 8: Customer 7-step authentication succeeded with valid token
[PASS] Test 9: Customer order tracking view verified (read-only balance & details)
[PASS] Test 10: Overpayment prevention rule successfully blocked excess amount
[PASS] Test 11: Valid balance payment recorded successfully
[PASS] Test 12: Mode-wise payment summary validated without double counting
[PASS] Test 13: Production status advanced to 'painting_in_progress'
[PASS] Test 14: Customer design change request submitted successfully
[PASS] Test 15: Phone blocked across workshop immediately revokes customer access

=======================================================
ALL 15 END-TO-END ACCEPTANCE TESTS PASSED SUCCESSFULLY!
=======================================================
```
