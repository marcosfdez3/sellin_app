import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../services/providers.dart';
import '../services/auth.dart';
import '../widgets/signal_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(signalsProvider);
    final filter = ref.watch(signalFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Señales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(signalsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: signalsAsync.when(
              loading: () => _ShimmerList(),
              error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(signalsProvider)),
              data: (signals) => signals.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(signalsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: signals.length,
                        itemBuilder: (context, i) => SignalCard(signal: signals[i]),
                      ),
                    ),
            ),
          ),
          _BuySellBar(filter: filter),
        ],
      ),
    );
  }
}

// ─── Filtros ──────────────────────────────────────────────────────────────────

/// Compras / Ventas: dos botones fijos en la parte de abajo del feed.
class _BuySellBar extends ConsumerWidget {
  final SignalFilter filter;
  const _BuySellBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String type) =>
        ref.read(signalFilterProvider.notifier).state = filter.copyWith(signalType: type);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SideButton(
              label: '🟢 Compras',
              selected: filter.signalType == 'buy',
              color: const Color(0xFF00D4AA),
              onTap: () => select('buy'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SideButton(
              label: '🔴 Ventas',
              selected: filter.signalType == 'sell',
              color: const Color(0xFFFF6B6B),
              onTap: () => select('sell'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ─── Estados vacío/error/loading ──────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No hay señales todavía', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No se pudo conectar al servidor',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFF16213E),
        highlightColor: const Color(0xFF1A2744),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
}
