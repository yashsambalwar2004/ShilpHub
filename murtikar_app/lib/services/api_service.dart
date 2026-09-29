import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Can be configured to point to remote server or localhost
  //
  // IMPORTANT: '127.0.0.1' / 'localhost' will NOT work from a physical
  // phone — it points to the phone itself, not your computer.
  // Phone and PC must be on the SAME Wi-Fi network.
  // Backend must be run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
  static String baseUrl = 'https://shilphub.onrender.com/api';

  static String? _token;

  /// Booking id of the support chat currently on screen (null if none).
  /// Used to avoid showing a notification banner for the chat you are reading.
  static String? activeChatBookingId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('murtitrack_jwt');
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('murtitrack_jwt', token);
    // Register this phone for push notifications as soon as anyone logs in
    // (murtikar or customer). Runs in the background; failures are ignored.
    unawaited(syncPushToken());
  }

  static Future<void> logout() async {
    // Stop push notifications for this user on this device (best effort)
    try {
      final fcm = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
      if (fcm != null && _token != null) {
        await http
            .post(
              Uri.parse('$baseUrl/auth/device-token/remove'),
              headers: _headers(),
              body: jsonEncode({'fcm_token': fcm}),
            )
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('murtitrack_jwt');
  }

  static bool get isLoggedIn => _token != null;

  static Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Safely extracts an error message from a failed response.
  /// Handles non-JSON bodies (e.g. plain-text 500s) and FastAPI's
  /// list-style 422 validation errors.
  static String _errorDetail(http.Response res, String fallback) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) return first['msg'].toString();
        }
        return detail.toString();
      }
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }

  // --- Auth ---
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await setToken(data['token']);
      return data;
    }
    throw Exception(data['detail'] ?? 'Login failed');
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/murtikars/change-password'),
      headers: _headers(),
      body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to change password'));
    }
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> regData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/murtikars/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(regData),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(_errorDetail(res, 'Registration failed'));
  }

  /// Customer tracking login: booking number + phone + PIN/password.
  static Future<Map<String, dynamic>> customerLogin(
      String bookingNumber, String phone, String credential) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/customer/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'booking_number': bookingNumber,
        'phone': phone,
        'credential': credential,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await setToken(data['token']);
      return data;
    }
    throw Exception(_errorDetail(res, 'Login failed'));
  }

  // --- Push notifications ---
  static Future<void> registerDeviceToken(String fcmToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/device-token'),
      headers: _headers(),
      body: jsonEncode({'fcm_token': fcmToken}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to register device token'));
    }
  }

  /// Gets this device's FCM token and registers it for the logged-in user.
  /// Safe to call anytime: does nothing if not logged in or Firebase is unavailable.
  static Future<void> syncPushToken() async {
    try {
      if (_token == null) return;
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null) await registerDeviceToken(fcm);
    } catch (e) {
      debugPrint('Push token sync failed: $e');
    }
  }

  // --- Bookings ---
  static Future<Map<String, dynamic>> getBookings({String? festival, String? stage, String? search}) async {
    String url = '$baseUrl/bookings?';
    if (festival != null && festival.isNotEmpty) url += 'festival=${Uri.encodeQueryComponent(festival)}&';
    if (stage != null && stage.isNotEmpty) url += 'stage=${Uri.encodeQueryComponent(stage)}&';
    if (search != null && search.isNotEmpty) url += 'search=${Uri.encodeQueryComponent(search)}&';

    final res = await http.get(Uri.parse(url), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load bookings');
  }

  static Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final res = await http.get(Uri.parse('$baseUrl/bookings/$bookingId'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load booking details');
  }

  /// On success the response may include `customer_pin` when the backend
  /// generated a PIN for the customer. Show it to the murtikar once.
  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    }
    throw Exception(data['detail'] ?? 'Failed to create booking');
  }

  static Future<void> updateBooking(String bookingId, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Failed to update booking');
    }
  }

  static Future<void> deleteBooking(String bookingId) async {
    final res = await http.delete(Uri.parse('$baseUrl/bookings/$bookingId'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to delete booking');
    }
  }

  // --- Status Updates ---
  /// [imagePath] is an optional local file path of a progress photo
  /// (uploaded as the `photo` field; backend accepts JPG/PNG/WEBP up to 8 MB).
  static Future<void> updateStatus(String bookingId, String stage,
      {String? note, String? imagePath}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/bookings/$bookingId/status'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.fields['status_stage'] = stage;
    if (note != null && note.isNotEmpty) req.fields['note'] = note;
    if (imagePath != null && imagePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('photo', imagePath));
    }

    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to update status'));
    }
  }

  // --- Authorized Phones ---
  static Future<void> addAuthorizedPhone(String bookingId, String phone, String label, String authType, String credential) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/phones'),
      headers: _headers(),
      body: jsonEncode({
        'phone_number': phone,
        'label': label,
        'auth_type': authType,
        'credential': credential,
      }),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Failed to authorize phone');
    }
  }

  static Future<void> removeAuthorizedPhone(String bookingId, String phoneId) async {
    final res = await http.delete(Uri.parse('$baseUrl/bookings/$bookingId/phones/$phoneId'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to remove phone');
    }
  }

  static Future<bool> togglePhoneBlock(String bookingId, String phoneId) async {
    final res = await http.post(Uri.parse('$baseUrl/bookings/$bookingId/phones/$phoneId/toggle-block'), headers: _headers());
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['is_blocked'] ?? false;
    }
    throw Exception('Failed to toggle block status');
  }

  // --- Workshop Block List ---
  static Future<List<dynamic>> getBlockList() async {
    final res = await http.get(Uri.parse('$baseUrl/murtikar/block-list'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<void> blockPhone(String phone, String? reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/murtikar/block-list'),
      headers: _headers(),
      body: jsonEncode({'phone_number': phone, 'reason': reason}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to block phone');
    }
  }

  static Future<void> unblockPhone(String phone) async {
    final res = await http.delete(Uri.parse('$baseUrl/murtikar/block-list/$phone'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to unblock phone');
    }
  }

  // --- Payments ---
  static Future<void> recordPayment(String bookingId, double amount, String date, String mode, String? note) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/payments'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
        'payment_date': date,
        'payment_mode': mode,
        'note': note,
      }),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Payment recording failed');
    }
  }

  static Future<Map<String, dynamic>> getPaymentSummaries({String? festival}) async {
    String url = '$baseUrl/murtikar/payment-summaries?';
    if (festival != null && festival.isNotEmpty) url += 'festival=${Uri.encodeQueryComponent(festival)}';
    final res = await http.get(Uri.parse(url), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load payment summaries');
  }

  // --- Change Requests (murtikar side) ---
  static Future<void> respondToChangeRequest(String bookingId, String crId, String status, String? response, double extraCharge) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/change-requests/$crId/respond'),
      headers: _headers(),
      body: jsonEncode({
        'status': status,
        'murtikar_response': response,
        'extra_charge': extraCharge,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to respond to change request'));
    }
  }

  // --- Customer tracking (customer side) ---
  static Future<Map<String, dynamic>> getCustomerBookingDetails() async {
    final res = await http.get(Uri.parse('$baseUrl/customer/booking'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(_errorDetail(res, 'Failed to load your booking'));
  }

  /// [bookingId] and [imagePath] are accepted for compatibility with the screens,
  /// but the backend identifies the booking from the login token and does not
  /// yet store images for change requests, so only type + description are sent.
  static Future<void> submitChangeRequest(String bookingId, String type, String description,
      {String? imagePath}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/change-requests'),
      headers: _headers(),
      body: jsonEncode({'change_type': type, 'description': description}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to submit change request'));
    }
  }

  static Future<void> submitRating(String bookingId, num score, String note) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customer/ratings'),
      headers: _headers(),
      body: jsonEncode({'score': score.round(), 'note': note.isEmpty ? null : note}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to submit rating'));
    }
  }

  // --- Support Chat ---
  /// Returns the list of messages for a booking.
  /// The backend responds with {"messages": [...]}; a bare list is also accepted.
  static Future<List<dynamic>> getMessages(String bookingId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/bookings/$bookingId/messages'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map && data['messages'] is List) {
        return List<dynamic>.from(data['messages']);
      }
      if (data is List) return data;
      return [];
    }
    throw Exception(_errorDetail(res, 'Failed to load messages'));
  }

  static Future<void> sendMessage(String bookingId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/messages'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res, 'Failed to send message'));
    }
  }

  // --- Ratings ---
  static Future<Map<String, dynamic>> getRatings() async {
    final res = await http.get(Uri.parse('$baseUrl/murtikar/ratings'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {'average_score': 0.0, 'total_reviews': 0, 'reviews': []};
  }

  // --- Metadata ---
  static Future<List<dynamic>> getFestivals() async {
    final res = await http.get(Uri.parse('$baseUrl/festivals'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getDefaultStages() async {
    final res = await http.get(Uri.parse('$baseUrl/default-stages'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }
}
