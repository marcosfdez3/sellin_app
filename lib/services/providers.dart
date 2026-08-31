import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// ─── Filtros del feed ─────────────────────────────────────────────────────────

class SignalFilter {
  final String? signalType;  // null = todos, 'buy', 'sell'
  final String? strength;
  final bool clusterOnly;

  const SignalFilter({
    this.signalType,
    this.strength,
    this.clusterOnly = false,
  });

  SignalFilter copyWith({
    Object? signalType = _sentinel,
    Object? strength = _sentinel,
    bool? clusterOnly,
  }) {
    return SignalFilter(
      signalType: signalType == _sentinel ? this.signalType : signalType as String?,
      strength: strength == _sentinel ? this.strength : strength as String?,
      clusterOnly: clusterOnly ?? this.clusterOnly,
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

  return client.getSignals(
    signalType: filter.signalType,
    strength: filter.strength,
    clusterOnly: filter.clusterOnly,
  );
});

// ─── Transacciones recientes ──────────────────────────────────────────────────

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getTransactions(limit: 50);
});

// ─── Transacciones de empresa ─────────────────────────────────────────────────

final companyTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, ticker) async {
  final client = ref.watch(apiClientProvider);
  return client.getCompanyTransactions(ticker);
});
