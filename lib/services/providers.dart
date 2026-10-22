import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'auth.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Cada cuánto se recargan solos los datos mientras la pantalla está abierta.
const kAutoRefreshInterval = Duration(minutes: 2);

/// Hace que el provider se vuelva a pedir al backend pasado [kAutoRefreshInterval].
void _autoRefresh(Ref ref) {
  final timer = Timer(kAutoRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

// ─── Empresas ─────────────────────────────────────────────────────────────────

/// Resultados del buscador para un texto.
final companySearchProvider = FutureProvider.autoDispose
    .family<List<CompanyRef>, String>((ref, query) {
  return ref.watch(apiClientProvider).searchCompanies(query);
});

/// Empresas con más actividad de insiders esta semana.
final popularCompaniesProvider = FutureProvider.autoDispose<List<CompanyActivity>>((ref) {
  _autoRefresh(ref);
  return ref.watch(apiClientProvider).getPopularCompanies();
});

/// Ficha de una empresa por su CIK.
final companyOverviewProvider = FutureProvider.autoDispose
    .family<CompanyOverview, String>((ref, cik) {
  return ref.watch(apiClientProvider).getCompanyOverview(cik);
});

// ─── Top de la semana ─────────────────────────────────────────────────────────

/// Días que cuenta el apartado Top.
const kTopDays = 7;

/// Las 3 señales con mejor puntuación de la semana para 'buy' o 'sell'.
final topSignalsProvider = FutureProvider.autoDispose
    .family<List<Signal>, String>((ref, signalType) async {
  final client = ref.watch(apiClientProvider);
  _autoRefresh(ref);
  return client.getSignals(
    signalType: signalType,
    sortByScore: true,
    days: kTopDays,
    pageSize: 3,
  );
});

// ─── Grandes inversores ───────────────────────────────────────────────────────

/// Movimientos de los grandes inversores (13F). Cambian como mucho una vez al día.
final investorMovesProvider = FutureProvider.autoDispose<List<InvestorMove>>((ref) {
  return ref.watch(apiClientProvider).getInvestorMoves();
});

// ─── Siguiendo ────────────────────────────────────────────────────────────────

/// Empresas que sigue el usuario. Se recarga al iniciar o cerrar sesión.
class FollowsNotifier extends AsyncNotifier<List<Follow>> {
  @override
  Future<List<Follow>> build() async {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn) return [];
    return ref.watch(apiClientProvider).getFollows();
  }

  /// Sigue o deja de seguir [company]. La estrella cambia al momento y,
  /// si el servidor falla, vuelve a como estaba y lanza el error.
  Future<void> toggle(Company company) async {
    final client = ref.read(apiClientProvider);
    final current = state.valueOrNull ?? const <Follow>[];
    final following = current.any((f) => f.company.id == company.id);

    state = AsyncData(following
        ? current.where((f) => f.company.id != company.id).toList()
        : [Follow(company: company, followedAt: DateTime.now()), ...current]);
    try {
      following ? await client.unfollow(company.id) : await client.follow(company.id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
    // Recarga para traer la última señal de la empresa recién seguida
    ref.invalidateSelf();
  }
}

final followsProvider =
    AsyncNotifierProvider<FollowsNotifier, List<Follow>>(FollowsNotifier.new);

/// IDs de las empresas seguidas, para pintar la estrella de cada señal.
final followedCompanyIdsProvider = Provider<Set<int>>((ref) {
  final follows = ref.watch(followsProvider).valueOrNull ?? const <Follow>[];
  return {for (final f in follows) f.company.id};
});

// ─── Transacciones de empresa ─────────────────────────────────────────────────

final companyTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, ticker) async {
  final client = ref.watch(apiClientProvider);
  return client.getCompanyTransactions(ticker);
});
