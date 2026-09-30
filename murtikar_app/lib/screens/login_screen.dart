import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'dashboard_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  final loc = LocalizationService.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            onPressed: () => Provider.of<ThemeService>(context, listen: false).toggleTheme(),
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
                      style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ).animate().fade(duration: 500.ms).slideY(begin: -0.2),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    loc.t('app_title'),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.secondary, letterSpacing: 0.5),
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                Center(
                  child: Text(
                    loc.t('sub_title'),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.black54),
                  ),
                ).animate().fade(delay: 400.ms),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header inside card
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Artisan Login', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 20)),
                              Text('Sign in to manage your orders', style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontSize: 13),
                          ),
                        ),

                      Text(loc.t('phone_label'), style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.phone_rounded, color: theme.primaryColor, size: 20),
                          hintText: '10-digit mobile number',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.black38),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF222232) : Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(loc.t('password_label'), style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_rounded, color: theme.primaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: isDark ? Colors.grey : Colors.black38, size: 20),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          hintText: 'Enter password',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.black38),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF222232) : Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(loc.t('login'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),

                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _showRegisterDialog,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(loc.t('register'), style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
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
