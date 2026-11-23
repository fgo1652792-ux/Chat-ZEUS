import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_repository.dart';
import '../design.dart';
import '../providers/credentials.dart';
import 'hub_client.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.history,
    required this.credentials,
  });

  final ChatRepository history;
  final Credentials credentials;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final _endpoint = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _when = TextEditingController(
    text: DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String(),
  );
  HubClient? _hub;
  bool _remember = false;
  bool _busy = false;
  String? _feedback;
  String? _selectedId;
  List<ChatThread> _local = [];
  List<Map<String, dynamic>> _remote = [];
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocal());
  }

  Future<void> _loadLocal() async {
    final list = await widget.history.list();
    final prefs = await widget.history.store.preferences();
    if (mounted) {
      setState(() {
        _local = list;
        _endpoint.text = prefs['hub_endpoint'] ?? _endpoint.text;
        _email.text = prefs['hub_email'] ?? _email.text;
      });
    }
  }

  @override
  void dispose() {
    _hub?.close();
    _password.clear();
    _invite.clear();
    for (final field in [_endpoint, _email, _password, _invite, _when]) {
      field.dispose();
    }
    super.dispose();
  }

  String _profileKey(Uri endpoint) =>
      'hub:${endpoint.toString()}:${_email.text.toLowerCase().trim()}';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await action();
    } on HubException catch (error) {
      if (mounted)
        setState(
          () => _feedback = localize(
            context,
            'Hub returned HTTP ${error.status}.',
            'أعاد الخادم حالة HTTP ${error.status}.',
          ),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _feedback = localize(
            context,
            'Check the Hub URL and connection settings.',
            'تحقق من عنوان الخادم وإعدادات الاتصال.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn({required bool restore}) async {
    final endpoint = HubClient.endpoint(_endpoint.text);
    final hub = HubClient(endpoint);
    try {
      if (restore) {
        final token = await widget.credentials.read(_profileKey(endpoint));
        if (token == null) {
          if (mounted)
            setState(
              () => _feedback = localize(
                context,
                'No saved session for this account.',
                'لا توجد جلسة محفوظة لهذا الحساب.',
              ),
            );
          return;
        }
        await hub.restore(token);
      } else {
        await hub.login(
          _email.text.trim(),
          _password.text,
          _invite.text.trim(),
        );
      }
      if (!mounted) return;
      _password.clear();
      _invite.clear();
      _remember = _remember || restore;
      if (_remember) {
        await widget.credentials.write(
          _profileKey(endpoint),
          hub.refreshToken!,
        );
        await widget.history.store.setPreference(
          'hub_endpoint',
          endpoint.toString(),
        );
        await widget.history.store.setPreference(
          'hub_email',
          _email.text.trim(),
        );
      }
      if (!mounted) return;
      _hub?.close();
      setState(() => _hub = hub);
      await _refresh();
    } finally {
      if (_hub != hub) hub.close();
    }
  }

  Future<void> _refresh() async {
    final hub = _hub!;
    final remote = await hub.request('POST', 'sync/batch', data: {});
    final jobList = await hub.request('GET', 'jobs');
    if (_remember)
      await widget.credentials.write(_profileKey(hub.base), hub.refreshToken!);
    if (mounted) {
      setState(() {
        _remote = (remote['changes'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where(
              (record) =>
                  record['kind'] == 'conversation' && record['deleted'] != true,
            )
            .toList();
        _jobs = (jobList['jobs'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    }
  }

  Future<void> _upload() async {
    final id = _selectedId!;
    final thread = await widget.history.get(id);
    final messages = await widget.history.messages(id);
    final prior = _remote.where((record) => record['id'] == id).firstOrNull;
    final response = await _hub!.request(
      'POST',
      'sync/batch',
      data: {
        'changes': [
          {
            'kind': 'conversation',
            'id': id,
            'version': prior?['version'] ?? 0,
            'body': {
              'title': thread.title,
              'messages': [
                for (final m in messages) {'role': m.role, 'content': m.text},
              ],
            },
          },
        ],
      },
    );
    if (mounted) {
      setState(
        () => _feedback = (response['conflicts'] as List).isEmpty
            ? localize(context, 'Conversation uploaded.', 'رُفعت المحادثة.')
            : localize(
                context,
                'The remote conversation changed. Refresh and compare before uploading again.',
                'تغيّرت المحادثة على الخادم. حدّث وقارن قبل الرفع مجددًا.',
              ),
      );
    }
    await _refresh();
  }

  Future<void> _import(Map<String, dynamic> record) async {
    final data = record['body'] as Map<String, dynamic>;
    final notes = (data['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    await widget.history.store.db.transaction((db) async {
      final id = record['id'] as String;
      final local = await db.query(
        'conversations',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (local.isNotEmpty) {
        if (mounted) {
          setState(
            () => _feedback = localize(
              context,
              'This conversation already exists locally. Export before replacing it.',
              'هذه المحادثة موجودة محليًا. صدّرها قبل استبدالها.',
            ),
          );
        }
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('conversations', {
        'id': id,
        'title': data['title'],
        'created_at': now,
        'updated_at': now,
      });
      final batch = db.batch();
      for (final (index, message) in notes.indexed) {
        batch.insert('messages', {
          'id': '$id:hub:$index',
          'conversation_id': id,
          'ordinal': index + 1,
          'role': message['role'],
          'content': message['content'],
          'status': 'completed',
          'created_at': now,
        });
      }
      await batch.commit(noResult: true);
      if (mounted)
        setState(
          () => _feedback = localize(
            context,
            'Conversation imported locally.',
            'استُوردت المحادثة محليًا.',
          ),
        );
    });
    await _loadLocal();
  }

  Future<void> _schedule() async {
    final due = DateTime.parse(_when.text).toUtc().toIso8601String();
    await _hub!.request(
      'POST',
      'jobs',
      data: {'kind': 'workspace_summary', 'runAt': due},
    );
    await _refresh();
  }

  Future<void> _results(String id) async {
    final result = await _hub!.request('GET', 'jobs/$id/runs');
    if (!mounted) return;
    final runs = (result['runs'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localize(context, 'Job results', 'نتائج المهمة')),
        content: SingleChildScrollView(
          child: SelectableText(
            runs.isEmpty
                ? localize(context, 'No runs yet.', 'لا توجد عمليات تشغيل بعد.')
                : runs
                      .map((r) => '${r['completed_at']}\n${r['result']}')
                      .join('\n\n'),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final hub = _hub!;
    await hub.request(
      'POST',
      'auth/logout',
      useAuth: false,
      data: {'refreshToken': hub.refreshToken},
    );
    await widget.credentials.delete(_profileKey(hub.base));
    hub.close();
    if (mounted) {
      setState(() {
        _hub = null;
        _remote = [];
        _jobs = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zeus Hub')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_hub == null) ...[
              TextField(
                controller: _endpoint,
                enabled: !_busy,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: localize(
                    context,
                    'Hub HTTPS URL',
                    'عنوان الخادم HTTPS',
                  ),
                ),
              ),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: localize(context, 'Email', 'البريد الإلكتروني'),
                ),
              ),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: localize(context, 'Password', 'كلمة المرور'),
                ),
              ),
              TextField(
                controller: _invite,
                enabled: !_busy,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: localize(
                    context,
                    'Invite code for new accounts',
                    'رمز دعوة الحساب الجديد',
                  ),
                ),
              ),
              CheckboxListTile(
                value: _remember,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _remember = value!),
                title: Text(
                  localize(
                    context,
                    'Remember this session',
                    'تذكّر هذه الجلسة',
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _signIn(restore: false)),
                    child: Text(localize(context, 'Connect', 'اتصال')),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _signIn(restore: true)),
                    child: Text(
                      localize(context, 'Restore session', 'استعادة الجلسة'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                localize(
                  context,
                  'Selected conversation content is sent to this Hub.',
                  'يُرسل محتوى المحادثة المحددة إلى هذا الخادم.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _run(_refresh),
                    child: Text(localize(context, 'Refresh', 'تحديث')),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _run(_logout),
                    child: Text(localize(context, 'Log out', 'تسجيل الخروج')),
                  ),
                ],
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _local.any((thread) => thread.id == _selectedId)
                    ? _selectedId
                    : null,
                hint: Text(
                  localize(
                    context,
                    'Select a local conversation',
                    'اختر محادثة محلية',
                  ),
                ),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _selectedId = value),
                items: [
                  for (final thread in _local)
                    DropdownMenuItem(
                      value: thread.id,
                      child: Text(thread.title),
                    ),
                ],
              ),
              FilledButton(
                onPressed: _busy || _selectedId == null
                    ? null
                    : () => _run(_upload),
                child: Text(
                  localize(
                    context,
                    'Upload selected conversation',
                    'رفع المحادثة المحددة',
                  ),
                ),
              ),
              for (final record in _remote)
                ListTile(
                  title: Text(record['body']['title'] as String),
                  trailing: IconButton(
                    onPressed: _busy ? null : () => _run(() => _import(record)),
                    tooltip: localize(
                      context,
                      'Import conversation',
                      'استيراد المحادثة',
                    ),
                    icon: const Icon(Icons.download),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                localize(
                  context,
                  'Scheduled workspace summaries',
                  'ملخصات مساحة العمل المجدولة',
                ),
              ),
              TextField(
                controller: _when,
                enabled: !_busy,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: localize(
                    context,
                    'Run at in ISO 8601 (UTC)',
                    'موعد التشغيل بصيغة ISO 8601 ‏(UTC)',
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run(_schedule),
                child: Text(
                  localize(context, 'Schedule summary', 'جدولة ملخّص'),
                ),
              ),
              for (final job in _jobs)
                ListTile(
                  title: Text(job['state'] as String),
                  subtitle: Text(job['next_run_at'] as String),
                  onTap: _busy
                      ? null
                      : () => _run(() => _results(job['id'] as String)),
                  trailing: ['queued', 'running'].contains(job['state'])
                      ? IconButton(
                          tooltip: localize(
                            context,
                            'Cancel job',
                            'إلغاء المهمة',
                          ),
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await _hub!.request(
                                    'POST',
                                    'jobs/${job['id']}/cancel',
                                  );
                                  await _refresh();
                                }),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : null,
                ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_feedback case final message?) Text(message),
          ],
        ),
      ),
    ),
  );
}
