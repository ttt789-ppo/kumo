import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../main.dart';
import '../widgets.dart';

/// DNS 配置编辑（对应 /control/dns_info + /control/dns_config）
class DnsConfigPage extends StatefulWidget {
  const DnsConfigPage({super.key});

  @override
  State<DnsConfigPage> createState() => _DnsConfigPageState();
}

class _DnsConfigPageState extends State<DnsConfigPage> {
  Map<String, dynamic>? _raw;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _upstream = TextEditingController();
  final _bootstrap = TextEditingController();
  final _fallback = TextEditingController();
  final _cacheSize = TextEditingController();
  final _ttlMin = TextEditingController();
  final _ttlMax = TextEditingController();
  String _mode = 'load_balance';
  bool _cache = true;
  bool _aaaa = false;

  static const _modes = {
    'load_balance': '负载均衡',
    'parallel': '并行',
    'fastest_addr': '最快地址',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _upstream.dispose();
    _bootstrap.dispose();
    _fallback.dispose();
    _cacheSize.dispose();
    _ttlMin.dispose();
    _ttlMax.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await appState.api.dnsInfo();
      if (!mounted) return;
      List<String> join(String k) =>
          ((d[k] as List?) ?? const []).map((e) => '$e').toList();
      setState(() {
        _raw = d;
        _upstream.text = join('upstream_dns').join('\n');
        _bootstrap.text = join('bootstrap_dns').join('\n');
        _fallback.text = join('fallback_dns').join('\n');
        _cacheSize.text = '${d['cache_size'] ?? 4194304}';
        _ttlMin.text = '${d['cache_ttl_min'] ?? 0}';
        _ttlMax.text = '${d['cache_ttl_max'] ?? 0}';
        _mode = (d['upstream_mode'] ?? 'load_balance').toString();
        if (!_modes.containsKey(_mode)) _mode = 'load_balance';
        _cache = d['cache_enabled'] != false;
        _aaaa = d['aaaa_disabled'] == true;
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

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final base = _raw;
    if (base == null) return;
    setState(() => _saving = true);
    try {
      final data = Map<String, dynamic>.from(base)
        ..['upstream_dns'] = _lines(_upstream)
        ..['bootstrap_dns'] = _lines(_bootstrap)
        ..['fallback_dns'] = _lines(_fallback)
        ..['upstream_mode'] = _mode
        ..['cache_enabled'] = _cache
        ..['cache_size'] = int.tryParse(_cacheSize.text.trim()) ?? 4194304
        ..['cache_ttl_min'] = int.tryParse(_ttlMin.text.trim()) ?? 0
        ..['cache_ttl_max'] = int.tryParse(_ttlMax.text.trim()) ?? 0
        ..['aaaa_disabled'] = _aaaa;
      await appState.api.setDnsConfig(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DNS 配置已保存')));
      Navigator.pop(context, true);
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('DNS 设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyBox(_error!, icon: Icons.error_outline)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const SectionLabel('上游 DNS'),
                    KsuCard(
                      child: TextField(
                        controller: _upstream,
                        maxLines: null,
                        minLines: 3,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '223.5.5.5\n119.29.29.29\nhttps://doh.pub/dns-query',
                          helperText: '一行一个，支持 IP / UDP / DoH / DoT',
                        ),
                      ),
                    ),
                    const SectionLabel('Bootstrap DNS'),
                    KsuCard(
                      child: TextField(
                        controller: _bootstrap,
                        maxLines: null,
                        minLines: 2,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '223.5.5.5\n119.29.29.29',
                        ),
                      ),
                    ),
                    const SectionLabel('Fallback DNS'),
                    KsuCard(
                      child: TextField(
                        controller: _fallback,
                        maxLines: null,
                        minLines: 2,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '留空表示不启用',
                        ),
                      ),
                    ),
                    const SectionLabel('上游模式'),
                    KsuCard(
                      child: Column(
                        children: [
                          for (final e in _modes.entries)
                            RadioListTile<String>(
                              value: e.key,
                              groupValue: _mode,
                              onChanged: (v) => setState(() => _mode = v ?? _mode),
                              title: Text(e.value),
                              subtitle: Text(e.key,
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                    const SectionLabel('缓存'),
                    KsuCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('启用缓存', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Switch(
                                  value: _cache,
                                  onChanged: (v) => setState(() => _cache = v)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _NumField(controller: _cacheSize, label: '缓存大小（字节）'),
                          const SizedBox(height: 10),
                          _NumField(controller: _ttlMin, label: '最小 TTL（秒）'),
                          const SizedBox(height: 10),
                          _NumField(controller: _ttlMax, label: '最大 TTL（秒，0 表示不限制）'),
                        ],
                      ),
                    ),
                    const SectionLabel('IPv6'),
                    KsuCard(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('停用 AAAA 查询',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                SizedBox(height: 3),
                                Text('抖音等 CDN 没有 IPv6，关掉能省一半查询',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(value: _aaaa, onChanged: (v) => setState(() => _aaaa = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('保存'),
                    ),
                  ],
                ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
