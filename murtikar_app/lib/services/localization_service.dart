import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService instance = LocalizationService._internal();
  LocalizationService._internal();

  String _currentLocale = 'en';
  String get currentLocale => _currentLocale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('murtitrack_locale') ?? 'en';
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    if (_currentLocale == langCode) return;
    _currentLocale = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('murtitrack_locale', langCode);
    notifyListeners();
  }

  String t(String key) {
    return _localizedStrings[_currentLocale]?[key] ?? _localizedStrings['en']?[key] ?? key;
  }

  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  static String formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  static final Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'app_title': 'ShilpHub',
      'sub_title': 'Digital Workshop Register',
      'login': 'Login to Register',
      'register': 'New Artisan Registration',
      'phone_label': 'Mobile Number',
      'password_label': 'Password',
      'dashboard': 'Workshop Register',
      'orders': 'Idol Bookings',
      'new_booking': 'New Booking',
      'total_revenue': 'Total Bookings',
      'total_received': 'Cash & UPI Received',
      'pending_balance': 'Balance Due',
      'all_festivals': 'All Festivals',
      'filter_stage': 'Filter by Stage',
      'search_placeholder': 'Search customer/mandal, phone or booking no...',
      'stage_booking_confirmed': 'Booking Confirmed',
      'stage_design_approved': 'Design Approved',
      'stage_base_structure_ready': 'Base Structure Ready',
      'stage_painting_in_progress': 'Painting in Progress',
      'stage_ornamentation': 'Ornamentation & Shringar',
      'stage_quality_check': 'Quality Check Complete',
      'stage_ready_for_pickup': 'Ready for Pickup',
      'stage_delivered': 'Delivered with Blessings',
      'advance_stage': 'Advance to Next Stage',
      'payments': 'Payments',
      'record_payment': 'Record Payment',
      'authorized_phones': 'Authorized Tracking Phones',
      'change_requests': 'Change Requests',
      'ratings': 'Customer Ratings',
      'workshop_blocklist': 'Workshop Block List',
      'logout': 'Sign Out',
    },
    'hi': {
      'app_title': 'मूर्ति-ट्रैक',
      'sub_title': 'डिजिटल मूर्तिकार रजिस्टर',
      'login': 'रजिस्टर में लॉगिन करें',
      'register': 'नया मूर्तिकार पंजीकरण',
      'phone_label': 'मोबाइल नंबर',
      'password_label': 'पासवर्ड',
      'dashboard': 'कार्यशाला रजिस्टर',
      'orders': 'मूर्ति बुकिंग्स',
      'new_booking': 'नई बुकिंग दर्ज करें',
      'total_revenue': 'कुल बुकिंग राशि',
      'total_received': 'नकद व UPI प्राप्त',
      'pending_balance': 'शेष राशि',
      'all_festivals': 'सभी उत्सव',
      'filter_stage': 'चरण अनुसार फ़िल्टर',
      'search_placeholder': 'ग्राहक / मंडल का नाम, फोन या बुकिंग नंबर खोजें...',
      'stage_booking_confirmed': 'बुकिंग पक्की',
      'stage_design_approved': 'डिज़ाइन स्वीकृत',
      'stage_base_structure_ready': 'आधार ढांचा तैयार',
      'stage_painting_in_progress': 'रंगाई जारी',
      'stage_ornamentation': 'आभूषण व श्रृंगार',
      'stage_quality_check': 'गुणवत्ता जांच पूर्ण',
      'stage_ready_for_pickup': 'लेने के लिए तैयार',
      'stage_delivered': 'शुभ विसर्जन / वितरित',
      'advance_stage': 'अगले चरण में बढ़ाएं',
      'payments': 'भुगतान',
      'record_payment': 'भुगतान दर्ज करें',
      'authorized_phones': 'ट्रैकिंग अधिकृत नंबर',
      'change_requests': 'बदलाव अनुरोध',
      'ratings': 'ग्राहक समीक्षा एवं रेटिंग',
      'workshop_blocklist': 'ब्लॉक नंबर सूची',
      'logout': 'लॉगआउट',
    },
    'mr': {
      'app_title': 'मूर्ती-ट्रॅक',
      'sub_title': 'डिजिटल मूर्तिकार रजिस्टर',
      'login': 'रजिस्टरमध्ये लॉगिन करा',
      'register': 'नवीन मूर्तिकार नोंदणी',
      'phone_label': 'मोबाईल क्रमांक',
      'password_label': 'पासवर्ड',
      'dashboard': 'कार्यशाळा रजिस्टर',
      'orders': 'मूर्ती बुकिंग्ज',
      'new_booking': 'नवीन बुकिंग नोंदवा',
      'total_revenue': 'एकूण बुकिंग रक्कम',
      'total_received': 'रोख व UPI जमा',
      'pending_balance': 'शिल्लक रक्कम',
      'all_festivals': 'सर्व उत्सव',
      'filter_stage': 'टप्प्यानुसार निवडा',
      'search_placeholder': 'ग्राहक / मंडळाचे नाव, फोन किंवा बुकिंग क्रमांक शोधा...',
      'stage_booking_confirmed': 'बुकिंग निश्चित',
      'stage_design_approved': 'डिझाइन मंजूर',
      'stage_base_structure_ready': 'मूळ रचना तयार',
      'stage_painting_in_progress': 'रंगकाम सुरू',
      'stage_ornamentation': 'अलंकार व शृंगार',
      'stage_quality_check': 'गुणवत्ता तपासणी पूर्ण',
      'stage_ready_for_pickup': 'नेण्यासाठी तयार',
      'stage_delivered': 'वितरित / शुभ विसर्जन',
      'advance_stage': 'पुढील टप्प्यावर न्या',
      'payments': 'पैसे भरणा',
      'record_payment': 'रक्कम जमा नोंदवा',
      'authorized_phones': 'ट्रॅकिंग अधिकृत मोबाईल',
      'change_requests': 'बदल विनंती',
      'ratings': 'ग्राहक अभिप्राय व रेटिंग',
      'workshop_blocklist': 'ब्लॉक नंबर यादी',
      'logout': 'बाहेर पडा',
    }
  };
}
