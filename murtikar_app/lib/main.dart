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
  // If that chat is already on screen it refreshes itself every 5 seconds.
  if (data['type'] == 'chat' && data['booking_id'] == ApiService.activeChatBookingId) return;

  final n = message.notification;
  final messenger = messengerKey.currentState;
  if (n == null || messenger == null) return;

  final type = data['type'] as String?;
  
  // Customization based on notification type
  Color bgColor = Colors.indigo.shade800; // default for chat
  IconData icon = Icons.mark_chat_unread_rounded;
  
  if (type == 'change_request') {
    bgColor = Colors.orange.shade800;
    icon = Icons.design_services_rounded;
  } else if (type == 'rating') {
    bgColor = Colors.amber.shade700;
    icon = Icons.star_rounded;
  } else if (type == 'test') {
    bgColor = Colors.teal.shade700;
    icon = Icons.bug_report_rounded;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: bgColor,
      duration: const Duration(seconds: 6),
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title ?? 'New Notification',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 3),
                if (n.body != null)
                  Text(
                    n.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 14, height: 1.3),
                  ),
              ],
            ),
          ),
        ],
      ),
      action: (type == 'chat' || type == 'change_request')
          ? SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.2),
              onPressed: () => _openChatFromMessage(message),
            )
          : null,
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
