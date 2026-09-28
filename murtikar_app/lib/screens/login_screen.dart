import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'dashboard_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'customer_tracking_screen.dart';
import '../services/theme_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isCustomer = false;

  final _phoneController = TextEditingController();
  final _passController = TextEditingController();

  final _bookingNoController = TextEditingController();
  final _custPhoneController = TextEditingController();
  final _credentialController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final loc = LocalizationService.instance;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.login(_phoneController.text.trim(), _passController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCustomerLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.customerLogin(
        _bookingNoController.text.trim(),
        _custPhoneController.text.trim(),
        _credentialController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerTrackingScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final shopCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Pune');
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final expCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Artisan Registration', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shopCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(labelText: 'Workshop / Kala Kendra Name', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(labelText: 'Master Artisan Name', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
              TextField(
                controller: cityCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(labelText: 'City', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
              TextField(
                controller: phoneCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: '10-digit Mobile', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
              TextField(
                controller: passCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
              TextField(
                controller: expCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Experience (Years)', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD35400)),
            onPressed: () async {
              try {
                await ApiService.register({
                  'name': nameCtrl.text.trim(),
                  'shop_name': shopCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'password': passCtrl.text.trim(),
                  'experience_years': int.tryParse(expCtrl.text.trim()) ?? 5,
                  'idol_types': ['ganesha', 'durga']
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registration submitted! Platform Admin will verify your shop shortly.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Submit Application', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: theme.colorScheme.secondary),
            onPressed: () {
              Provider.of<ThemeService>(context, listen: false).toggleTheme();
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.language, color: theme.colorScheme.secondary),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Auspicious Blessing Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.2),
                      border: Border.all(color: theme.primaryColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '॥ श्री गणेशाय नमः ॥',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ).animate().fade(duration: 500.ms).slideY(begin: -0.2),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    loc.t('app_title'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                Center(
                  child: Text(
                    loc.t('sub_title'),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.black54),
                  ),
                ).animate().fade(delay: 400.ms),
                const SizedBox(height: 32),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            border: Border.all(color: Colors.red.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFF7675), fontSize: 13),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => _isCustomer = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCustomer ? (isDark ? const Color(0xFF222232) : Colors.grey.shade300) : theme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Artisan', style: TextStyle(color: !_isCustomer || isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => _isCustomer = true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCustomer ? theme.primaryColor : (isDark ? const Color(0xFF222232) : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Customer', style: TextStyle(color: _isCustomer || isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_isCustomer) ...[
                        Text(
                          'Booking / Bill Number',
                          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bookingNoController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.receipt, color: Color(0xFFD35400), size: 20),
                            hintText: 'Enter Booking Number',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: const Color(0xFF222232),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Registered Mobile',
                          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _custPhoneController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFFD35400), size: 20),
                            hintText: '10-digit mobile number',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: const Color(0xFF222232),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Password / PIN',
                          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _credentialController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFFD35400), size: 20),
                            hintText: 'Enter password or PIN',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: const Color(0xFF222232),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Text(
                          loc.t('phone_label'),
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFFD35400), size: 20),
                          hintText: '10-digit mobile number',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: const Color(0xFF222232),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        loc.t('password_label'),
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFD35400), size: 20),
                          hintText: 'Enter password',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: const Color(0xFF222232),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      ],
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isLoading ? null : (_isCustomer ? _handleCustomerLogin : _handleLogin),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                loc.t('login'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),

                      const SizedBox(height: 16),
                      if (!_isCustomer)
                        OutlinedButton(
                          onPressed: _showRegisterDialog,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black12),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            loc.t('register'),
                            style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ).animate().fade(delay: 600.ms).scaleXY(begin: 0.95),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
