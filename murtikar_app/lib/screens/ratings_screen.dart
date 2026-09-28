import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);
    try {
      final r = await ApiService.getRatings();
      if (mounted) setState(() => _data = r);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = (_data['average_score'] as num?)?.toDouble() ?? 0.0;
    final total = (_data['total_reviews'] as num?) ?? 0;
    final reviews = (_data['reviews'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181824),
        title: const Text('Customer Ratings & Blessings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Average Rating Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181824),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('🪔', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              avg > 0 ? avg.toStringAsFixed(1) : '10.0',
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFFF39C12)),
                            ),
                            const Text(' / 10', style: TextStyle(fontSize: 20, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Average score from $total verified devotees & customers',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Customer Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),

                  if (reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text('No reviews submitted yet. Ratings appear after customer idol delivery.', style: TextStyle(color: Colors.grey.shade500)),
                    )
                  else
                    ...reviews.map((r) => Card(
                      color: const Color(0xFF181824),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r['customer_name'] ?? 'Devotee',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text('${r['score']}/10', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r['note'] != null && r['note'].toString().isNotEmpty ? r['note'] : 'Blessed with a magnificent idol.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Order: ${r['booking_number']} • ${LocalizationService.formatDate(r['created_at'])}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}
