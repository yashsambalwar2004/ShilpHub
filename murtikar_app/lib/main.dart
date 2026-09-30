import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/localization_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/support_chat_screen.dart'; // <-- adjust if your chat screen file has a different name

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Kept for compatibility: registration now also happens automatically
/// inside ApiService.setToken() after every login.
Future<void> registerPushToken() => ApiService.syncPushToken();

/// Opens the right support chat when a chat notification is tapped.
void _openChatFromMessage(RemoteMessage message) {
  final data = message.data;
  if (data['type'] != 'chat') return;
  final bookingId = data['booking_id'];
  if (bookingId == null || bookingId.isEmpty) return;
  if (!ApiService.isLoggedIn) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(
    builder: (_) => SupportChatScreen(
      bookingId: bookingId,
      isCustomer: data['recipient_type'] == 'customer',
    ),
  ));
}

/// While the app is open Android does not show a system notification,
/// so show an in-app banner instead.
void _showForegroundBanner(RemoteMessage message) {
  final data = message.data;
  if (data['type'] == 'chat' && data['booking_id'] == ApiService.activeChatBookingId) return;

  final n = message.notification;
  final messenger = messengerKey.currentState;
  if (n == null || messenger == null) return;

  final type = data['type'] as String?;
  
  List<Color> gradientColors = [const Color(0xFF4F46E5), const Color(0xFF6366F1)]; // default chat
  IconData icon = Icons.mark_chat_unread_rounded;
  String badgeTag = 'NEW MESSAGE';
  
  if (type == 'change_request') {
    gradientColors = [const Color(0xFFE65100), const Color(0xFFF57C00)];
    icon = Icons.design_services_rounded;
    badgeTag = 'DESIGN REQUEST';
  } else if (type == 'rating') {
    gradientColors = [const Color(0xFFD97706), const Color(0xFFF59E0B)];
    icon = Icons.star_rounded;
    badgeTag = 'NEW RATING';
  } else if (type == 'booking' || type == 'stage') {
    gradientColors = [const Color(0xFF059669), const Color(0xFF10B981)];
    icon = Icons.auto_awesome_rounded;
    badgeTag = 'BOOKING UPDATE';
  } else if (type == 'test') {
    gradientColors = [const Color(0xFF0F766E), const Color(0xFF14B8A6)];
    icon = Icons.bug_report_rounded;
    badgeTag = 'SYSTEM ALERT';
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 12,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 6),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeTag,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.title ?? 'New Notification',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, height: 1.2),
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 13, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            if (type == 'chat' || type == 'change_request') ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  _openChatFromMessage(message);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    type == 'change_request' ? 'REVIEW' : 'OPEN',
                    style: TextStyle(
                      color: gradientColors[0],
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await LocalizationService.instance.init();
  await ThemeService.instance.init();

  try {
    await Firebase.initializeApp();

    // Needed on Android 13+ and iOS, otherwise notifications won't show
    await FirebaseMessaging.instance.requestPermission();

    // Firebase can rotate the token, so keep the backend up to date
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (!ApiService.isLoggedIn) return;
      try {
        await ApiService.registerDeviceToken(newToken);
      } catch (e) {
        debugPrint('Token refresh registration failed: $e');
      }
    });

    // Notification arrives while the app is open / notification tapped
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    FirebaseMessaging.onMessageOpenedApp.listen(_openChatFromMessage);

    // If the user is already logged in, register right away
    await ApiService.syncPushToken();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ThemeService.instance),
      ],
      child: const ShilpHubApp(),
    ),
  );
}

class ShilpHubApp extends StatefulWidget {
  const ShilpHubApp({super.key});

  @override
  State<ShilpHubApp> createState() => _ShilpHubAppState();
}

class _ShilpHubAppState extends State<ShilpHubApp> {
  final loc = LocalizationService.instance;

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loc.addListener(_onLocaleChanged);

    // App was fully closed and opened by tapping a notification
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _openChatFromMessage(initial);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    loc.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'ShilpHub',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: themeService.currentTheme,
      home: ApiService.isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
