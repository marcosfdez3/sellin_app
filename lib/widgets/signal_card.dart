import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/providers.dart';

// ─── Tarjeta de señal ─────────────────────────────────────────────────────────

class SignalCard extends StatelessWidget {
  final Signal signal;
  const SignalCard({super.key, required this.signal});

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
                FollowButton(company: signal.company),
                const SizedBox(width: 4),
                // Score
                ScoreBadge(score: signal.score, color: color),
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

class ScoreBadge extends StatelessWidget {
  final double score;
  final Color color;
  const ScoreBadge({super.key, required this.score, required this.color});

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

/// Estrella para seguir / dejar de seguir una empresa.
class FollowButton extends ConsumerWidget {
  final Company company;
  const FollowButton({super.key, required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followedCompanyIdsProvider).contains(company.id);

    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: following ? 'Dejar de seguir' : 'Seguir',
      icon: Icon(
        following ? Icons.star_rounded : Icons.star_border_rounded,
        color: following ? const Color(0xFFFFD93D) : Colors.white38,
      ),
      onPressed: () async {
        try {
          await ref.read(followsProvider.notifier).toggle(company);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar. Inténtalo de nuevo.')),
          );
        }
      },
    );
  }
}
