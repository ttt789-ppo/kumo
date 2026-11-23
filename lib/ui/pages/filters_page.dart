import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';

class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key});

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  List<FilterEntry> _filters = const [];
  List<String> _userRules = const [];
  int _interval = 24;
  bool _loading = true;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _filters.isEmpty;
      _error = null;
    });
    try {
      final r = await appState.api.filteringStatus();
      if (!mounted) return;
      setState(() {
        _filters = r.filters;
        _userRules = r.userRules;
        _interval = r.interval;
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

  int get _totalRules => _filters.fold(0, (a, b) => a + b.rulesCount);

  Future<void> _toggle(FilterEntry f, bool on) async {
    try {
      await appState.api.setFilterEnabled(f, on);
      setState(() {
        final i = _filters.indexWhere((e) => e.url == f.url);
        if (i >= 0) _filters[i] = FilterEntry(
          url: f.url,
          name: f.name,
          rulesCount: f.rulesCount,
          enabled: on,
        );
      });
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _refreshing = true);
    try {
      await appState.api.refreshFilters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已开始更新订阅')));
      await Future.delayed(const Duration(seconds: 2));
      await _load();
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _addFilter() async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(hintText: '规则地址（http/https）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: '名称'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.api.addFilter(urlCtrl.text.trim(), nameCtrl.text.trim());
      await _load();
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editRules() async {
    final ctrl = TextEditingController(text: _userRules.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义规则'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(hintText: '||example.com^\n@@||allow.com^'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final rules = ctrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      await appState.api.setUserRules(rules);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('规则已保存')));
    } on AghException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
          children: [
            KsuHeader(
              title: '过滤器',
              actions: [
                IconButton(
                  onPressed: _refreshing ? null : _refreshAll,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  tooltip: '更新全部',
                ),
                IconButton(onPressed: _addFilter, icon: const Icon(Icons.add)),
              ],
            ),
            StatusBanner(
              title: '${_filters.where((e) => e.enabled).length} 条订阅生效',
              badge: '${(_totalRules / 10000).toStringAsFixed(1)} 万条',
              subtitle: '更新间隔 $_interval 小时 · 自定义规则 ${_userRules.length} 条',
              ok: true,
              icon: Icons.layers_outlined,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: KsuCard(
                  color: scheme.errorContainer,
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            const SectionLabel('订阅列表'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final f in _filters) ...[
              KsuCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name.isEmpty ? f.url : f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${f.rulesCount} 条 · ${f.lastUpdated.isEmpty ? '未更新' : f.lastUpdated.substring(0, 10)}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: f.enabled, onChanged: (v) => _toggle(f, v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SectionLabel('自定义规则'),
            KsuCard(
              onTap: _editRules,
              child: Row(
                children: [
                  Icon(Icons.code, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  const Text('编辑自定义规则', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${_userRules.length} 条',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
