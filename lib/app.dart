import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/checkout/checkout_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/orders/e_ticket_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isInitial = authState.status == AuthStatus.initial;
      final loc = state.matchedLocation;

      if (isInitial) return '/';

      if (!isAuth && loc != '/login' && loc != '/register') return '/login';
      if (isAuth && (loc == '/' || loc == '/login' || loc == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(
          currentIndex: MainShell.indexForLocation(state.matchedLocation),
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          GoRoute(path: '/chatbot', builder: (_, _) => const ChatbotScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (_, state) =>
            EventDetailScreen(eventId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/checkout',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          final expiresAtStr = extra['payment_expires_at'] as String?;
          return CheckoutScreen(
            snapToken: extra['snap_token'] as String,
            orderNumber: extra['order_number'] as String,
            orderId: extra['order_id'] as int,
            paymentExpiresAt: expiresAtStr != null
                ? DateTime.tryParse(expiresAtStr)
                : null,
            paymentTimeoutMinutes:
                extra['payment_timeout_minutes'] as int? ?? 30,
          );
        },
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/eticket/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ETicketScreen(
            ticketCode: extra['ticket_code'] as String,
            eventTitle: extra['event_title'] as String? ?? '',
            ticketName: extra['ticket_name'] as String? ?? '',
            status: extra['status'] as String? ?? 'issued',
          );
        },
      ),
    ],
  );
});

class EvoriaApp extends ConsumerWidget {
  const EvoriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Evoria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;
  const MainShell({super.key, required this.currentIndex, required this.child});

  static const routes = ['/home', '/orders', '/chatbot', '/profile'];

  /// Tab aktif diturunkan dari lokasi router (bukan state lokal) supaya
  /// highlight selalu sinkron, termasuk saat pindah via context.go dari layar lain.
  static int indexForLocation(String location) {
    final i = routes.indexOf(location);
    return i < 0 ? 0 : i;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Riwayat tab yang dikunjungi → tombol back HP mundur satu langkah.
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    _history.add(widget.currentIndex);
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Catat perpindahan tab (lewat tap maupun context.go dari layar lain).
    if (_history.isEmpty || widget.currentIndex != _history.last) {
      _history.add(widget.currentIndex);
    }
  }

  void _handleBack() {
    if (_history.length > 1) {
      // Mundur ke tab sebelumnya.
      _history.removeLast();
      context.go(MainShell.routes[_history.last]);
    } else {
      // Sudah di tab awal & tanpa riwayat → keluar aplikasi.
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: widget.currentIndex,
          onTap: (i) => context.go(MainShell.routes[i]),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
              activeIcon: Icon(Icons.confirmation_number),
              label: 'Tiket',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
