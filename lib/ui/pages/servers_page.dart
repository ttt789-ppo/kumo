import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../theme.dart';
import '../widgets.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  ServerConfig? _editing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = appState.store.servers;

    if (_editing != null) {
      return _ServerForm(
        initial: _editing!,
        onDone: () {
          setState(() => _editing = null);
        },
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
        children: [
          KsuHeader(
            title: 'Kumo',
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '添加服务器',
                onPressed: () => setState(() => _editing = ServerConfig(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: 'AdGuard Home',
                      host: '127.0.0.1',
                      port: 3000,
                      user: 'admin',
                    )),
              ),
            ],
          ),
          StatusBanner(
            title: '未连接',
            badge: 'Kumo',
            subtitle: '填 AdGuard Home 的管理地址、账号密码即可接管',
            ok: false,
            icon: Icons.link_off,
            onTap: () => setState(() => _editing = ServerConfig(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: 'AdGuard Home',
                  host: '127.0.0.1',
                  port: 3000,
                  user: 'admin',
                )),
          ),
          const SectionLabel('已保存的服务器'),
          if (list.isEmpty)
            const EmptyBox('还没有保存的服务器', icon: Icons.dns_outlined),
          for (final s in list) ...[
            KsuCard(
              onTap: () async {
                await appState.store.setActive(s);
              },
              child: Row(
                children: [
                  Icon(Icons.dns_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          s.label,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = s.copy()),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除服务器'),
                          content: Text('删除「${s.name}」？'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('删除')),
                          ],
                        ),
                      );
                      if (ok == true) await appState.store.remove(s);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          KsuCard(
            onTap: () => setState(() => _editing = ServerConfig(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: 'AdGuard Home',
                  host: '127.0.0.1',
                  port: 3000,
                  user: 'admin',
                )),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: scheme.primary),
                const SizedBox(width: 14),
                Text('添加服务器',
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerForm extends StatefulWidget {
  final ServerConfig initial;
  final VoidCallback onDone;
  const _ServerForm({required this.initial, required this.onDone});

  @override
  State<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _path;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late String _scheme;
  bool _testing = false;
  bool _saving = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c.name);
    _host = TextEditingController(text: c.host);
    _port = TextEditingController(text: '${c.port}');
    _path = TextEditingController(text: c.path);
    _user = TextEditingController(text: c.user);
    _password = TextEditingController(text: c.password);
    _scheme = c.scheme;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _path.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  ServerConfig _build() => ServerConfig(
        id: widget.initial.id,
        name: _name.text.trim().isEmpty ? 'AdGuard Home' : _name.text.trim(),
        scheme: _scheme,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 3000,
        path: _path.text.trim(),
        user: _user.text.trim(),
        password: _password.text,
      );

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      final api = AghClient.fromConfig(_build());
      final s = await api.ping();
      api.close();
      if (!mounted) return;
      setState(() {
        _ok = true;
        _message = '连接成功 · AdGuard Home ${s.version} · 保护${s.protectionEnabled ? '开启' : '暂停'}';
      });
    } on AghException catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _message = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = _build();
      await appState.store.upsert(cfg);
      await appState.store.setActive(cfg);
      if (!mounted) return;
      widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onDone,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              const Text('连接服务器', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),
          KsuCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'http', label: Text('http')),
                    ButtonSegment(value: 'https', label: Text('https')),
                  ],
                  selected: {_scheme},
                  onSelectionChanged: (v) => setState(() => _scheme = v.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _host,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: '地址'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '端口'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _path,
                  decoration: const InputDecoration(
                    labelText: '路径（可选）',
                    hintText: '/agh',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_message != null)
            KsuCard(
              color: _ok ? scheme.primaryContainer : scheme.errorContainer,
              child: Row(
                children: [
                  Icon(_ok ? Icons.check_circle_outline : Icons.error_outline,
                      color: _ok ? scheme.onPrimaryContainer : scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('保存并连接'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
