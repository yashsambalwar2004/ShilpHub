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

  final isChat = data['type'] == 'chat';
  final isChangeReq = data['type'] == 'change_request';

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isChangeReq ? Colors.orange.shade800 : Colors.indigo.shade800,
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
              isChangeReq ? Icons.design_services_rounded : Icons.mark_chat_unread_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title ?? 'New Notification',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 2),
                if (n.body != null)
                  Text(
                    n.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
      action: isChat
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
