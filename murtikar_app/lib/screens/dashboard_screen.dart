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
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFestivals();
    _fetchBookings();
  }

  bool _hasShownGreetingPopup = false;

  Future<void> _loadProfile() async {
    try {
      final p = await ApiService.getMurtikarProfile();
      if (mounted) {
        setState(() => _profile = p);
        if (!_hasShownGreetingPopup) {
          _hasShownGreetingPopup = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showGreetingPopup(context);
          });
        }
      }
    } catch (_) {}
  }

  String _getGreetingTitle(String lang, int hour, String rawName) {
    String formattedName = rawName.trim();
    if (formattedName.isNotEmpty) {
      final parts = formattedName.split(' ');
      formattedName = '${parts[0]} Ji';
    } else {
      formattedName = 'Master Artisan';
    }

    if (lang == 'hi') {
      if (hour < 12) return 'सुप्रभात $formattedName! 🌅';
      if (hour < 17) return 'शुभ दोपहर $formattedName! ☀️';
      return 'शुभ संध्या $formattedName! 🌆';
    } else if (lang == 'mr') {
      if (hour < 12) return 'शुभ सकाळ $formattedName! 🌅';
      if (hour < 17) return 'शुभ दुपार $formattedName! ☀️';
      return 'शुभ संध्या $formattedName! 🌆';
    } else {
      if (hour < 12) return 'Good Morning, $formattedName! 🌅';
      if (hour < 17) return 'Good Afternoon, $formattedName! ☀️';
      return 'Good Evening, $formattedName! 🌆';
    }
  }

  void _showGreetingPopup(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = loc.currentLocale;
    final hour = DateTime.now().hour;
    final name = _profile['name'] as String? ?? '';
    final shopName = _profile['shop_name'] as String? ?? 'Shree Ganesh Kalakendra';

    final title = _getGreetingTitle(lang, hour, name);

    String blessingText = '॥ श्री गणेशाय नमः ॥';
    String quoteText = 'आपकी पावन कला एवं साधना से भगवान गणेश का रूप सजीव होता है।';
    String buttonText = '🙏 जय श्री गणेश (प्रारंभ करें)';

    if (lang == 'mr') {
      blessingText = '॥ श्री गणेशाय नमः ॥';
      quoteText = 'तुमच्या पवित्र हातांनी घडणारी सुरेख रूपे आणि अपार भक्ती.';
      buttonText = '🙏 जय श्री गणेश (सुरू करा)';
    } else if (lang == 'en') {
      blessingText = '॥ Shree Ganeshaya Namah ॥';
      quoteText = 'Crafting divine idols with sacred hands & pure devotion.';
      buttonText = '🙏 Jai Shree Ganesh • Start Crafting';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C1E14), const Color(0xFF191928)]
                    : [const Color(0xFFFFF3E0), const Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFFF39C12).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD35400).withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.5), width: 1.5),
                  ),
                  child: const Text('🪔', style: TextStyle(fontSize: 42))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1800.ms, curve: Curves.easeInOut),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD35400).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD35400).withOpacity(0.35)),
                  ),
                  child: Text(
                    blessingText,
                    style: const TextStyle(
                      color: Color(0xFFE67E22),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  quoteText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (shopName.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFF39C12)),
                        const SizedBox(width: 8),
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF39C12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD35400),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    shadowColor: const Color(0xFFD35400).withOpacity(0.5),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    buttonText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Touch screen to dismiss',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.black45),
                ),
              ],
            ),
          ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
        ),
      ),
    );
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

  Widget _buildGreetingBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = loc.currentLocale;
    final hour = DateTime.now().hour;
    final name = _profile['name'] as String? ?? '';
    final shopName = _profile['shop_name'] as String? ?? '';

    final greetingTitle = _getGreetingTitle(lang, hour, name);

    String blessingText = '॥ श्री गणेशाय नमः ॥';
    String quoteText = 'आपकी पावन कला एवं साधना से भगवान गणेश का रूप सजीव होता है।';

    if (lang == 'mr') {
      blessingText = '॥ श्री गणेशाय नमः ॥';
      quoteText = 'तुमच्या पवित्र हातांनी घडणारी सुरेख रूपे आणि अपार भक्ती.';
    } else if (lang == 'en') {
      blessingText = '॥ Shree Ganeshaya Namah ॥';
      quoteText = 'Crafting divine idols with sacred hands & pure devotion.';
    }

    return GestureDetector(
      onTap: () => _showGreetingPopup(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2C1E14), const Color(0xFF1E1E2E)]
                : [const Color(0xFFFFF3E0), const Color(0xFFFBE9E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF39C12).withOpacity(isDark ? 0.35 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD35400).withOpacity(isDark ? 0.25 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.4)),
                  ),
                  child: const Text('🪔', style: TextStyle(fontSize: 26))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 2.seconds, curve: Curves.easeInOut),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD35400).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD35400).withOpacity(0.3)),
                        ),
                        child: Text(
                          blessingText,
                          style: const TextStyle(
                            color: Color(0xFFE67E22),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greetingTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quoteText,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (shopName.isNotEmpty || name.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFFF39C12)),
                  const SizedBox(width: 6),
                  Text(
                    shopName.isNotEmpty ? shopName : 'Shree Ganesh Kalakendra',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF39C12),
                    ),
                  ),
                  if (name.isNotEmpty) ...[
                    Text(
                      ' • $name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ],
        ),
      ).animate().fade(duration: 400.ms).slideY(begin: -0.05, curve: Curves.easeOut),
    );
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
                    _buildGreetingBanner(context),

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
