import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/providers.dart';

class SignalDetailScreen extends ConsumerWidget {
  final Signal signal;
  const SignalDetailScreen({super.key, required this.signal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = signal.isBuy;
    final color = isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final fmt = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US');
    final txAsync = ref.watch(
      companyTransactionsProvider(signal.company.ticker ?? ''),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(signal.company.ticker ?? signal.company.name),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero card ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isBuy ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: color,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBuy ? 'SEÑAL DE COMPRA' : 'SEÑAL DE VENTA',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            signal.company.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Score grande
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            signal.score.toInt().toString(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    signal.summary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Métricas ─────────────────────────────────────────────────────
            const _SectionTitle('Detalle'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Valor total',
                    value: fmt.format(signal.totalValue),
                    icon: Icons.attach_money_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Insiders',
                    value: signal.numInsiders.toString(),
                    icon: Icons.people_outline_rounded,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Fortaleza',
                    value: _strengthLabel(signal.strength),
                    icon: Icons.bolt_rounded,
                    color: _strengthColor(signal.strength),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Cluster',
                    value: signal.isCluster ? 'Sí ⚡' : 'No',
                    icon: Icons.group_work_outlined,
                    color: signal.isCluster ? const Color(0xFFFFD93D) : Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Fechas ───────────────────────────────────────────────────────
            const _SectionTitle('Período'),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Primera transacción',
              value: _formatDate(signal.firstTransactionDate),
            ),
            _InfoRow(
              label: 'Última transacción',
              value: _formatDate(signal.lastTransactionDate),
            ),
            const SizedBox(height: 24),

            // ── Transacciones recientes de la empresa ─────────────────────────
            const _SectionTitle('Historial de transacciones'),
            const SizedBox(height: 12),
            txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text(
                'No se pudieron cargar las transacciones',
                style: TextStyle(color: Colors.white38),
              ),
              data: (txs) => txs.isEmpty
                  ? const Text('Sin transacciones', style: TextStyle(color: Colors.white38))
                  : Column(
                      children: txs.take(10).map((tx) => _TxRow(tx: tx)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy', 'es_ES').format(dt);

  String _strengthLabel(String s) {
    switch (s) {
      case 'strong': return 'Fuerte';
      case 'medium': return 'Media';
      default: return 'Débil';
    }
  }

  Color _strengthColor(String s) {
    switch (s) {
      case 'strong': return const Color(0xFF00D4AA);
      case 'medium': return const Color(0xFFFFD93D);
      default: return Colors.white38;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isBuy = tx.transactionType == 'buy';
    final color = isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final fmt = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.insiderRole,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(
                  DateFormat('dd MMM yyyy').format(tx.transactionDate),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (tx.totalValue != null)
            Text(
              fmt.format(tx.totalValue),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
