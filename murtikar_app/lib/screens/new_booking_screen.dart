import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class NewBookingScreen extends StatefulWidget {
  const NewBookingScreen({super.key});

  @override
  State<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends State<NewBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController(text: '5 feet');
  final _totalCtrl = TextEditingController(text: '25000');
  final _advanceCtrl = TextEditingController(text: '5000');
  final _noteCtrl = TextEditingController();
  final _pinCtrl = TextEditingController(text: '1234');

  String _festival = 'ganesh_utsav_2026';
  String _idolType = 'ganesha';
  String _material = 'clay';
  String _advanceMode = 'upi';
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 60));

  bool _isLoading = false;
  List<dynamic> _festivals = [];

  @override
  void initState() {
    super.initState();
    _loadFestivals();
  }

  Future<void> _loadFestivals() async {
    try {
      final f = await ApiService.getFestivals();
      if (mounted && f.isNotEmpty) {
        setState(() {
          _festivals = f;
          _festival = f.first['name'];
        });
      }
    } catch (_) {}
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final total = double.tryParse(_totalCtrl.text.trim()) ?? 0;
    final advance = double.tryParse(_advanceCtrl.text.trim()) ?? 0;

    if (advance > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advance cannot exceed total idol price!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.createBooking({
        'customer_name': _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'festival': _festival,
        'idol_type': _idolType,
        'size': _sizeCtrl.text.trim(),
        'material': _material,
        'total_amount': total,
        'advance_amount': advance,
        'advance_mode': _advanceMode,
        'expected_delivery_date': _deliveryDate.toIso8601String().substring(0, 10),
        'notes': _noteCtrl.text.trim(),
        'customer_auth_type': 'pin',
        'customer_credential': _pinCtrl.text.trim().isEmpty ? '1234' : _pinCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${res['message'] ?? 'Booking created successfully!'}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181824),
        title: const Text('New Idol Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Details Section
              _buildSectionTitle('1. Customer Information'),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Customer / Mandal Name *', Icons.person),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter customer name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('10-digit Mobile Number *', Icons.phone),
                validator: (v) {
                  if (v == null || v.trim().length != 10) return 'Enter valid 10-digit phone number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Idol Specifications
              _buildSectionTitle('2. Idol & Festival Specifications'),
              DropdownButtonFormField<String>(
                value: _festival,
                dropdownColor: const Color(0xFF1E1E2E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Festival *', Icons.festival),
                items: _festivals.isNotEmpty
                    ? _festivals.map((f) => DropdownMenuItem<String>(
                        value: f['name'] as String,
                        child: Text(f['display_name_en'] ?? f['name']),
                      )).toList()
                    : const [DropdownMenuItem(value: 'ganesh_utsav_2026', child: Text('Ganesh Utsav 2026'))],
                onChanged: (v) => setState(() => _festival = v!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _idolType,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Deity *', Icons.auto_awesome),
                      items: const [
                        DropdownMenuItem(value: 'ganesha', child: Text('Ganesha')),
                        DropdownMenuItem(value: 'durga', child: Text('Durga')),
                        DropdownMenuItem(value: 'lakshmi', child: Text('Lakshmi')),
                        DropdownMenuItem(value: 'saraswati', child: Text('Saraswati')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _idolType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _material,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Material *', Icons.nature),
                      items: const [
                        DropdownMenuItem(value: 'clay', child: Text('Clay / Shadu')),
                        DropdownMenuItem(value: 'plaster', child: Text('Plaster (POP)')),
                        DropdownMenuItem(value: 'fiber', child: Text('Fiber')),
                        DropdownMenuItem(value: 'marble', child: Text('Marble')),
                      ],
                      onChanged: (v) => setState(() => _material = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _sizeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Height & Pose (e.g. 5 ft Lalbaugcha Raja) *', Icons.height),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter size/pose' : null,
              ),
              const SizedBox(height: 12),

              // Delivery Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deliveryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                  );
                  if (picked != null) setState(() => _deliveryDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFFF39C12), size: 20),
                          const SizedBox(width: 10),
                          const Text('Expected Delivery Date:', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Text(
                        LocalizationService.formatDate(_deliveryDate.toIso8601String()),
                        style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Pricing & Advance
              _buildSectionTitle('3. Pricing & Token Advance'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Total Price (₹) *', Icons.currency_rupee),
                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid price' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _advanceCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Advance (₹)', Icons.payments),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _advanceMode,
                dropdownColor: const Color(0xFF1E1E2E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Advance Payment Mode', Icons.account_balance_wallet),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash (रोख)')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI (GPay / PhonePe / Paytm)')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer (NEFT/IMPS)')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _advanceMode = v!),
              ),
              const SizedBox(height: 20),

              // Customer Tracking Credential
              _buildSectionTitle('4. Customer Order Tracking Access'),
              TextFormField(
                controller: _pinCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: _inputDecoration('Initial 4-6 digit Customer Tracking PIN', Icons.lock_clock),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: _inputDecoration('Special Crafting Notes (e.g. Mukut, Shringar, Colors)', Icons.note),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD35400),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirm & Save to Register',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFF39C12), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFFD35400), size: 20),
      filled: true,
      fillColor: const Color(0xFF1E1E2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
