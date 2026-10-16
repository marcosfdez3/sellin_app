import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth.dart';
import '../services/providers.dart';
import '../widgets/signal_card.dart';

/// Pantalla principal: las 3 mejores compras y las 3 mejores ventas de la semana.
class TopScreen extends ConsumerWidget {
  const TopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(topSignalsProvider('buy'));
      ref.invalidate(topSignalsProvider('sell'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/sellin.png',
          height: 70,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TopSection(
              title: '🟢 Mejores compras de la semana',
              emptyText: 'Sin compras esta semana',
              signals: ref.watch(topSignalsProvider('buy')),
              onRetry: refresh,
            ),
            const SizedBox(height: 24),
            _TopSection(
              title: '🔴 Mejores ventas de la semana',
              emptyText: 'Sin ventas esta semana',
              signals: ref.watch(topSignalsProvider('sell')),
              onRetry: refresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final AsyncValue<List<Signal>> signals;
  final VoidCallback onRetry;

  const _TopSection({
    required this.title,
    required this.emptyText,
    required this.signals,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        signals.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _Message(
            text: 'No se pudo conectar al servidor',
            action: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ),
          data: (list) => list.isEmpty
              ? _Message(text: emptyText)
              : Column(
                  children: [for (final s in list) SignalCard(signal: s)],
                ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(text, style: const TextStyle(color: Colors.white54)),
            if (action != null) action!,
          ],
        ),
      );
}
