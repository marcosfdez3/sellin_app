import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

/// Cinta con los movimientos de los grandes inversores que se desplaza sola
/// de derecha a izquierda, en bucle. Se para mientras se mantiene pulsada.
class InvestorTicker extends StatefulWidget {
  final List<InvestorMove> moves;
  const InvestorTicker({super.key, required this.moves});

  @override
  State<InvestorTicker> createState() => _InvestorTickerState();
}

class _InvestorTickerState extends State<InvestorTicker>
    with SingleTickerProviderStateMixin {
  /// Velocidad de la cinta, en píxeles por segundo
  static const _speed = 40.0;

  final _controller = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (_paused || !_controller.hasClients) return;
    _controller.jumpTo(_controller.offset + _speed * seconds);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    return Listener(
      onPointerDown: (_) => _paused = true,
      onPointerUp: (_) => _paused = false,
      onPointerCancel: (_) => _paused = false,
      child: SizedBox(
        height: 36,
        // Lista sin fin: el elemento i es moves[i % n], así la cinta nunca se acaba
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MoveChip(move: moves[i % moves.length]),
          ),
        ),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final InvestorMove move;
  const _MoveChip({required this.move});

  static const _actions = {
    'new': 'Compra',
    'add': 'Aumenta',
    'reduce': 'Reduce',
    'exit': 'Vende todo',
  };

  @override
  Widget build(BuildContext context) {
    final color = move.isBuy ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final amount = NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US')
        .format(move.valueChange.abs());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${move.investor}  ',
              style: const TextStyle(color: Colors.white60),
            ),
            TextSpan(
              text: '${_actions[move.action] ?? move.action} ',
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: '${move.ticker ?? shortCompanyName(move.issuer)} ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '${move.isBuy ? '+' : '−'}$amount',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// Nombre corto y legible de una empresa del 13F, para cuando no hay ticker:
/// "SEALED AIR CORP NEW" → "Sealed Air".
String shortCompanyName(String issuer) {
  const suffixes = {
    'INC', 'CORP', 'CO', 'LTD', 'PLC', 'NEW', 'HLDGS', 'HOLDINGS', 'COM',
    'DEL', 'LP', 'LLC', 'CL', 'A', 'B', 'SA', 'NV', 'AG', 'SE',
  };
  final words = issuer.replaceAll(RegExp(r'[.,/]'), ' ').split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  while (words.length > 1 && suffixes.contains(words.last.toUpperCase())) {
    words.removeLast();
  }
  return words.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}

/// "T2 2026" a partir de la fecha de cierre del trimestre de un 13F.
String quarterLabel(DateTime period) => 'T${(period.month + 2) ~/ 3} ${period.year}';
