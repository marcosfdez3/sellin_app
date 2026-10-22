import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/providers.dart';

// ─── Tarjeta de señal ─────────────────────────────────────────────────────────

/// Tarjeta compacta: logo de la empresa, ticker y número de insiders.
/// Al pulsarla se despliega con el resto de datos de la señal.
/// El borde es verde en las compras y rojo en las ventas.
/// Con [asRow] se pinta como una fila sin borde ni fondo, para ir
/// dentro de un bloque que agrupa varias señales.
class SignalCard extends StatefulWidget {
  final Signal signal;
  final bool asRow;
  const SignalCard({super.key, required this.signal, this.asRow = false});

  @override
  State<SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<SignalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final color = signal.isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final n = signal.numInsiders;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: widget.asRow ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: widget.asRow
            ? null
            : BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(_expanded ? 0.6 : 0.3), width: 1),
              ),
        child: Column(
          children: [
            Row(
              children: [
                CompanyLogo(ticker: signal.company.ticker, name: signal.company.name),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _SignalDetails(signal: signal, color: color)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos que aparecen al desplegar la tarjeta: empresa, resumen, importe y fecha.
class _SignalDetails extends StatelessWidget {
  final Signal signal;
  final Color color;
  const _SignalDetails({required this.signal, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US');

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          if (signal.company.ticker != null) ...[
            Text(
              signal.company.name,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            signal.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Wrap: en pantallas estrechas los datos pasan a otra línea en vez de desbordar
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _IconText(
                icon: signal.isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                iconColor: color,
                text: fmt.format(signal.totalValue),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _IconText(
                icon: Icons.schedule_rounded,
                iconColor: Colors.white38,
                text: _formatDate(signal.lastTransactionDate),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/signal/${signal.id}', extra: signal),
              child: const Text('Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final TextStyle style;
  const _IconText({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 4),
          Text(text, style: style),
        ],
      );
}

/// Logo de la empresa (Financial Modeling Prep) sobre un círculo blanco.
/// Si no hay logo para ese ticker, muestra su inicial.
class CompanyLogo extends StatelessWidget {
  final String? ticker;
  final String name;
  final double size;
  const CompanyLogo({super.key, required this.ticker, required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final ticker = this.ticker;
    final initial = Center(
      child: Text(
        (ticker ?? name).characters.first.toUpperCase(),
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
