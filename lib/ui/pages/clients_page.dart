import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';
import 'client_detail_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<ClientEntry> _clients = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _clients.isEmpty;
      _error = null;
    });
    try {
      final list = await appState.api.clients();
      if (!mounted) return;
      setState(() {
        _clients = list;
        _loading = false;
      });
    } on AghException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manual = _clients.where((e) => !e.auto).toList();
    final auto = _clients.where((e) => e.auto).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
          children: [
            KsuHeader(
              title: '客户端',
              actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
            ),
            StatusBanner(
              title: '${_clients.length} 个设备',
              badge: '${manual.length} 手动',
              subtitle: '自动发现 ${auto.length} 个 · 来自 AdGuard Home 租约与配置',
              ok: true,
              icon: Icons.devices_other_outlined,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: KsuCard(
                  color: scheme.errorContainer,
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (manual.isNotEmpty) ...[
              const SectionLabel('已配置'),
              for (final c in manual) ...[
                _ClientTile(client: c),
                const SizedBox(height: 8),
              ],
            ],
            if (auto.isNotEmpty) ...[
              const SectionLabel('自动发现'),
              for (final c in auto) ...[
                _ClientTile(client: c),
                const SizedBox(height: 8),
              ],
            ],
            if (!_loading && _clients.isEmpty)
              const EmptyBox('没有客户端记录', icon: Icons.devices_other_outlined),
          ],
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final ClientEntry client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KsuCard(
      onTap: () => Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ClientDetailPage(clientName: client.name)),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  client.ids.isEmpty ? '—' : client.ids,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (client.blocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.error.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('已屏蔽', style: TextStyle(fontSize: 11, color: scheme.error)),
            ),
        ],
      ),
    );
  }
}
