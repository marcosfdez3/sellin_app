import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../services/providers.dart';
import '../services/api_client.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(signalsProvider);
    final filter = ref.watch(signalFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
    'assets/images/sellin.png',  
    height: 70,
  ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(signalsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
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
                        itemBuilder: (context, i) => _SignalCard(signal: signals[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filtros ──────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final SignalFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Chip(
            label: 'Todos',
            selected: filter.signalType == null,
            onTap: () => ref.read(signalFilterProvider.notifier).state =
                filter.copyWith(signalType: null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '🟢 Compras',
            selected: filter.signalType == 'buy',
            color: const Color(0xFF00D4AA),
            onTap: () => ref.read(signalFilterProvider.notifier).state =
                filter.copyWith(signalType: 'buy'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '🔴 Ventas',
            selected: filter.signalType == 'sell',
            color: const Color(0xFFFF6B6B),
            onTap: () => ref.read(signalFilterProvider.notifier).state =
                filter.copyWith(signalType: 'sell'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '⚡ Cluster',
            selected: filter.clusterOnly,
            color: const Color(0xFFFFD93D),
            onTap: () => ref.read(signalFilterProvider.notifier).state =
                filter.copyWith(clusterOnly: !filter.clusterOnly),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF00D4AA);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta de señal ─────────────────────────────────────────────────────────

class _SignalCard extends StatelessWidget {
  final Signal signal;
  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final isBuy = signal.isBuy;
    final color = isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final fmt = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US');

    return GestureDetector(
      onTap: () => context.push('/signal/${signal.id}', extra: signal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ticker + badge
            Row(
              children: [
                // Ticker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    signal.company.ticker ?? signal.company.name,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cluster badge
                if (signal.isCluster)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD93D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚡ CLUSTER',
                      style: TextStyle(
                        color: Color(0xFFFFD93D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                // Score
                _ScoreBadge(score: signal.score, color: color),
              ],
            ),
            const SizedBox(height: 12),
            // Resumen
            Text(
              signal.summary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Footer: valor + insiders + fecha
            Row(
              children: [
                Icon(
                  isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  fmt.format(signal.totalValue),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person_outline_rounded, color: Colors.white38, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${signal.numInsiders} insider${signal.numInsiders > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _formatDate(signal.lastTransactionDate),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return '${diff.inDays}d atrás';
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final Color color;
  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          score.toInt().toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
