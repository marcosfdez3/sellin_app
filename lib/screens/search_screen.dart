import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../services/auth.dart';
import '../services/providers.dart';
import '../widgets/signal_card.dart';

/// Buscador de acciones; sin texto, muestra las más activas de la semana.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// Espera a que se deje de escribir un momento antes de buscar.
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (text) {
                _onChanged(text);
                setState(() {}); // muestra u oculta la X
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar empresa o ticker',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clear),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty ? const _PopularList() : _ResultsList(query: _query),
          ),
        ],
      ),
    );
  }
}

/// Empresas con más actividad de insiders esta semana.
class _PopularList extends ConsumerWidget {
  const _PopularList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularCompaniesProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(popularCompaniesProvider.future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Más activas esta semana',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...popular.when(
            loading: () => const [_Loading()],
            error: (_, __) => [
              _Message(
                text: 'No se pudo conectar al servidor',
                onRetry: () => ref.invalidate(popularCompaniesProvider),
              ),
            ],
            data: (list) => list.isEmpty
                ? const [_Message(text: 'Sin actividad de insiders esta semana')]
                : [
                    for (final a in list)
                      _CompanyTile(
                        ticker: a.company.ticker,
                        name: a.company.name,
                        subtitle: '${a.numTransactions} operaciones · '
                            '${a.numInsiders} insider${a.numInsiders == 1 ? '' : 's'}',
                        onTap: () => _openCompany(context, a.company.cik, a.company.ticker, a.company.name),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  final String query;
  const _ResultsList({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(companySearchProvider(query)).when(
          loading: () => const _Loading(),
          error: (_, __) => _Message(
            text: 'No se pudo buscar',
            onRetry: () => ref.invalidate(companySearchProvider(query)),
          ),
          data: (results) => results.isEmpty
              ? _Message(text: 'Sin resultados para "$query"')
              : ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    for (final c in results)
                      _CompanyTile(
                        ticker: c.ticker,
                        name: c.name,
                        onTap: () => _openCompany(context, c.cik, c.ticker, c.name),
                      ),
                  ],
                ),
        );
  }
}

void _openCompany(BuildContext context, String cik, String? ticker, String name) {
  FocusScope.of(context).unfocus();
  context.push('/company/$cik', extra: CompanyRef(cik: cik, ticker: ticker, name: name));
}

class _CompanyTile extends StatelessWidget {
  final String? ticker;
  final String name;
  final String? subtitle;
  final VoidCallback onTap;

  const _CompanyTile({required this.ticker, required this.name, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CompanyLogo(ticker: ticker, name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticker ?? name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle != null ? '$name · $subtitle' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
}
