import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/company_screen.dart';
import 'screens/login_screen.dart';
import 'screens/following_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/search_screen.dart';
import 'screens/top_screen.dart';
import 'screens/signal_detail_screen.dart';
import 'services/api_client.dart';
import 'services/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Antes del primer frame solo se carga el logo de la splash: lo demás se
  // carga con el logo ya en pantalla (SellinBootstrap)
  const logo = SvgAssetLoader(kWordmarkAsset);
  await svg.cache.putIfAbsent(logo.cacheKey(null), () => logo.loadBytes(null));

  runApp(const SellinBootstrap());
}

const kWordmarkAsset = 'assets/images/sellin_wordmark.svg';

/// La splash dura 2,5 s en total: el logo entra creciendo desde el centro
/// ([kSplashIntro]), se queda quieto hasta [kSplashMinDuration] desde el
/// arranque y sale encogiéndose hacia el centro ([kSplashOutro]) mientras el
/// negro se funde con la app.
const kSplashIntro = Duration(milliseconds: 600);
const kSplashMinDuration = Duration(milliseconds: 2000);
const kSplashOutro = Duration(milliseconds: 500);

/// Arranque de la app. Muestra la splash (el logo grande sobre negro) mientras
/// recupera la sesión guardada y carga las fechas en español, y como mínimo
/// [kSplashMinDuration]; después pinta la app debajo y retira el logo.
/// La splash del sistema es solo negra: Android 12+ escala y emborrona su
/// icono, así que el logo se dibuja aquí, desde el SVG.
class SellinBootstrap extends StatefulWidget {
  const SellinBootstrap({super.key});

  @override
  State<SellinBootstrap> createState() => _SellinBootstrapState();
}

class _SellinBootstrapState extends State<SellinBootstrap> with TickerProviderStateMixin {
  final _auth = AuthController(ApiClient());
  GoRouter? _router;  // null mientras se carga
  bool _splashDone = false;

  late final _intro = AnimationController(vsync: this, duration: kSplashIntro);
  late final _outro = AnimationController(vsync: this, duration: kSplashOutro)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _splashDone = true);
    });

  // Entrada: de nada a tamaño completo, frenando al final
  late final _introScale = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
  // Salida, al revés: encoge hacia el centro acelerando (la primera parte)…
  late final _outroScale = CurvedAnimation(
    parent: _outro,
    curve: const Interval(0, 0.7, curve: Curves.easeInCubic),
  );
  // …y el fondo negro se funde con la app al final
  late final _outroFade = CurvedAnimation(parent: _outro, curve: const Interval(0.4, 1));

  @override
  void initState() {
    super.initState();
    // La entrada empieza con el primer frame ya en pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro.forward());
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      // Nombres de meses en español para las fechas (DateFormat con 'es_ES')
      initializeDateFormatting('es_ES'),
      // Sesión guardada: decide si la primera pantalla es el login
      _auth.load(),
      Future.delayed(kSplashMinDuration),
    ]);
    if (!mounted) return;
    setState(() => _router = _buildRouter(_auth));
    // La salida empieza cuando la app ya está pintada debajo del logo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _outro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _outro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (router != null)
            ProviderScope(
              overrides: [authProvider.overrideWith((ref) => _auth)],
              child: InsiderTrackApp(router: router),
            ),
          if (!_splashDone)
            AbsorbPointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _outro]),
                builder: (context, logo) {
                  final scale = _introScale.value * (1 - _outroScale.value);
                  return Opacity(
                    opacity: 1 - _outroFade.value,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Opacity(
                          opacity: scale.clamp(0.0, 1.0),
                          child: Transform.scale(scale: scale, child: logo),
                        ),
                      ),
                    ),
                  );
                },
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: SvgPicture.asset(kWordmarkAsset),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

GoRouter _buildRouter(AuthController auth) => GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    // Pantallas que se ven sin sesión iniciada
    final public = const {'/login', '/forgot'}.contains(state.matchedLocation);
    if (!auth.isLoggedIn) return public ? null : '/login';
    if (public) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot',
      builder: (context, state) => ForgotPasswordScreen(initialEmail: state.extra as String?),
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
