import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';

/// 订阅规则详情（对应参考 App 的「订阅规则详情」页）
class FilterDetailPage extends StatefulWidget {
  final FilterEntry entry;
  const FilterDetailPage({super.key, required this.entry});

  @override
  State<FilterDetailPage> createState() => _FilterDetailPageState();
}

class _FilterDetailPageState extends State<FilterDetailPage> {
  late FilterEntry _entry = widget.entry;
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      await appState.api.setFilterEnabled(_entry, on);
      setState(() => _entry = FilterEntry(
            id: _entry.id,
            url: _entry.url,
            name: _entry.name,
            rulesCount: _entry.rulesCount,
            enabled: on,
            whitelist: _entry.whitelist,
            lastUpdated: _entry.lastUpdated,
          ));
    } on AghException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final nameCtrl = TextEditingController(text: _entry.name);
    final urlCtrl = TextEditingController(text: _entry.url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'URL'),
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
      await appState.api.updateFilter(_entry, name: nameCtrl.text.trim(), url: urlCtrl.text.trim());
      setState(() => _entry = FilterEntry(
            id: _entry.id,
            url: urlCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            rulesCount: _entry.rulesCount,
            enabled: _entry.enabled,
            whitelist: _entry.whitelist,
            lastUpdated: _entry.lastUpdated,
          ));
      _toast('已保存');
    } on AghException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('删除「${_entry.name}」？该操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.api.removeFilter(_entry);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AghException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await appState.api.refreshFilters();
      _toast('已开始更新订阅');
    } on AghException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅规则详情'),
        actions: [
          IconButton(onPressed: _busy ? null : _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: _busy ? null : _delete,
            icon: Icon(Icons.delete_outline, color: scheme.error),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _refresh,
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _Row(
            icon: Icons.shield_outlined,
            label: '当前状态',
            child: Row(
              children: [
                Text(
                  _entry.enabled ? '已启用' : '已停用',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _entry.enabled ? scheme.primary : scheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: _entry.enabled, onChanged: _busy ? null : _toggle),
              ],
            ),
          ),
          _Row(icon: Icons.label_outline, label: '名称', child: Text(_entry.name, style: _valueStyle)),
          _Row(
            icon: Icons.link,
            label: 'URL',
            child: Row(
              children: [
                Expanded(child: Text(_entry.url, style: _valueStyle)),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _entry.url));
                    _toast('已复制 URL');
                  },
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
          ),
          _Row(
            icon: Icons.format_list_bulleted,
            label: '规则',
            child: Text('${_entry.rulesCount}', style: _valueStyle),
          ),
          _Row(
            icon: Icons.shield_moon_outlined,
            label: '订阅规则类型',
            child: Text(_entry.whitelist ? '白名单' : '黑名单', style: _valueStyle),
          ),
          _Row(
            icon: Icons.access_time,
            label: '最近更新',
            child: Text(_fmtDate(_entry.lastUpdated), style: _valueStyle),
          ),
        ],
      ),
    );
  }

  TextStyle get _valueStyle => TextStyle(
        fontSize: 14.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      );

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '未更新';
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}-${two(l.month)}-${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _Row({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
