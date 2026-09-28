import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class PaymentSummaryScreen extends StatefulWidget {
  const PaymentSummaryScreen({super.key});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  String? _selectedFestival;
  List<dynamic> _festivals = [];

  @override
  void initState() {
    super.initState();
    _loadFestivals();
    _fetchSummary();
  }

  Future<void> _loadFestivals() async {
    try {
      final f = await ApiService.getFestivals();
      if (mounted) setState(() => _festivals = f);
    } catch (_) {}
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPaymentSummaries(festival: _selectedFestival);
      if (mounted) setState(() => _summary = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = (_summary?['grand_total'] as num?) ?? 0;
    final breakdown = (_summary?['mode_breakdown'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181824),
        title: const Text('Payment Mode Summaries', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Festival Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Festivals'),
                          selected: _selectedFestival == null,
                          selectedColor: const Color(0xFFD35400),
                          backgroundColor: const Color(0xFF1E1E2E),
                          labelStyle: TextStyle(color: _selectedFestival == null ? Colors.white : Colors.grey),
                          onSelected: (_) {
                            setState(() => _selectedFestival = null);
                            _fetchSummary();
                          },
                        ),
                        const SizedBox(width: 8),
                        ..._festivals.map((f) {
                          final name = f['name'] as String;
                          final isSel = _selectedFestival == name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f['display_name_en'] ?? name),
                              selected: isSel,
                              selectedColor: const Color(0xFFD35400),
                              backgroundColor: const Color(0xFF1E1E2E),
                              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey),
                              onSelected: (_) {
                                setState(() => _selectedFestival = name);
                                _fetchSummary();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grand Total Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD35400), Color(0xFFF39C12)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD35400).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL CASH & DIGITAL COLLECTIONS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(
                          LocalizationService.formatCurrency(grandTotal),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text('Unified payments (Advances + Balances) with zero double-counting', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Mode-wise Breakdown', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _buildModeCard('UPI / Digital Payments', breakdown['upi'], Icons.qr_code_2, const Color(0xFF2ECC71), grandTotal),
                  _buildModeCard('Cash Collections', breakdown['cash'], Icons.payments, const Color(0xFF3498DB), grandTotal),
                  _buildModeCard('Bank Transfers (NEFT/IMPS)', breakdown['bank_transfer'], Icons.account_balance, const Color(0xFF9B59B6), grandTotal),
                  _buildModeCard('Other Payment Modes', breakdown['other'], Icons.credit_card, Colors.orange, grandTotal),
                ],
              ),
            ),
    );
  }

  Widget _buildModeCard(String title, dynamic data, IconData icon, Color color, num grandTotal) {
    final count = data != null ? data['transactions'] ?? 0 : 0;
    final total = data != null ? (data['total'] as num?) ?? 0 : 0;
    final pct = grandTotal > 0 ? (total / grandTotal) : 0.0;

    return Card(
      color: const Color(0xFF181824),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('$count transactions recorded', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  LocalizationService.formatCurrency(total),
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                color: color,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
