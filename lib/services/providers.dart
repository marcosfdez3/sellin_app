import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Cada cuánto se recargan solos los datos mientras la pantalla está abierta.
const kAutoRefreshInterval = Duration(minutes: 2);

/// Hace que el provider se vuelva a pedir al backend pasado [kAutoRefreshInterval].
void _autoRefresh(Ref ref) {
  final timer = Timer(kAutoRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

// ─── Filtros del feed ─────────────────────────────────────────────────────────

class SignalFilter {
  final String? signalType;  // 'buy' o 'sell' (null = todos)
  final String? strength;
  final bool clusterOnly;
  final bool sortByScore;  // false = más recientes primero

  const SignalFilter({
    this.signalType = 'buy',
    this.strength,
    this.clusterOnly = false,
    this.sortByScore = false,
  });

  SignalFilter copyWith({
    Object? signalType = _sentinel,
    Object? strength = _sentinel,
    bool? clusterOnly,
    bool? sortByScore,
  }) {
    return SignalFilter(
      signalType: signalType == _sentinel ? this.signalType : signalType as String?,
      strength: strength == _sentinel ? this.strength : strength as String?,
      clusterOnly: clusterOnly ?? this.clusterOnly,
      sortByScore: sortByScore ?? this.sortByScore,
    );
  }
}

const _sentinel = Object();

final signalFilterProvider = StateProvider<SignalFilter>(
  (ref) => const SignalFilter(),
);

// ─── Señales ──────────────────────────────────────────────────────────────────

final signalsProvider = FutureProvider.autoDispose<List<Signal>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final filter = ref.watch(signalFilterProvider);
  _autoRefresh(ref);

  return client.getSignals(
    signalType: filter.signalType,
    strength: filter.strength,
    clusterOnly: filter.clusterOnly,
    sortByScore: filter.sortByScore,
  );
});

// ─── Transacciones recientes ──────────────────────────────────────────────────

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final client = ref.watch(apiClientProvider);
  _autoRefresh(ref);
  return client.getTransactions(limit: 50);
});

// ─── Transacciones de empresa ─────────────────────────────────────────────────

final companyTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, ticker) async {
  final client = ref.watch(apiClientProvider);
  return client.getCompanyTransactions(ticker);
});
