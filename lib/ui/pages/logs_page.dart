import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

enum _Filter { all, blocked, allowed, grouped }

class _LogsPageState extends State<LogsPage> {
  final _search = TextEditingController();
  List<QueryLogEntry> _all = const [];
  Map<int, String> _filterNames = const {};
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final api = appState.api;
      final list = await api.queryLog(limit: 300, search: _search.text.trim());
      final st = await api.filteringStatus();
      if (!mounted) return;
      setState(() {
        _all = list;
        _filterNames = {
          for (final f in [...st.filters, ...st.whitelist]) f.id: f.name,
        };
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

  List<QueryLogEntry> get _visible {
    switch (_filter) {
      case _Filter.blocked:
        return _all.where((e) => e.blocked).toList();
      case _Filter.allowed:
        return _all.where((e) => !e.blocked).toList();
      case _Filter.grouped:
        final seen = <String>{};
        return _all.where((e) => seen.add(e.domain)).toList();
      case _Filter.all:
        return _all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _visible;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
            child: KsuHeader(
              title: '日志',
              actions: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
                IconButton(
                  onPressed: () async {
                    try {
                      await appState.api.clearQueryLog();
                      await _load();
                    } on AghException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: '清空日志',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: '搜索域名、客户端',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('全部', _Filter.all),
                const SizedBox(width: 8),
                _chip('已拦截', _Filter.blocked),
                const SizedBox(width: 8),
                _chip('已放行', _Filter.allowed),
                const SizedBox(width: 8),
                _chip('聚合重复', _Filter.grouped),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _error != null
                ? EmptyBox(_error!, icon: Icons.error_outline)
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? const EmptyBox('没有查询记录')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _LogTile(
                                entry: list[i],
                                filterName: _nameFor(list[i]),
                                onTap: () => _showDetail(list[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _nameFor(QueryLogEntry e) {
    if (e.rules.isEmpty) return '';
    final id = e.rules.first.filterId;
    return _filterNames[id] ?? '规则 $id';
  }

  Widget _chip(String label, _Filter f) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _filter == f;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = f),
      showCheckmark: selected,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
      selectedColor: scheme.primary.withOpacity(0.22),
      backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  void _showDetail(QueryLogEntry e) {
    final scheme = Theme.of(context).colorScheme;
    final name = _nameFor(e);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.domain,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text(
              '状态：${e.stateLabel}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: e.blocked ? scheme.error : scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text('${e.reasonLabel}（${e.reason}）· ${e.elapsedMs.toStringAsFixed(1)} ms',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
            if (e.client.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('客户端：${e.client}${e.cached ? ' · 命中缓存' : ''}',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            if (e.answer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('应答：${e.answer}',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(name,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary)),
              ),
              const SizedBox(height: 8),
              for (final r in e.rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(r.text,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant)),
                ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.domain));
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(const SnackBar(content: Text('已复制域名')));
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('复制到剪贴板'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        if (e.blocked) {
                          await appState.api.allowDomain(e.domain);
                        } else {
                          await appState.api.blockDomain(e.domain);
                        }
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.blocked ? '已放行 ${e.domain}' : '已拦截 ${e.domain}')),
                        );
                      } on AghException catch (err) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err.message)));
                      }
                    },
                    icon: Icon(e.blocked ? Icons.check : Icons.block),
                    label: Text(e.blocked ? '放行域名' : '拦截域名'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final QueryLogEntry entry;
  final String filterName;
  final VoidCallback onTap;

  const _LogTile({required this.entry, required this.filterName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = entry.blocked ? scheme.error : scheme.primary;
    final icon = entry.blocked
        ? Icons.shield
        : (entry.whitelisted ? Icons.verified_user : Icons.check_circle_outline);

    return KsuCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.domain.isEmpty ? '（无域名）' : entry.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_time(entry.time),
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(entry.qtype.isEmpty ? 'A' : entry.qtype,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        filterName.isEmpty
                            ? '${entry.reasonLabel} · ${entry.elapsedMs.toStringAsFixed(1)}ms'
                            : '$filterName · ${entry.reasonLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(entry.stateLabel,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(entry.reasonLabel,
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}
