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
        bottomNavigationBar: _EvoriaBottomNav(
          currentIndex: widget.currentIndex,
          onTap: (i) => context.go(MainShell.routes[i]),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavSpec(this.icon, this.activeIcon, this.label);
}

class _EvoriaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _EvoriaBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavSpec(Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    _NavSpec(Icons.confirmation_number_outlined,
        Icons.confirmation_number_rounded, 'Tiket'),
    _NavSpec(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'AI'),
    _NavSpec(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x141B2A4A),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final spec = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: active ? AppGradients.brand : null,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(999)),
                          boxShadow: active
                              ? AppShadows.glow(AppColors.primary,
                                  opacity: 0.28)
                              : null,
                        ),
                        child: Icon(
                          active ? spec.activeIcon : spec.icon,
                          size: 22,
                          color: active ? Colors.white : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
