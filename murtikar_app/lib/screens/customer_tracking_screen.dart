import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';

import 'support_chat_screen.dart';

class CustomerTrackingScreen extends StatefulWidget {
  const CustomerTrackingScreen({super.key});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final loc = LocalizationService.instance;
  Map<String, dynamic>? _bookingData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final data = await ApiService.getCustomerBookingDetails();
      setState(() {
        _bookingData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showChangeRequestDialog(String bookingId) {
    String type = 'color';
    final descCtrl = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Request Design Change', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(labelText: 'Change Type', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                    items: const [
                      DropdownMenuItem(value: 'color', child: Text('Color Adjustment')),
                      DropdownMenuItem(value: 'ornament', child: Text('Jewellery / Ornaments')),
                      DropdownMenuItem(value: 'size_adjustment', child: Text('Size Adjustment')),
                      DropdownMenuItem(value: 'face_expression', child: Text('Face Expression')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => type = v!,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Describe what you want changed',
                      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                      hintText: 'e.g. Please make the dhoti yellow instead of red.',
                      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF222232)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (img != null) {
                            setDialogState(() => selectedImagePath = img.path);
                          }
                        },
                        icon: const Icon(Icons.photo, color: Color(0xFFF39C12)),
                        label: const Text('Reference Image', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      if (selectedImagePath != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey : Colors.black54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD35400)),
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  try {
                    await ApiService.submitChangeRequest(bookingId, type, descCtrl.text.trim(), imagePath: selectedImagePath);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to workshop!'), backgroundColor: Colors.green));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showRatingDialog(String bookingId) {
    int score = 10;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Rate Your Experience', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How would you rate the idol and service?', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text('$score / 10', style: const TextStyle(color: Color(0xFFF39C12), fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: score.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: const Color(0xFFF39C12),
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setDialogState(() => score = v.toInt()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Additional Feedback (Optional)',
                      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                      hintText: 'e.g. Very beautiful idol!',
                      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD35400)),
                onPressed: () async {
                  try {
                    await ApiService.submitRating(bookingId, score, noteCtrl.text.trim());
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your rating!'), backgroundColor: Colors.green));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Submit Rating', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
      );
    }

    if (_error != null || _bookingData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Tracking Error'), backgroundColor: theme.colorScheme.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Unable to load booking', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _logout, child: const Text('Go Back'))
            ],
          ),
        ),
      );
    }

    final b = _bookingData!;
    final total = b['total_amount'] ?? 0;
    final paid = b['total_paid'] ?? 0;
    final due = b['balance_due'] ?? 0;
    final bookingId = b['id'] ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Text('${b['booking_number']} Tracking', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          IconButton(icon: Icon(Icons.logout, color: theme.colorScheme.secondary), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['idol_type']?.toString().toUpperCase() ?? '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                    const SizedBox(height: 8),
                    Text('Booked for: ${b['customer_name']}', style: TextStyle(color: theme.colorScheme.onSurface)),
                    Text('Delivery: ${b['expected_delivery_date']}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Current Stage: ${b['current_status']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),
            if (b['current_status'] != 'ready_for_pickup' && b['current_status'] != 'delivered')
              ElevatedButton.icon(
                onPressed: () => _showChangeRequestDialog(bookingId),
                icon: const Icon(Icons.edit_note, color: Colors.white),
                label: const Text('Request Design Adjustment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().fade(delay: 200.ms)
            else
              ElevatedButton.icon(
                onPressed: () => _showRatingDialog(bookingId),
                icon: const Icon(Icons.star, color: Colors.white),
                label: const Text('Rate Your Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().fade(delay: 200.ms),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Total Amount', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)), Text('₹$total', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))],
                    ),
                    Divider(color: isDark ? Colors.white10 : Colors.black12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Total Paid', style: TextStyle(color: Colors.green)), Text('₹$paid', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))],
                    ),
                    Divider(color: isDark ? Colors.white10 : Colors.black12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Balance Due', style: TextStyle(color: Colors.redAccent)), Text('₹$due', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))],
                    ),
                  ],
                ),
              ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workshop Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Text('${b['shop_name']}', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 16)),
                    Text('${b['murtikar_name']}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                    Text('${b['city']}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                  ],
                ),
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SupportChatScreen(bookingId: bookingId, isCustomer: true)));
        },
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
