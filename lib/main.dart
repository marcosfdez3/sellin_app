import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/feed_screen.dart';
import 'screens/login_screen.dart';
import 'screens/following_screen.dart';
import 'screens/top_screen.dart';
import 'screens/signal_detail_screen.dart';
import 'services/api_client.dart';
import 'services/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Recupera la sesión guardada antes de decidir la primera pantalla
  final auth = AuthController(ApiClient());
  await auth.load();

  runApp(ProviderScope(
    overrides: [authProvider.overrideWith((ref) => auth)],
    child: InsiderTrackApp(router: _buildRouter(auth)),
  ));
}

GoRouter _buildRouter(AuthController auth) => GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    final onLogin = state.matchedLocation == '/login';
    if (!auth.isLoggedIn) return onLogin ? null : '/login';
    if (onLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TopScreen(),
        ),
        GoRoute(
          path: '/signals',
          builder: (context, state) => const FeedScreen(),
        ),
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/signal/:id',
      builder: (context, state) {
        final signal = state.extra as Signal;
        return SignalDetailScreen(signal: signal);
      },
    ),
  ],
);

class InsiderTrackApp extends StatelessWidget {
  final GoRouter router;
  const InsiderTrackApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InsiderTrack',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1A2E),
        brightness: Brightness.dark,
        primary: const Color(0xFF00D4AA),
        surface: const Color(0xFF16213E),
      ),
      scaffoldBackgroundColor: Colors.black,
      cardTheme: CardThemeData(
        color: const Color(0xFF16213E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        // Sin el tinte que Material 3 añade al desplazar contenido por debajo
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Rutas de cada pestaña, en el mismo orden que la barra de navegación
  static const _tabs = ['/', '/signals', '/following'];

  /// La barra de abajo se esconde al bajar y vuelve a salir al subir.
  bool _barVisible = true;

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final visible = switch (notification.direction) {
      ScrollDirection.reverse => false, // bajando
      ScrollDirection.forward => true,  // subiendo
      ScrollDirection.idle => _barVisible,
    };
    if (visible != _barVisible) setState(() => _barVisible = visible);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _tabs.indexOf(location).clamp(0, _tabs.length - 1);

    return Scaffold(
      // La barra flota sobre el contenido, que se ve alrededor de ella.
      // Las pantallas reciben su alto en MediaQuery.padding.bottom.
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: _barVisible
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    // El margen del sistema ya lo pone el SafeArea de fuera;
                    // sin esto la barra lo añadiría también dentro de la píldora
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                                size: 26,
                                color: states.contains(WidgetState.selected)
                                    ? const Color(0xFF00D4AA)
                                    : Colors.white38,
                              )),
                        ),
                        child: NavigationBar(
                          selectedIndex: selectedIndex,
                          height: 56,
                          backgroundColor: const Color(0xFF1E1E1E),
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          indicatorColor: Colors.transparent,
                          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                          onDestinationSelected: (index) => context.go(_tabs[index]),
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.emoji_events_rounded),
                              label: 'Top',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.trending_up_rounded),
                              label: 'Señales',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.star_rounded),
                              label: 'Siguiendo',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
