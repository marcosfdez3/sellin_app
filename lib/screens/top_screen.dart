import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth.dart';
import '../services/providers.dart';
import '../widgets/investor_ticker.dart';
import '../widgets/signal_card.dart';

/// Lado que se muestra en el Top: 'buy' (compras) o 'sell' (ventas).
/// Se mantiene al cambiar de pestaña mientras la app está abierta.
final _topTypeProvider = StateProvider<String>((ref) => 'buy');

const _topTitles = {
  'buy': 'Mejores compras de la semana',
  'sell': 'Mejores ventas de la semana',
};

/// Pantalla principal: las 3 mejores compras o ventas de la semana,
/// con un desplegable para cambiar de una a otra.
class TopScreen extends ConsumerWidget {
  const TopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(_topTypeProvider);
    void refresh() {
      ref.invalidate(topSignalsProvider(type));
      ref.invalidate(investorMovesProvider);
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
          children: [
            const _InvestorMovesStrip(),
            _TopSection(
              header: _TypeDropdown(
                value: type,
                onChanged: (t) => ref.read(_topTypeProvider.notifier).state = t,
              ),
              emptyText: type == 'buy' ? 'Sin compras esta semana' : 'Sin ventas esta semana',
              signals: ref.watch(topSignalsProvider(type)),
              onRetry: refresh,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cinta de movimientos de los grandes inversores, con el trimestre encima.
/// Mientras carga o si falla no ocupa sitio: no debe tapar el Top.
class _InvestorMovesStrip extends ConsumerWidget {
  const _InvestorMovesStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(investorMovesProvider).valueOrNull ?? const [];
    if (moves.isEmpty) return const SizedBox.shrink();

    final latest = moves.map((m) => m.period).reduce((a, b) => a.isAfter(b) ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Grandes inversores · ${quarterLabel(latest)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          InvestorTicker(moves: moves),
        ],
      ),
    );
  }
}

/// Título del Top con una flecha: al pulsarlo deja elegir compras o ventas.
class _TypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: const Color(0xFF1E1E1E),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      itemBuilder: (context) => [
        for (final entry in _topTitles.entries)
          PopupMenuItem(
            value: entry.key,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: entry.key == value ? Colors.white10 : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(entry.value)),
                  if (entry.key == value)
                    const Icon(Icons.check_rounded, size: 18, color: Color(0xFF00D4AA)),
                ],
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _topTitles[value]!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  final Widget header;
  final String emptyText;
  final AsyncValue<List<Signal>> signals;
  final VoidCallback onRetry;

  const _TopSection({
    required this.header,
    required this.emptyText,
    required this.signals,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Un solo bloque: título con el desplegable y las señales como filas
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Align(alignment: Alignment.centerLeft, child: header),
          ),
          const Divider(height: 1, color: Colors.white12),
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
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, s) in list.indexed) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                          SignalCard(key: ValueKey(s.id), signal: s, asRow: true),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
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
