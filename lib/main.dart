import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/company_screen.dart';
import 'screens/login_screen.dart';
import 'screens/following_screen.dart';
import 'screens/search_screen.dart';
import 'screens/top_screen.dart';
import 'screens/signal_detail_screen.dart';
import 'services/api_client.dart';
import 'services/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de meses en español para las fechas (DateFormat con 'es_ES')
  await initializeDateFormatting('es_ES');

  // Recupera la sesión guardada antes de decidir la primera pantalla
  final auth = AuthController(ApiClient());
  await auth.load();

  // Carga el logo ya, para que la splash (LaunchOverlay) lo pinte en el primer frame
  const logo = SvgAssetLoader(kWordmarkAsset);
  await svg.cache.putIfAbsent(logo.cacheKey(null), () => logo.loadBytes(null));

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
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/company/:cik',
      builder: (context, state) => CompanyScreen(
        cik: state.pathParameters['cik']!,
        preview: state.extra as CompanyRef?,
      ),
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
      builder: (context, child) => LaunchOverlay(child: child!),
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

const kWordmarkAsset = 'assets/images/sellin_wordmark.svg';

/// Splash de la app: el logo grande sobre negro al arrancar, que se funde
/// con la primera pantalla. La splash del sistema es solo negra (Android 12+
/// escala y emborrona su icono), así que el logo se dibuja aquí, desde el SVG.
class LaunchOverlay extends StatefulWidget {
  final Widget child;
  const LaunchOverlay({super.key, required this.child});

  @override
  State<LaunchOverlay> createState() => _LaunchOverlayState();
}

class _LaunchOverlayState extends State<LaunchOverlay> {
  bool _visible = true; // empieza el fundido
  bool _done = false;   // overlay retirado

  @override
  void initState() {
    super.initState();
    // El tiempo cuenta desde que el logo ya está en pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      children: [
        widget.child,
        // Mientras se ve el logo no se puede tocar la app de debajo
        AbsorbPointer(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            onEnd: () => setState(() => _done = true),
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.7,
                  child: SvgPicture.asset(kWordmarkAsset),
                ),
              ),
            ),
          ),
        ),
      ],
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
  static const _tabs = ['/', '/search', '/following'];

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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    heightFactor: 1,
                    child: _NavPill(
                      selectedIndex: selectedIndex,
                      onSelected: (index) => context.go(_tabs[index]),
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// Barra de navegación compacta: una píldora gris oscuro, centrada y solo con iconos.
class _NavPill extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _NavPill({required this.selectedIndex, required this.onSelected});

  static const _items = [
    (icon: Icons.emoji_events_rounded, label: 'Top'),
    (icon: Icons.search_rounded, label: 'Buscar'),
    (icon: Icons.star_rounded, label: 'Siguiendo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in _items.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            IconButton(
              tooltip: item.label,
              iconSize: 24,
              onPressed: () => onSelected(i),
              icon: Icon(
                item.icon,
                color: i == selectedIndex ? const Color(0xFF00D4AA) : Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
