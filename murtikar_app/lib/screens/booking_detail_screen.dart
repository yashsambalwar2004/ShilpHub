import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'support_chat_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final loc = LocalizationService.instance;

  bool _isLoading = true;
  Map<String, dynamic>? _booking;

  final List<Map<String, String>> _allStages = [
    {'key': 'booking_confirmed', 'en': 'Booking Confirmed'},
    {'key': 'design_approved', 'en': 'Design Approved'},
    {'key': 'base_structure_ready', 'en': 'Base Structure Ready'},
    {'key': 'painting_in_progress', 'en': 'Painting in Progress'},
    {'key': 'ornamentation', 'en': 'Ornamentation & Shringar'},
    {'key': 'quality_check', 'en': 'Quality Check Complete'},
    {'key': 'ready_for_pickup', 'en': 'Ready for Pickup'},
    {'key': 'delivered', 'en': 'Delivered with Blessings'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final b = await ApiService.getBookingDetails(widget.bookingId);
      if (mounted) setState(() => _booking = b);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdvanceStatusDialog() {
    final currentStage = _booking?['current_status'] ?? 'booking_confirmed';
    final currentIndex = _allStages.indexWhere((s) => s['key'] == currentStage);
    final nextStage = (currentIndex >= 0 && currentIndex < _allStages.length - 1)
        ? _allStages[currentIndex + 1]['key']!
        : currentStage;

    String selectedStage = nextStage;
    final noteCtrl = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Advance Production Stage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStage,
                    dropdownColor: const Color(0xFF222232),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Target Stage', labelStyle: TextStyle(color: Colors.grey)),
                    items: _allStages.map((s) => DropdownMenuItem(value: s['key'], child: Text(s['en']!))).toList(),
                    onChanged: (v) => selectedStage = v!,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Crafting Note (Visible to Customer)',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'e.g. Clay sculpting complete',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
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
                        icon: const Icon(Icons.photo_library, color: Color(0xFFF39C12)),
                        label: const Text('Attach Photo', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      if (selectedImagePath != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  if (selectedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Image selected', style: const TextStyle(color: Colors.green, fontSize: 12)),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD35400)),
                onPressed: () async {
                  try {
                    await ApiService.updateStatus(widget.bookingId, selectedStage, note: noteCtrl.text.trim(), imagePath: selectedImagePath);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadDetails();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Update Stage', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showRecordPaymentDialog() {
    final balance = (_booking?['balance_due'] as num?)?.toDouble() ?? 0.0;
    final amountCtrl = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(0) : '0');
    final noteCtrl = TextEditingController(text: 'Balance installment');
    String paymentMode = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Record Balance Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining Balance: ${LocalizationService.formatCurrency(balance)}', style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹) *', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: paymentMode,
              dropdownColor: const Color(0xFF222232),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Payment Mode', labelStyle: TextStyle(color: Colors.grey)),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash (रोख)')),
                DropdownMenuItem(value: 'upi', child: Text('UPI (GPay / PhonePe)')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer (NEFT/IMPS)')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => paymentMode = v!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Receipt Note', labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              try {
                final today = DateTime.now().toIso8601String().substring(0, 10);
                await ApiService.recordPayment(widget.bookingId, amt, today, paymentMode, noteCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadDetails();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPhoneDialog() {
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '1234');
    String label = 'family';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Authorize Tracking Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '10-digit Mobile', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: label,
              dropdownColor: const Color(0xFF222232),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Relationship Label', labelStyle: TextStyle(color: Colors.grey)),
              items: const [
                DropdownMenuItem(value: 'buyer', child: Text('Primary Buyer')),
                DropdownMenuItem(value: 'family', child: Text('Family Member')),
                DropdownMenuItem(value: 'friend', child: Text('Friend / Mandal Member')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => label = v!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tracking PIN', labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD35400)),
            onPressed: () async {
              try {
                await ApiService.addAuthorizedPhone(widget.bookingId, phoneCtrl.text.trim(), label, 'pin', pinCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadDetails();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Authorize Phone', style: TextStyle(color: Colors.white)),
          ),
        ],
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

    final b = _booking!;
    final bookingNo = b['booking_number'] ?? '';
    final custName = b['customer_name'] ?? '';
    final total = (b['total_amount'] as num?) ?? 0;
    final paid = (b['total_paid'] as num?) ?? 0;
    final balance = (b['balance_due'] as num?) ?? 0;
    final payments = (b['payments'] as List<dynamic>?) ?? [];
    final phones = (b['authorized_phones'] as List<dynamic>?) ?? [];
    final crs = (b['change_requests'] as List<dynamic>?) ?? [];
    final currentStage = b['current_status'] as String? ?? 'booking_confirmed';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bookingNo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
            Text(custName, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.black54)),
          ],
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF25D366)), // WhatsApp Green
            tooltip: 'Share to WhatsApp',
            onPressed: () async {
              final phones = (_booking?['authorized_phones'] as List<dynamic>?) ?? [];
              String phone = phones.isNotEmpty ? phones[0]['phone_number'] : '';
              final apiUri = Uri.parse(ApiService.baseUrl);
              final trackingLink = "http://${apiUri.host}:8000/tracking"; // Uses actual network IP
              final msg = "Namaskar! 🙏 Your idol booking ($bookingNo) is confirmed. You can track your idol's progress here: $trackingLink \n(Use PIN: 1234 or type your custom PIN here)";
              
              final urlStr = phone.isNotEmpty 
                  ? "https://api.whatsapp.com/send?phone=91$phone&text=${Uri.encodeComponent(msg)}"
                  : "https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}";
                  
              final url = Uri.parse(urlStr);
              
              try {
                final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                if (!launched) {
                  // Fallback for Windows/Desktop if externalApplication fails
                  await launchUrl(url, mode: LaunchMode.platformDefault);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.secondary,
          labelColor: theme.colorScheme.secondary,
          unselectedLabelColor: isDark ? Colors.grey : Colors.black54,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Status Timeline'),
            Tab(icon: Icon(Icons.payments), text: 'Payments'),
            Tab(icon: Icon(Icons.phone_android), text: 'Customer Phones'),
            Tab(icon: Icon(Icons.edit_note), text: 'Change Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: PRODUCTION TIMELINE
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${b['size']} • ${(b['idol_type'] as String).toUpperCase()}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(LocalizationService.formatDate(b['expected_delivery_date']), style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (b['notes'] != null && b['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Crafting notes: ${b['notes']}', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black54, fontSize: 13)),
                      ]
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),

                // Stepper Pipeline
                ..._allStages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  final currentIdx = _allStages.indexWhere((st) => st['key'] == currentStage);
                  final isDone = idx < currentIdx;
                  final isCurrent = idx == currentIdx;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? const Color(0xFF2ECC71)
                                  : (isCurrent ? const Color(0xFFF39C12) : const Color(0xFF222232)),
                              border: Border.all(color: isCurrent ? Colors.white : Colors.transparent, width: 2),
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : Text('${idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCurrent ? Colors.black : Colors.grey)),
                            ),
                          ),
                          if (idx < _allStages.length - 1)
                            Container(width: 2, height: 40, color: isDone ? const Color(0xFF2ECC71) : Colors.white12),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['en']!,
                                style: TextStyle(
                                  color: isCurrent ? const Color(0xFFF39C12) : (isDone ? Colors.white : Colors.grey),
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              if (isCurrent)
                                const Text('Active stage at workshop', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _showAdvanceStatusDialog,
                  icon: const Icon(Icons.forward, color: Colors.white),
                  label: const Text('Advance Production Stage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD35400),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // TAB 2: PAYMENTS
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Financial Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Idol Price:', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                          Text(LocalizationService.formatCurrency(total), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Collected (Advance + Balance):', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                          Text(LocalizationService.formatCurrency(paid), style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Divider(color: isDark ? Colors.white12 : Colors.black12, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Remaining Balance Due:', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          Text(LocalizationService.formatCurrency(balance), style: TextStyle(color: balance > 0 ? const Color(0xFFE74C3C) : Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.1),
                const SizedBox(height: 16),

                if (balance > 0)
                  ElevatedButton.icon(
                    onPressed: _showRecordPaymentDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Record Balance Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 20),

                const Text('Payment History & Receipts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                ...payments.map((p) => Card(
                  color: const Color(0xFF181824),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      p['is_advance'] == 1 ? Icons.star : Icons.check_circle,
                      color: const Color(0xFFF39C12),
                    ),
                    title: Text(
                      '${LocalizationService.formatCurrency(p['amount'])} via ${(p['payment_mode'] as String).toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${p['note'] ?? (p['is_advance'] == 1 ? 'Initial Advance' : 'Balance payment')} • ${p['payment_date']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )),
              ],
            ),
          ),

          // TAB 3: AUTHORIZED PHONES
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Phones allowed to log in and track this order.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),

                ...phones.map((ph) {
                  final isBlocked = ph['is_blocked'] == 1;
                  return Card(
                    color: const Color(0xFF181824),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(Icons.phone_android, color: isBlocked ? Colors.red : const Color(0xFF2ECC71)),
                      title: Text(
                        '${ph['phone_number']} (${ph['label']})',
                        style: TextStyle(color: isBlocked ? Colors.red.shade300 : Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isBlocked ? 'Blocked - Access Denied' : 'Active Access',
                        style: TextStyle(color: isBlocked ? Colors.red : Colors.grey, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: isBlocked ? Colors.green : Colors.orange),
                            onPressed: () async {
                              await ApiService.togglePhoneBlock(widget.bookingId, ph['id']);
                              _loadDetails();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              await ApiService.removeAuthorizedPhone(widget.bookingId, ph['id']);
                              _loadDetails();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _showAddPhoneDialog,
                  icon: const Icon(Icons.add, color: Color(0xFFF39C12)),
                  label: const Text('Authorize Another Phone', style: TextStyle(color: Color(0xFFF39C12))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF39C12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          // TAB 4: CHANGE REQUESTS & RATINGS
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Customer Design Adjustment Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                if (crs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Text('No adjustment requests submitted.', style: TextStyle(color: Colors.grey.shade500)),
                  )
                else
                  ...crs.map((cr) {
                    final status = cr['status'] as String;
                    return Card(
                      color: theme.colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text((cr['change_type'] as String).toUpperCase(), style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                                Text(status.toUpperCase(), style: TextStyle(color: status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(cr['description'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface)),
                            if (cr['murtikar_response'] != null) ...[
                              const SizedBox(height: 8),
                              Text('Your response: ${cr['murtikar_response']}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 12)),
                            ],
                            if (status == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () async {
                                      await ApiService.respondToChangeRequest(widget.bookingId, cr['id'], 'accepted', 'Adjustment accepted by workshop', 0);
                                      _loadDetails();
                                    },
                                    child: const Text('Accept', style: TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () async {
                                      await ApiService.respondToChangeRequest(widget.bookingId, cr['id'], 'rejected', 'Cannot be altered at this stage', 0);
                                      _loadDetails();
                                    },
                                    child: const Text('Reject', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ).animate().fade().slideY(begin: 0.1);
                  }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SupportChatScreen(bookingId: widget.bookingId, isCustomer: false)));
        },
        backgroundColor: const Color(0xFFF39C12),
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text('Customer Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
