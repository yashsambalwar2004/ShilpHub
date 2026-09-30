import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  Future<void> _loadRatings({bool showLoading = false}) async {
    if (showLoading || _data.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final r = await ApiService.getRatings();
      if (mounted) setState(() => _data = r);
    } catch (_) {} finally {
      if (mounted && (showLoading || _data.isEmpty)) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _scoreColor(double score) {
    if (score >= 8) return const Color(0xFF2ECC71);
    if (score >= 5) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avg = (_data['average_score'] as num?)?.toDouble() ?? 0.0;
    final total = (_data['total_reviews'] as num?) ?? 0;
    final reviews = (_data['reviews'] as List<dynamic>?) ?? [];
    final color = _scoreColor(avg > 0 ? avg : 10.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Ratings & Blessings',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadRatings,
              color: theme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          const Text('🪔', style: TextStyle(fontSize: 48))
                              .animate().scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(avg > 0 ? avg.toStringAsFixed(1) : '–',
                                  style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: color, height: 1)),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(' / 10', style: TextStyle(fontSize: 22, color: isDark ? Colors.grey : Colors.black54, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(10, (i) {
                              final filled = i < (avg > 0 ? avg.round() : 10);
                              return Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: filled ? const Color(0xFFF39C12) : (isDark ? Colors.grey.shade700 : Colors.black26),
                                size: 22,
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                            child: Text('$total verified ${total == 1 ? "review" : "reviews"}',
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 28),

                    if (reviews.isEmpty)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 16)],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reviews_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black12),
                              const SizedBox(height: 16),
                              Text('No reviews yet', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Ratings appear after customer idol delivery.', textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 14)),
                            ],
                          ),
                        ),
                      ).animate().fade()
                    else ...[
                      Row(children: [
                        Icon(Icons.format_quote_rounded, color: theme.primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Text('Customer Feedback', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 18)),
                      ]),
                      const SizedBox(height: 14),
                      ...reviews.asMap().entries.map((entry) {
                        final i = entry.key;
                        final r = entry.value;
                        final score = (r['score'] as num?)?.toDouble() ?? 0;
                        final c = _scoreColor(score);
                        final name = r['customer_name'] as String? ?? 'D';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: c.withOpacity(0.12),
                                  child: Text(name[0].toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 18)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('Order: ${r["booking_number"]} • ${LocalizationService.formatDate(r["created_at"])}',
                                          style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.star_rounded, color: c, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${score.toStringAsFixed(0)}/10', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 14)),
                                  ]),
                                ),
                              ]),
                              if (r['note'] != null && r['note'].toString().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.format_quote, size: 16, color: isDark ? Colors.grey : Colors.black26),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(r['note'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.4, fontStyle: FontStyle.italic)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ).animate(delay: Duration(milliseconds: i * 60)).fade().slideY(begin: 0.1, curve: Curves.easeOut);
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
