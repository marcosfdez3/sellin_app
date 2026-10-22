import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/providers.dart';
import '../widgets/signal_card.dart';

/// Ficha de una empresa: cabecera con la ★ para seguirla, sus señales
/// recientes y las últimas transacciones de sus insiders.
class CompanyScreen extends ConsumerWidget {
  final String cik;

  /// Lo que ya se sabe de la empresa (desde el buscador), para la cabecera
  /// mientras carga la ficha.
  final CompanyRef? preview;

  const CompanyScreen({super.key, required this.cik, this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(companyOverviewProvider(cik));
    final company = overview.valueOrNull?.company;
    final ticker = company?.ticker ?? preview?.ticker;
    final name = company?.name ?? preview?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(ticker ?? name)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(companyOverviewProvider(cik).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Cabecera ──────────────────────────────────────────────────────
            Row(
              children: [
                CompanyLogo(ticker: ticker, name: name, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticker ?? name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (ticker != null)
                        Text(name, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                // La ★ necesita el id de la BD, que llega con la ficha
                if (company != null) FollowButton(company: company),
              ],
            ),
            const SizedBox(height: 24),

            ...overview.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, __) => [
                const Text('No se pudo cargar la empresa', style: TextStyle(color: Colors.white54)),
                TextButton(
                  onPressed: () => ref.invalidate(companyOverviewProvider(cik)),
                  child: const Text('Reintentar'),
                ),
              ],
              data: (o) => [
                const _SectionTitle('Señales recientes'),
                if (o.signals.isEmpty)
                  const _Empty('Sin señales de insiders')
                else
                  for (final s in o.signals) SignalCard(key: ValueKey(s.id), signal: s),
                const SizedBox(height: 16),
                const _SectionTitle('Transacciones de insiders'),
                if (o.transactions.isEmpty)
                  const _Empty('Sin transacciones registradas')
                else
                  for (final tx in o.transactions) _TxRow(tx: tx),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  const _TxRow({required this.tx});

  static const _types = {
    'buy': 'Compra',
    'sell': 'Venta',
    'exercise': 'Ejercicio de opciones',
    'award': 'Concesión de acciones',
    'other': 'Otra operación',
  };

  @override
  Widget build(BuildContext context) {
    final isBuy = tx.transactionType == 'buy';
    final isSell = tx.transactionType == 'sell';
    final color = isBuy
        ? const Color(0xFF00D4AA)
        : isSell
            ? const Color(0xFFFF6B6B)
            : Colors.white54;
    final value = tx.totalValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isBuy
                ? Icons.add_circle_outline
                : isSell
                    ? Icons.remove_circle_outline
                    : Icons.swap_horiz_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.insiderName ?? (kRoleLabels[tx.insiderRole] ?? tx.insiderRole),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  '${kRoleLabels[tx.insiderRole] ?? tx.insiderRole} · '
                  '${DateFormat('dd MMM yyyy', 'es_ES').format(tx.transactionDate)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _types[tx.transactionType] ?? tx.transactionType,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (value != null && value > 0)
                Text(
                  NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US').format(value),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white38)),
      );
}
