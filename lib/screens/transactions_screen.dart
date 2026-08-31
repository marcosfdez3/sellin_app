import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/providers.dart';
import '../services/api_client.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
    'assets/images/sellin.png',
    height: 70,
  ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(transactionsProvider),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(e.toString(), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(transactionsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (txs) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(transactionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: txs.length,
            itemBuilder: (context, i) => _TransactionCard(tx: txs[i]),
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction tx;
  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isBuy = tx.transactionType == 'buy';
    final isExercise = tx.transactionType == 'exercise';
    final color = isBuy
        ? const Color(0xFF00D4AA)
        : isExercise
            ? const Color(0xFFFFD93D)
            : const Color(0xFFFF6B6B);

    final fmt = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          // Icono
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_txIcon(tx.transactionType), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.company.ticker ?? tx.company.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${tx.insiderRole} · ${_txLabel(tx.transactionType)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(tx.transactionDate),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Valor
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tx.totalValue != null)
                Text(
                  fmt.format(tx.totalValue),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              Text(
                '${_formatShares(tx.shares)} acc.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'buy': return Icons.add_rounded;
      case 'sell': return Icons.remove_rounded;
      case 'exercise': return Icons.swap_horiz_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  String _txLabel(String type) {
    switch (type) {
      case 'buy': return 'Compra';
      case 'sell': return 'Venta';
      case 'exercise': return 'Ejercicio';
      case 'award': return 'Award';
      default: return 'Otro';
    }
  }

  String _formatShares(double shares) {
    if (shares >= 1000000) return '${(shares / 1000000).toStringAsFixed(1)}M';
    if (shares >= 1000) return '${(shares / 1000).toStringAsFixed(0)}K';
    return shares.toStringAsFixed(0);
  }
}
