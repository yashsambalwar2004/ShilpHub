"""
Comprehensive End-to-End API and Security Test Suite for MurtiTrack.
Verifies all 6 deliverables' critical paths and security rules.
"""

import sys
from fastapi.testclient import TestClient
from main import app
import database

client = TestClient(app)

def run_tests():
    print("=== STARTING MURTITRACK VERIFICATION TESTS ===")
    
    # Reset and seed database
    database.init_db()
    conn = database.get_connection()
    conn.execute("DELETE FROM users WHERE phone = '9822998877'")
    conn.execute("DELETE FROM bookings WHERE customer_phone = '9811122233'")
    conn.commit()
    conn.close()

    # 1. Admin Login
    res = client.post("/api/auth/login", json={"phone": "9999999999", "password": "Admin@Murti2026"})
    assert res.status_code == 200, f"Admin login failed: {res.text}"
    admin_token = res.json()["token"]
    print("[PASS] Test 1: Admin login successful")

    # 2. Murtikar Registration & Admin Review Flow
    new_phone = "9822998877"
    reg_res = client.post("/api/murtikars/register", json={
        "name": "Kailash Jadhav",
        "shop_name": "Jadhav Murti Kala",
        "city": "Nagpur",
        "phone": new_phone,
        "password": "Password@123",
        "experience_years": 12,
        "idol_types": ["durga", "ganesha"]
    })
    assert reg_res.status_code == 200, f"Registration failed: {reg_res.text}"
    new_murtikar_id = reg_res.json()["user_id"]
    print("[PASS] Test 2: Murtikar self-registration creates pending account")

    # Attempting login before approval must fail with 403
    unapproved_login = client.post("/api/auth/login", json={"phone": new_phone, "password": "Password@123"})
    assert unapproved_login.status_code == 403, "Unapproved murtikar should not be allowed to log in"
    print("[PASS] Test 3: Unapproved murtikar blocked from logging in with 403")

    # Admin approves murtikar
    appr_res = client.post(f"/api/admin/murtikars/{new_murtikar_id}/approve", headers={"Authorization": f"Bearer {admin_token}"})
    assert appr_res.status_code == 200
    print("[PASS] Test 4: Admin successfully approved murtikar")

    # Now login succeeds
    murtikar_login = client.post("/api/auth/login", json={"phone": new_phone, "password": "Password@123"})
    assert murtikar_login.status_code == 200
    murtikar_token = murtikar_login.json()["token"]
    print("[PASS] Test 5: Approved murtikar logged in successfully")

    # 3. Create Booking & Auto-Generate Booking Number
    book_res = client.post("/api/bookings", headers={"Authorization": f"Bearer {murtikar_token}"}, json={
        "customer_name": "Sunil Patil",
        "customer_phone": "9811122233",
        "festival": "navratri_2026",
        "idol_type": "durga",
        "size": "6 feet Mahishasuramardini",
        "material": "clay",
        "total_amount": 35000.0,
        "advance_amount": 10000.0,
        "advance_received_date": "2026-06-20",
        "advance_mode": "upi",
        "advance_note": "Token Advance via UPI",
        "expected_delivery_date": "2026-10-08",
        "notes": "Red silk saree drape with golden trishul.",
        "customer_auth_type": "pin",
        "customer_credential": "4321"
    })
    assert book_res.status_code == 200, f"Booking create failed: {book_res.text}"
    booking_data = book_res.json()
    booking_id = booking_data["booking_id"]
    booking_no = booking_data["booking_number"]
    assert booking_no.startswith("MUR-"), f"Invalid booking format: {booking_no}"
    print(f"[PASS] Test 6: Booking created with sequential number: {booking_no}")

    # 4. Customer 7-Step Login Authentication
    # 4a: Wrong PIN must fail with generic error
    wrong_pin_res = client.post("/api/auth/customer/login", json={
        "booking_number": booking_no,
        "phone": "9811122233",
        "credential": "9999"
    })
    assert wrong_pin_res.status_code == 401
    assert "Invalid booking number" in wrong_pin_res.json()["detail"]
    print("[PASS] Test 7: Invalid PIN rejected with generic anti-enumeration error")

    # 4b: Correct PIN succeeds
    cust_res = client.post("/api/auth/customer/login", json={
        "booking_number": booking_no,
        "phone": "9811122233",
        "credential": "4321"
    })
    assert cust_res.status_code == 200
    customer_token = cust_res.json()["token"]
    print("[PASS] Test 8: Customer 7-step authentication succeeded with valid token")

    # 5. Customer Read-Only Tracking View
    track_res = client.get("/api/customer/booking", headers={"Authorization": f"Bearer {customer_token}"})
    assert track_res.status_code == 200
    track_data = track_res.json()
    assert track_data["booking_number"] == booking_no
    assert track_data["total_amount"] == 35000.0
    assert track_data["total_paid"] == 10000.0
    assert track_data["balance_due"] == 25000.0
    print("[PASS] Test 9: Customer order tracking view verified (read-only balance & details)")

    # 6. Payment Overpayment Prevention Rule
    # Attempting to record balance payment of ₹30,000 when balance is only ₹25,000 must fail with 400
    excess_pay = client.post(f"/api/bookings/{booking_id}/payments", headers={"Authorization": f"Bearer {murtikar_token}"}, json={
        "amount": 30000.0,
        "payment_date": "2026-07-01",
        "payment_mode": "cash"
    })
    assert excess_pay.status_code == 400
    assert "exceeds remaining balance" in excess_pay.json()["detail"]
    print("[PASS] Test 10: Overpayment prevention rule successfully blocked excess amount")

    # Valid balance payment of ₹15,000
    valid_pay = client.post(f"/api/bookings/{booking_id}/payments", headers={"Authorization": f"Bearer {murtikar_token}"}, json={
        "amount": 15000.0,
        "payment_date": "2026-07-01",
        "payment_mode": "cash",
        "note": "Second installment in cash"
    })
    assert valid_pay.status_code == 200
    print("[PASS] Test 11: Valid balance payment recorded successfully")

    # 7. Payment Mode Summaries (No Double Counting)
    summary_res = client.get("/api/murtikar/payment-summaries", headers={"Authorization": f"Bearer {murtikar_token}"})
    assert summary_res.status_code == 200
    s_data = summary_res.json()
    assert s_data["grand_total"] == 25000.0, f"Expected ₹25,000 total, got {s_data['grand_total']}"
    assert s_data["mode_breakdown"]["upi"]["total"] == 10000.0  # Advance
    assert s_data["mode_breakdown"]["cash"]["total"] == 15000.0 # Balance
    print("[PASS] Test 12: Mode-wise payment summary validated without double counting")

    # 8. Status Progression
    status_adv = client.post(f"/api/bookings/{booking_id}/status", headers={"Authorization": f"Bearer {murtikar_token}"}, data={
        "status_stage": "painting_in_progress",
        "note": "Clay work dry, applying natural colors"
    })
    assert status_adv.status_code == 200
    print("[PASS] Test 13: Production status advanced to 'painting_in_progress'")

    # 9. Customer Change Request (JSON and Multipart with Image)
    cr_res = client.post("/api/customer/change-requests", headers={"Authorization": f"Bearer {customer_token}"}, json={
        "change_type": "color",
        "description": "Please ensure the lion vahana is painted in royal gold."
    })
    assert cr_res.status_code == 200
    
    # Test Multipart upload with image attachment
    cr_img_res = client.post(
        "/api/customer/change-requests",
        headers={"Authorization": f"Bearer {customer_token}"},
        data={"change_type": "ornaments", "description": "Add gold crown details as shown in photo"},
        files={"image": ("reference.jpg", b"\xFF\xD8\xFF\xE0fakejpgheaderdata", "image/jpeg")}
    )
    assert cr_img_res.status_code == 200
    print("[PASS] Test 14: Customer design change request submitted successfully (JSON & Multipart Image)")

    # 10. Phone Access Revocation / Blocking
    block_ph = client.post("/api/murtikar/block-list", headers={"Authorization": f"Bearer {murtikar_token}"}, json={
        "phone_number": "9811122233",
        "reason": "Test block"
    })
    assert block_ph.status_code == 200
    
    # Now customer token must immediately fail with 403 on re-verification
    blocked_check = client.get("/api/customer/booking", headers={"Authorization": f"Bearer {customer_token}"})
    assert blocked_check.status_code == 403
    print("[PASS] Test 15: Phone blocked across workshop immediately revokes customer access")

    print("\n=======================================================")
    print("ALL 15 END-TO-END ACCEPTANCE TESTS PASSED SUCCESSFULLY!")
    print("=======================================================")

if __name__ == "__main__":
    run_tests()
