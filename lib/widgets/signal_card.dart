import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../services/providers.dart';

// ─── Tarjeta de señal ─────────────────────────────────────────────────────────

/// Tarjeta compacta: logo de la empresa, ticker y número de insiders.
/// El borde es verde en las compras y rojo en las ventas.
class SignalCard extends StatelessWidget {
  final Signal signal;
  const SignalCard({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal.isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final n = signal.numInsiders;

    return GestureDetector(
      onTap: () => context.push('/signal/${signal.id}', extra: signal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            CompanyLogo(company: signal.company),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                signal.company.ticker ?? signal.company.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            const Icon(Icons.person_outline_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 4),
            Text(
              '$n insider${n == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 4),
            FollowButton(company: signal.company),
          ],
        ),
      ),
    );
  }
}

/// Logo de la empresa (Financial Modeling Prep) sobre un círculo blanco.
/// Si no hay logo para ese ticker, muestra su inicial.
class CompanyLogo extends StatelessWidget {
  final Company company;
  final double size;
  const CompanyLogo({super.key, required this.company, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final ticker = company.ticker;
    final initial = Center(
      child: Text(
        (ticker ?? company.name).characters.first.toUpperCase(),
        style: TextStyle(
          color: const Color(0xFF16213E),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ticker == null
          ? initial
          : Image.network(
              'https://financialmodelingprep.com/image-stock/${Uri.encodeComponent(ticker.toUpperCase())}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => initial,
              loadingBuilder: (_, child, progress) => progress == null ? child : const SizedBox(),
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
