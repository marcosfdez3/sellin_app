import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth.dart';
import '../services/providers.dart';
import '../widgets/signal_card.dart';

/// Empresas que sigue el usuario, cada una con su señal más reciente.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followsAsync = ref.watch(followsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siguiendo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(followsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider).logout(),
          ),
        ],
      ),
      body: followsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.wifi_off_rounded,
          text: 'No se pudo conectar al servidor',
          action: ElevatedButton(
            onPressed: () => ref.invalidate(followsProvider),
            child: const Text('Reintentar'),
          ),
        ),
        data: (follows) => follows.isEmpty
            ? const _Message(
                icon: Icons.star_border_rounded,
                text: 'Aún no sigues ninguna empresa',
                hint: 'Pulsa la ★ de una señal para seguir su empresa',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(followsProvider.future),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  itemCount: follows.length,
                  itemBuilder: (context, i) {
                    final follow = follows[i];
                    final signal = follow.latestSignal;
                    return signal != null
                        ? SignalCard(key: ValueKey(signal.id), signal: signal)
                        : _CompanyCard(company: follow.company);
                  },
                ),
              ),
      ),
    );
  }
}

/// Empresa seguida que todavía no tiene señales.
class _CompanyCard extends StatelessWidget {
  final Company company;
  const _CompanyCard({required this.company});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CompanyLogo(ticker: company.ticker, name: company.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.ticker ?? company.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company.ticker != null ? '${company.name} · Sin señales' : 'Sin señales',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          FollowButton(company: company),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? hint;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.hint, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(color: Colors.white70)),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
