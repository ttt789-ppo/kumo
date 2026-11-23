import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../main.dart';
import '../widgets.dart';

/// 客户端详情 / 分应用放行
///
/// AdGuard Home 只按客户端 IP 区分，无法识别 App 包名，
/// 所以这里做的是「按设备放行」：关掉某个客户端的过滤，该设备就整体不过滤。
class ClientDetailPage extends StatefulWidget {
  final String clientName;
  const ClientDetailPage({super.key, required this.clientName});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _useGlobal = true;
  bool _filtering = true;
  bool _safeBrowsing = false;
  bool _parental = false;
  bool _safeSearch = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await appState.api.clientRaw(widget.clientName);
      if (!mounted) return;
      setState(() {
        _data = d;
        _useGlobal = d['use_global_settings'] != false;
        _filtering = d['filtering_enabled'] != false;
        _safeBrowsing = d['safe_browsing_enabled'] == true;
        _parental = d['parental_enabled'] == true;
        _safeSearch = d['safesearch_enabled'] == true;
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

  Future<void> _save() async {
    final base = _data;
    if (base == null) return;
    setState(() => _saving = true);
    try {
      final data = Map<String, dynamic>.from(base)
        ..['use_global_settings'] = _useGlobal
        ..['filtering_enabled'] = _filtering
        ..['safe_browsing_enabled'] = _safeBrowsing
        ..['parental_enabled'] = _parental
        ..['safesearch_enabled'] = _safeSearch;
      await appState.api.updateClient(widget.clientName, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
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
      appBar: AppBar(title: const Text('客户端设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyBox(_error!, icon: Icons.error_outline)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    StatusBanner(
                      title: _filtering ? '正在过滤' : '已放行',
                      badge: _useGlobal ? '跟随全局' : '独立设置',
                      subtitle: widget.clientName,
                      ok: _filtering,
                      icon: _filtering ? Icons.shield_outlined : Icons.shield_moon_outlined,
                    ),
                    const SectionLabel('放行策略'),
                    _SwitchTile(
                      title: '使用全局设置',
                      subtitle: '关闭后本客户端单独配置下面几项',
                      value: _useGlobal,
                      onChanged: (v) => setState(() => _useGlobal = v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      title: '规则过滤',
                      subtitle: '关掉即该设备整机放行（不过滤广告）',
                      value: _filtering,
                      onChanged: _useGlobal ? null : (v) => setState(() => _filtering = v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      title: '安全浏览',
                      subtitle: '拦截恶意站点',
                      value: _safeBrowsing,
                      onChanged: _useGlobal ? null : (v) => setState(() => _safeBrowsing = v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      title: '家长控制',
                      subtitle: '过滤成人内容',
                      value: _parental,
                      onChanged: _useGlobal ? null : (v) => setState(() => _parental = v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      title: '安全搜索',
                      subtitle: '强制搜索引擎安全模式',
                      value: _safeSearch,
                      onChanged: _useGlobal ? null : (v) => setState(() => _safeSearch = v),
                    ),
                    const SectionLabel('说明'),
                    KsuCard(
                      child: Text(
                        'AdGuard Home 只能按客户端 IP 识别设备，读不到 App 包名，'
                        '所以做不到「只放行某个 App」。要按 App 放行，需要在系统层做 uid 级的分流，'
                        'DNS 这一层没有这个能力。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
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

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KsuCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
