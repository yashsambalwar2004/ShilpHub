import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'new_booking_screen.dart';
import 'booking_detail_screen.dart';
import 'payment_summary_screen.dart';
import 'workshop_blocklist_screen.dart';
import 'ratings_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../services/theme_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final loc = LocalizationService.instance;
  bool _isLoading = true;
  Map<String, dynamic> _bookingData = {};
  String? _selectedFestival;
  String? _selectedStage;
  final _searchController = TextEditingController();

  List<dynamic> _festivals = [];

  @override
  void initState() {
    super.initState();
    _loadFestivals();
    _fetchBookings();
  }

  Future<void> _loadFestivals() async {
    try {
      final f = await ApiService.getFestivals();
      if (mounted) setState(() => _festivals = f);
    } catch (_) {}
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getBookings(
        festival: _selectedFestival,
        stage: _selectedStage,
        search: _searchController.text.trim(),
      );
      if (mounted) setState(() => _bookingData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'booking_confirmed': return const Color(0xFF3498DB);
      case 'design_approved': return const Color(0xFF9B59B6);
      case 'base_structure_ready': return const Color(0xFFE67E22);
      case 'painting_in_progress': return const Color(0xFFF39C12);
      case 'ornamentation': return const Color(0xFFE91E63);
      case 'quality_check': return const Color(0xFF1ABC9C);
      case 'ready_for_pickup': return const Color(0xFF27AE60);
      case 'delivered': return const Color(0xFF2ECC71);
      default: return Colors.grey;
    }
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Old Password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          if (oldController.text.trim().isEmpty || newController.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          try {
                            await ApiService.changePassword(oldController.text.trim(), newController.text.trim());
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green));
                          } catch (e) {
                            setStateDialog(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Submit'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings = (_bookingData['bookings'] as List<dynamic>?) ?? [];
    final totalRev = _bookingData['total_revenue'] ?? 0;
    final totalReceived = _bookingData['total_received'] ?? 0;
    final totalPending = _bookingData['total_pending_balance'] ?? 0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            const Text('🪔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                loc.t('dashboard'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: theme.colorScheme.secondary),
            onPressed: () {
              Provider.of<ThemeService>(context, listen: false).toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.secondary),
            onPressed: _fetchBookings,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.language, color: theme.colorScheme.onSurface),
            onSelected: (code) {
              loc.setLocale(code);
              setState(() {});
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'en', child: Text('English (EN)')),
              const PopupMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
              const PopupMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
            ],
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFD35400), Color(0xFFF39C12)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('🪔', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(loc.t('app_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(loc.t('sub_title'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Color(0xFFF39C12)),
              title: Text(loc.t('payments'), style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentSummaryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(loc.t('ratings'), style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: Text(loc.t('workshop_blocklist'), style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkshopBlocklistScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.blueAccent),
              title: Text('Change Password', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            Divider(color: isDark ? Colors.white24 : Colors.black12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.grey),
              title: Text(loc.t('logout'), style: const TextStyle(color: Colors.grey)),
              onTap: () async {
                await ApiService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary))
          : RefreshIndicator(
              onRefresh: _fetchBookings,
              color: theme.colorScheme.secondary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Financial Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            loc.t('total_revenue'),
                            LocalizationService.formatCurrency(totalRev),
                            isDark ? Colors.white : Colors.black,
                            isDark ? const Color(0xFF1E1E2E) : Colors.blue.shade50,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            loc.t('total_received'),
                            LocalizationService.formatCurrency(totalReceived),
                            const Color(0xFF2ECC71),
                            isDark ? const Color(0xFF162E20) : Colors.green.shade50,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            loc.t('pending_balance'),
                            LocalizationService.formatCurrency(totalPending),
                            const Color(0xFFE74C3C),
                            isDark ? const Color(0xFF2E1616) : Colors.red.shade50,
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      onSubmitted: (_) => _fetchBookings(),
                      decoration: InputDecoration(
                        hintText: loc.t('search_placeholder'),
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.secondary),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.arrow_forward, color: theme.colorScheme.secondary),
                          onPressed: _fetchBookings,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),

                    // Festival Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(loc.t('all_festivals')),
                            selected: _selectedFestival == null,
                            selectedColor: theme.primaryColor,
                            labelStyle: TextStyle(color: _selectedFestival == null ? Colors.white : (isDark ? Colors.grey : Colors.black87)),
                            backgroundColor: theme.colorScheme.surface,
                            onSelected: (_) {
                              setState(() => _selectedFestival = null);
                              _fetchBookings();
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._festivals.map((f) {
                            final name = f['name'] as String;
                            final disp = f['display_name_${loc.currentLocale}'] ?? f['display_name_en'] ?? name;
                            final isSel = _selectedFestival == name;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(disp),
                                selected: isSel,
                                selectedColor: theme.primaryColor,
                                labelStyle: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.grey : Colors.black87)),
                                backgroundColor: theme.colorScheme.surface,
                                onSelected: (_) {
                                  setState(() => _selectedFestival = name);
                                  _fetchBookings();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms).slideX(begin: 0.1),
                    const SizedBox(height: 16),

                    // Order Cards Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${loc.t('orders')} (${bookings.length})',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (bookings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No bookings found.', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text('Tap "+ New Booking" below to register a customer.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bookings.length,
                        itemBuilder: (ctx, index) {
                          final b = bookings[index];
                          final stageKey = b['current_status'] as String? ?? 'booking_confirmed';
                          final stageColor = _getStageColor(stageKey);
                          final stageDisp = loc.t('stage_$stageKey');
                          final total = (b['total_amount'] as num?) ?? 0;
                          final paid = (b['total_paid'] as num?) ?? 0;
                          final balance = (b['balance_due'] as num?) ?? 0;

                          return Card(
                            color: const Color(0xFF181824),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailScreen(bookingId: b['id']),
                                  ),
                                );
                                _fetchBookings();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Booking Number & Stage Tag
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF39C12).withOpacity(0.15),
                                            border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            b['booking_number'] ?? '',
                                            style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: stageColor.withOpacity(0.2),
                                            border: Border.all(color: stageColor.withOpacity(0.5)),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            stageDisp,
                                            style: TextStyle(color: stageColor, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Idol Description
                                    Text(
                                      '${b['size']} • ${(b['idol_type'] as String).toUpperCase()}',
                                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),

                                    // Customer Name & Delivery
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('👤 ${b['customer_name']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                        Text('📅 ${LocalizationService.formatDate(b['expected_delivery_date'])}', style: const TextStyle(color: Color(0xFFF39C12), fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Payment Progress Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: total > 0 ? (paid / total).clamp(0.0, 1.0) : 0,
                                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                        color: const Color(0xFF2ECC71),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Payment Amounts
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Paid: ${LocalizationService.formatCurrency(paid)}', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text('Balance: ${LocalizationService.formatCurrency(balance)}', style: TextStyle(color: balance > 0 ? const Color(0xFFE74C3C) : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text('Total: ${LocalizationService.formatCurrency(total)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fade(delay: (300 + index * 50).ms).slideY(begin: 0.2);
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD35400),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(loc.t('new_booking'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewBookingScreen()),
          );
          _fetchBookings();
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
