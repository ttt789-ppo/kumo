import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../theme.dart';
import '../widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AghStatus? _status;
  AghStats? _stats;
  List<String> _upstreams = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = _status == null;
      _error = null;
    });
    try {
      final api = appState.api;
      final s = await api.status();
      final st = await api.stats();
      final ups = await api.upstreams();
      if (!mounted) return;
      setState(() {
        _status = s;
        _stats = st;
        _upstreams = ups;
        _loading = false;
      });
    } on AghException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleProtection() async {
    final s = _status;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    try {
      final enabled = await appState.api.setProtection(!s.protectionEnabled);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? '已开启保护' : '已暂停保护')),
      );
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = appState.store.active;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
          children: [
            KsuHeader(
              title: 'Kumo',
              actions: [
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: _toggleProtection,
                  icon: Icon(_status?.protectionEnabled == false
                      ? Icons.power_settings_new
                      : Icons.shield_outlined),
                  tooltip: '保护开关',
                ),
              ],
            ),
            if (_error != null)
              KsuCard(
                color: scheme.errorContainer,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            if (_loading && _status == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_status != null) ...[
              StatusBanner(
                title: _status!.protectionEnabled ? '工作中' : '已暂停',
                badge: _status!.version,
                subtitle: cfg == null ? '' : '${cfg.host}:${cfg.port}',
                ok: _status!.protectionEnabled,
                icon: _status!.protectionEnabled ? Icons.verified_outlined : Icons.pause_circle_outline,
                onTap: _toggleProtection,
              ),
              const SectionLabel('数据总览'),
              Row(
                children: [
                  MetricBox(
                    label: '今日查询',
                    value: _fmt(_stats?.sumQueries ?? 0),
                    sub: '${_stats?.querySeries.length ?? 0} 个时间点',
                  ),
                  const SizedBox(width: 12),
                  MetricBox(
                    label: '已拦截',
                    value: _fmt(_stats?.sumBlocked ?? 0),
                    sub: _blockRate,
                    color: scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KsuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('查询趋势', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(
                          '均 ${_avgMs} ms',
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Sparkline(
                      data: _stats?.normalizedQueries ?? const [],
                      second: _stats?.normalizedBlocked,
                    ),
                  ],
                ),
              ),
              const SectionLabel('服务信息'),
              InfoTile(
                icon: Icons.dns_outlined,
                title: 'DNS 服务',
                value: '${_status!.dnsAddresses.join('、')}:${_status!.dnsPort}',
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.cloud_outlined,
                title: '上游 DNS',
                value: _upstreams.isEmpty ? '未读取到' : _upstreams.join('\n'),
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.memory_outlined,
                title: 'AdGuard Home',
                value: '版本 ${_status!.version} · 管理端口 ${_status!.httpPort}',
              ),
              const SectionLabel('状态信息'),
              _SwitchRow(
                icon: Icons.filter_alt_outlined,
                title: '规则过滤',
                value: _status!.protectionEnabled,
              ),
              const SizedBox(height: 10),
              _AsyncSwitchRow(
                icon: Icons.travel_explore_outlined,
                title: '安全浏览',
                loader: () => appState.api.safebrowsingStatus(),
                setter: (v) => appState.api.setSafebrowsing(v),
              ),
              const SizedBox(height: 10),
              _AsyncSwitchRow(
                icon: Icons.family_restroom_outlined,
                title: '家长控制',
                loader: () => appState.api.parentalStatus(),
                setter: (v) async => throw AghException('家长控制请到 Web 面板修改'),
                readOnly: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _avgMs => (_stats?.avgProcessingMs ?? 0).toStringAsFixed(1);

  String get _blockRate {
    final st = _stats;
    if (st == null || st.sumQueries == 0) return '拦截率 —';
    final r = st.sumBlocked / st.sumQueries * 100;
    return '拦截率 ${r.toStringAsFixed(2)}%';
  }

  String _fmt(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(2)} 亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(2)} 万';
    return '$n';
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  const _SwitchRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KsuCard(
      child: Row(
        children: [
          Icon(icon, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value ? '开启' : '关闭',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: value ? scheme.primary : scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// 需要额外读接口的开关行
class _AsyncSwitchRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final Future<bool> Function() loader;
  final Future<void> Function(bool) setter;
  final bool readOnly;

  const _AsyncSwitchRow({
    required this.icon,
    required this.title,
    required this.loader,
    required this.setter,
    this.readOnly = false,
  });

  @override
  State<_AsyncSwitchRow> createState() => _AsyncSwitchRowState();
}

class _AsyncSwitchRowState extends State<_AsyncSwitchRow> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await widget.loader();
      if (mounted) setState(() => _value = v);
    } catch (_) {
      if (mounted) setState(() => _value = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = _value;
    return KsuCard(
      child: Row(
        children: [
          Icon(widget.icon, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (v == null)
            Text('—', style: TextStyle(color: scheme.onSurfaceVariant))
          else
            Switch(
              value: v,
              onChanged: widget.readOnly
                  ? null
                  : (n) async {
                      try {
                        await widget.setter(n);
                        setState(() => _value = n);
                      } on AghException catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
            ),
        ],
      ),
    );
  }
}
