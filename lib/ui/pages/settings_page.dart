import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';
import 'dns_config_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<DnsRewrite> _rewrites = const [];
  Map<String, dynamic> _dns = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rw = await appState.api.rewrites();
      final dns = await appState.api.dnsInfo();
      if (!mounted) return;
      setState(() {
        _rewrites = rw;
        _dns = dns;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDns() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DnsConfigPage()),
    );
    await _load();
  }

  Future<void> _addRewrite() async {
    final domain = TextEditingController();
    final answer = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 DNS 重写'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: domain,
              decoration: const InputDecoration(hintText: '域名，例如 github.com'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answer,
              decoration: const InputDecoration(hintText: 'IP，例如 140.82.114.3'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.api.addRewrite(domain.text.trim(), answer.text.trim());
      await _load();
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = appState.store.active;
    final ups = ((_dns['upstream_dns'] as List?) ?? const []).map((e) => '$e').toList();
    final bootstrap = ((_dns['bootstrap_dns'] as List?) ?? const []).map((e) => '$e').toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
          children: [
            const KsuHeader(title: '设置'),
            if (cfg != null)
              StatusBanner(
                title: cfg.name,
                badge: cfg.scheme.toUpperCase(),
                subtitle: cfg.label,
                ok: true,
                icon: Icons.lan_outlined,
              ),
            const SectionLabel('DNS 配置'),
            InfoTile(
              icon: Icons.cloud_queue,
              title: '上游 DNS',
              value: ups.isEmpty ? '—' : ups.join('\n'),
              onTap: _openDns,
            ),
            const SizedBox(height: 10),
            InfoTile(
              icon: Icons.hub_outlined,
              title: 'Bootstrap',
              value: bootstrap.isEmpty ? '—' : bootstrap.join('、'),
              onTap: _openDns,
            ),
            const SizedBox(height: 10),
            InfoTile(
              icon: Icons.cached,
              title: '缓存',
              onTap: _openDns,
              value: _dns['cache_enabled'] == true
                  ? '已开启 · 最小 TTL ${_dns['cache_ttl_min'] ?? 0}s'
                  : '已关闭',
            ),
            const SizedBox(height: 10),
            InfoTile(
              icon: Icons.abc,
              title: 'AAAA 查询',
              value: _dns['aaaa_disabled'] == true ? '已停用（省流量）' : '正常返回',
              onTap: _openDns,
            ),
            const SectionLabel(
              'DNS 重写',
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final r in _rewrites) ...[
              KsuCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.domain, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(r.answer,
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        try {
                          await appState.api.deleteRewrite(r);
                          await _load();
                        } on AghException catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!_loading && _rewrites.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: KsuCard(
                  onTap: _addRewrite,
                  child: const Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 12),
                      Text('添加 DNS 重写', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SectionLabel('连接'),
            KsuCard(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('断开连接'),
                    content: const Text('只是从 App 移除当前连接，不会改动服务器。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('断开')),
                    ],
                  ),
                );
                if (ok == true) await appState.store.disconnect();
              },
              child: Row(
                children: [
                  Icon(Icons.logout, color: scheme.error),
                  const SizedBox(width: 14),
                  Text('断开连接', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SectionLabel('关于'),
            const InfoTile(
              icon: Icons.info_outline,
              title: 'Kumo',
              value: '1.0.0 · 面向 AdGuard Home 的管理客户端',
            ),
          ],
        ),
      ),
    );
  }
}
