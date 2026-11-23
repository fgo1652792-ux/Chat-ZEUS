import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../design.dart';
import '../providers/provider_protocol.dart';
import '../providers/provider_settings.dart';
import 'chat_repository.dart';
import 'chat_runtime.dart';

enum HistoryFilter { current, archive, trash }

class ChatWorkspace extends StatefulWidget {
  const ChatWorkspace({
    super.key,
    required this.runtime,
    required this.onProviders,
  });
  final ChatRuntime runtime;
  final VoidCallback onProviders;

  @override
  State<ChatWorkspace> createState() => _ChatWorkspaceState();
}

class _ChatWorkspaceState extends State<ChatWorkspace> {
  final _draft = TextEditingController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _composeFocus = FocusNode();
  final _historyRevision = ValueNotifier(0);
  List<ChatThread> _threads = const [];
  List<ChatMessage> _messages = const [];
  ChatThread? _thread;
  HistoryFilter _filter = HistoryFilter.current;
  Timer? _saveDraftTimer;
  Timer? _searchTimer;
  bool _loading = true;
  bool _failed = false;
  int _selection = 0;
  int _listQuery = 0;
  ChatRepository get _repo => widget.runtime.repository;

  @override
  void initState() {
    super.initState();
    widget.runtime.addListener(_runtimeChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (mounted) setState(() => _failed = false);
    try {
      final pref = await _repo.store.preferences();
      await _refresh();
      if (!mounted) return;
      final id = pref['active_thread'];
      for (final thread in _threads) {
        if (thread.id == id) {
          await _open(thread, savePreference: false);
          break;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final query = ++_listQuery;
    final threads = await _repo.list(
      archived: _filter == HistoryFilter.archive,
      deleted: _filter == HistoryFilter.trash,
      search: _search.text,
    );
    if (mounted && query == _listQuery) {
      setState(() => _threads = threads);
      _historyRevision.value++;
    }
  }

  void _runtimeChanged() {
    if (mounted) {
      setState(() {});
      _toBottom(onlyIfNear: true);
    }
  }

  void _toBottom({bool onlyIfNear = false}) {
    if (onlyIfNear &&
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.offset > 180) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    widget.runtime.removeListener(_runtimeChanged);
    _saveDraftTimer?.cancel();
    _searchTimer?.cancel();
    _draft.dispose();
    _search.dispose();
    _scroll.dispose();
    _composeFocus.dispose();
    _historyRevision.dispose();
    super.dispose();
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localize(
            context,
            'The operation failed. Try again.',
            'تعذرت العملية. أعد المحاولة.',
          ),
        ),
      ),
    );
  }

  Future<void> _flushDraft() async {
    final pending = _saveDraftTimer;
    if (pending?.isActive != true || _thread == null) return;
    pending!.cancel();
    await _repo.setDraft(_thread!.id, _draft.text);
  }

  void _saveDraft(String text) {
    final thread = _thread;
    if (thread == null) return;
    _saveDraftTimer?.cancel();
    _saveDraftTimer = Timer(const Duration(milliseconds: 150), () async {
      try {
        await _repo.setDraft(thread.id, text);
      } catch (_) {
        _showError();
      }
    });
  }

  Future<void> _open(ChatThread thread, {bool savePreference = true}) async {
    final selection = ++_selection;
    try {
      await _flushDraft();
      final messages = await _repo.messages(thread.id);
      if (!mounted || selection != _selection) return;
      setState(() {
        _thread = thread;
        _draft.text = thread.draft;
        _messages = messages;
      });
      if (savePreference) {
        await _repo.store.setPreference('active_thread', thread.id);
      }
      _toBottom();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _create() async {
    final title = localize(context, 'New conversation', 'محادثة جديدة');
    try {
      final providers = await widget.runtime.providers.list();
      final previous = _thread;
      final preferred =
          providers
              .where((provider) => provider.id == previous?.providerId)
              .firstOrNull ??
          providers
              .where((provider) => provider.manualModel.isNotEmpty)
              .firstOrNull;
      final defaultModel = preferred?.id == previous?.providerId
          ? previous?.modelId
          : preferred?.manualModel;
      final thread = await _repo.create(
        title,
        providerId: preferred?.id,
        modelId: defaultModel,
      );
      await _refresh();
      await _open(thread);
    } catch (_) {
      _showError();
    }
  }

  Future<void> _chooseModel() async {
    final thread = _thread;
    if (thread == null) return;
    final connections = await widget.runtime.providers.list();
    if (!mounted) return;
    if (connections.isEmpty) {
      widget.onProviders();
      return;
    }
    final selection = await showDialog<(ProviderConnection, String)>(
      context: context,
      builder: (context) => _ChatModelDialog(
        connections: connections,
        current: thread,
        runtime: widget.runtime,
      ),
    );
    if (selection == null || !mounted || _thread?.id != thread.id) return;
    final (provider, model) = selection;
    if (thread.providerId != null &&
        thread.providerId != provider.id &&
        _messages.isNotEmpty) {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localize(context, 'Change provider?', 'تغيير المزوّد؟')),
          content: Text(
            localize(
              context,
              'Future requests will share this conversation with ${provider.label}.',
              'ستُرسل المحادثة مع الطلبات القادمة إلى ${provider.label}.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localize(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                localize(context, 'Change provider', 'تغيير المزوّد'),
              ),
            ),
          ],
        ),
      );
      if (allowed != true) return;
    }
    try {
      await _repo.setModel(thread.id, provider.id, model);
      final updated = await _repo.get(thread.id);
      if (mounted && _thread?.id == thread.id) {
        setState(() => _thread = updated);
      }
    } catch (_) {
      _showError();
    }
  }

  Future<void> _send({bool retry = false}) async {
    final thread = _thread;
    final prompt = _draft.text.trim();
    if (thread == null ||
        (prompt.isEmpty && !retry) ||
        widget.runtime.active(thread.id) != null) {
      return;
    }
    if (thread.providerId == null || thread.modelId == null) {
      await _chooseModel();
      return;
    }
    try {
      final connections = await widget.runtime.providers.list();
      final candidates = connections.where(
        (provider) => provider.id == thread.providerId,
      );
      if (!mounted || _thread?.id != thread.id) return;
      if (candidates.isEmpty) {
        await _chooseModel();
        return;
      }
      if (!retry) {
        _saveDraftTimer?.cancel();
        _draft.clear();
      }
      if (!retry && _messages.isEmpty) {
        final title = String.fromCharCodes(prompt.runes.take(56));
        await _repo.rename(thread.id, title);
      }
      await widget.runtime.send(
        thread,
        candidates.first,
        thread.modelId!,
        retry ? null : prompt,
      );
      if (!mounted) return;
      final updated = await _repo.get(thread.id);
      final messages = await _repo.messages(thread.id);
      if (mounted && _thread?.id == thread.id) {
        setState(() {
          _thread = updated;
          _messages = messages;
        });
        _toBottom();
      }
      await _refresh();
    } catch (_) {
      if (mounted && _thread?.id == thread.id && _draft.text.isEmpty) {
        _draft.text = prompt;
        _saveDraft(prompt);
      }
      _showError();
    }
  }

  Future<String?> _askText(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            controller: controller,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localize(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(localize(context, 'Save', 'حفظ')),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _threadAction(ChatThread thread, String action) async {
    try {
      switch (action) {
        case 'rename':
          final title = await _askText(
            localize(context, 'Rename conversation', 'إعادة تسمية المحادثة'),
            thread.title,
          );
          if (title == null || title.isEmpty) return;
          await _repo.rename(thread.id, title);
        case 'pin':
          await _repo.pin(thread.id, !thread.pinned);
        case 'archive':
          await _repo.archive(thread.id, !thread.archived);
        case 'trash':
          await _repo.trash(thread.id, !thread.deleted);
        case 'copy':
        case 'share':
          final messages = await _repo.messages(thread.id);
          final transcript = messages
              .map((m) => '**${m.role}**\n\n${m.text}')
              .join('\n\n---\n\n');
          final markdown = '# ${thread.title}\n\n$transcript';
          if (action == 'copy') {
            await Clipboard.setData(ClipboardData(text: markdown));
          } else if (mounted) {
            final window = context.findRenderObject() as RenderBox;
            final origin = window.localToGlobal(Offset.zero) & window.size;
            await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(
                    utf8.encode(markdown),
                    mimeType: 'text/markdown',
                  ),
                ],
                fileNameOverrides: ['ZeusChat-${thread.id.substring(0, 8)}.md'],
                sharePositionOrigin: origin,
              ),
            );
          }
          return;
      }
      if (mounted && thread.id == _thread?.id) {
        final latest = await _repo.get(thread.id);
        if (mounted) setState(() => _thread = latest.deleted ? null : latest);
      }
      await _refresh();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _fork(
    ChatThread thread,
    ChatMessage anchor, {
    bool edit = false,
  }) async {
    final title = '${thread.title} · ${localize(context, 'Branch', 'فرع')}';
    try {
      final edited = edit
          ? await _askText(
              localize(context, 'Edit and branch', 'تعديل وتفريع'),
              anchor.text,
            )
          : null;
      if (edit && (edited == null || edited.isEmpty)) return;
      final branch = await _repo.fork(
        thread,
        anchor,
        title,
        editedText: edited,
      );
      await _refresh();
      await _open(branch);
    } catch (_) {
      _showError();
    }
  }

  void _changeFilter(HistoryFilter value) {
    setState(() => _filter = value);
    unawaited(_refresh().catchError((Object _) => _showError()));
  }

  Widget _history(BuildContext context, {VoidCallback? dismiss}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: FilledButton.icon(
            onPressed: () {
              dismiss?.call();
              unawaited(_create());
            },
            icon: const Icon(Icons.add),
            label: Text(localize(context, 'New conversation', 'محادثة جديدة')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: localize(context, 'Search history', 'بحث في السجل'),
            ),
            onChanged: (_) {
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 150), () {
                unawaited(_refresh().catchError((Object _) => _showError()));
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 18, end: 12),
          child: DropdownButton<HistoryFilter>(
            value: _filter,
            isExpanded: true,
            onChanged: (value) => _changeFilter(value!),
            items: [
              DropdownMenuItem(
                value: HistoryFilter.current,
                child: Text(localize(context, 'Conversations', 'المحادثات')),
              ),
              DropdownMenuItem(
                value: HistoryFilter.archive,
                child: Text(localize(context, 'Archive', 'الأرشيف')),
              ),
              DropdownMenuItem(
                value: HistoryFilter.trash,
                child: Text(localize(context, 'Trash', 'المحذوفات')),
              ),
            ],
          ),
        ),
        Expanded(
          child: _threads.isEmpty
              ? Center(
                  child: Text(
                    localize(
                      context,
                      'No conversations here',
                      'لا توجد محادثات هنا',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: _threads.length,
                  itemBuilder: (context, i) {
                    final thread = _threads[i];
                    return ListTile(
                      selected: _thread?.id == thread.id,
                      leading: Icon(
                        thread.pinned
                            ? Icons.push_pin_outlined
                            : Icons.chat_bubble_outline,
                        size: 18,
                      ),
                      title: Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: thread.deleted
                          ? null
                          : () {
                              dismiss?.call();
                              unawaited(_open(thread));
                            },
                      trailing: PopupMenuButton<String>(
                        tooltip: localize(
                          context,
                          'Conversation actions',
                          'إجراءات المحادثة',
                        ),
                        onSelected: (action) =>
                            unawaited(_threadAction(thread, action)),
                        itemBuilder: (context) => [
                          if (!thread.deleted) ...[
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(
                                localize(context, 'Rename', 'إعادة تسمية'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(
                                thread.pinned
                                    ? localize(
                                        context,
                                        'Unpin',
                                        'إلغاء التثبيت',
                                      )
                                    : localize(context, 'Pin', 'تثبيت'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(
                                thread.archived
                                    ? localize(
                                        context,
                                        'Unarchive',
                                        'إلغاء الأرشفة',
                                      )
                                    : localize(context, 'Archive', 'أرشفة'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'copy',
                              child: Text(
                                localize(
                                  context,
                                  'Copy transcript',
                                  'نسخ المحادثة',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: Text(
                                localize(
                                  context,
                                  'Export Markdown',
                                  'تصدير Markdown',
                                ),
                              ),
                            ),
                          ],
                          PopupMenuItem(
                            value: 'trash',
                            child: Text(
                              thread.deleted
                                  ? localize(context, 'Restore', 'استعادة')
                                  : localize(
                                      context,
                                      'Move to trash',
                                      'نقل إلى المحذوفات',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showHistory() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: .84,
          child: ValueListenableBuilder(
            valueListenable: _historyRevision,
            builder: (context, _, _) =>
                _history(context, dismiss: () => Navigator.pop(context)),
          ),
        ),
      ),
    );
  }

  Widget _chat(BuildContext context, {required bool wide}) {
    final theme = Theme.of(context);
    final thread = _thread;
    final active = thread == null ? null : widget.runtime.active(thread.id);
    if (thread == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/zeus.png', width: 82, height: 82),
            const SizedBox(height: 18),
            Text(
              localize(context, 'Start a conversation', 'ابدأ محادثة'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _create,
              child: Text(
                localize(context, 'New conversation', 'محادثة جديدة'),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: active == null ? _chooseModel : null,
                icon: const Icon(Icons.tune, size: 17),
                label: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 190 : 122),
                  child: Text(
                    thread.modelId ??
                        localize(context, 'Choose model', 'اختر نموذجًا'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            children: [
              for (final message in _messages)
                _message(context, thread, message),
              if (active?.prompt case final prompt?)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _bubble(context, prompt, user: true),
                ),
              if (active != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _bubble(
                    context,
                    active.text.isEmpty
                        ? localize(
                            context,
                            'Waiting for the model…',
                            'بانتظار النموذج…',
                          )
                        : active.text,
                    user: false,
                    footer: active.summary.isNotEmpty ? active.summary : null,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ZeusPane(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _composeFocus,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _saveDraft,
                      decoration: InputDecoration(
                        hintText: localize(
                          context,
                          'Write a message',
                          'اكتب رسالة',
                        ),
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: active == null
                        ? localize(context, 'Send', 'إرسال')
                        : localize(context, 'Stop', 'إيقاف'),
                    onPressed: active == null
                        ? () => unawaited(_send())
                        : () => widget.runtime.cancel(thread.id),
                    icon: Icon(
                      active == null
                          ? Icons.arrow_upward_rounded
                          : Icons.stop_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _message(
    BuildContext context,
    ChatThread thread,
    ChatMessage message,
  ) {
    final user = message.role == 'user';
    final error = message.error == null
        ? null
        : ProviderErrorCode.values
              .where((value) => value.name == message.error)
              .firstOrNull;
    final status = switch (message.state) {
      MessageState.cancelled => localize(context, 'Stopped', 'تم الإيقاف'),
      MessageState.interrupted => localize(
        context,
        'Interrupted',
        'انقطع الرد',
      ),
      MessageState.failed => localize(context, 'Failed', 'تعذّر الرد'),
      _ => '',
    };
    final footer = [
      if (message.modelId != null) message.modelId!,
      if (status.isNotEmpty) status,
      if (error != null) providerError(context, ProviderException(error)),
      if (message.outputTokens != null)
        localize(
          context,
          '${message.outputTokens} output tokens',
          '${message.outputTokens} رمز إخراج',
        ),
    ].join(' · ');
    return Align(
      alignment: user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: _bubble(
        context,
        message.text,
        user: user,
        footer: footer.isEmpty ? null : footer,
        actions: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, size: 19),
          tooltip: localize(context, 'Message actions', 'إجراءات الرسالة'),
          onSelected: (action) {
            switch (action) {
              case 'copy':
                unawaited(Clipboard.setData(ClipboardData(text: message.text)));
              case 'branch':
                unawaited(_fork(thread, message));
              case 'edit':
                unawaited(_fork(thread, message, edit: true));
              case 'retry':
                unawaited(_send(retry: true));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'copy',
              child: Text(localize(context, 'Copy', 'نسخ')),
            ),
            PopupMenuItem(
              value: 'branch',
              child: Text(
                localize(context, 'Branch from here', 'تفريع من هنا'),
              ),
            ),
            if (user)
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  localize(context, 'Edit and branch', 'تعديل وتفريع'),
                ),
              ),
            if (!user &&
                message.state != MessageState.completed &&
                _messages.lastOrNull?.id == message.id)
              PopupMenuItem(
                value: 'retry',
                child: Text(localize(context, 'Retry', 'إعادة المحاولة')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    String text, {
    required bool user,
    String? footer,
    Widget? actions,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: user ? colors.primaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text.isNotEmpty) SelectableText(text),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                footer,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ?actions,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: _initialize,
          child: Text(
            localize(
              context,
              'Could not load chats. Retry',
              'تعذر تحميل المحادثات. أعد المحاولة',
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 860;
        if (!wide) {
          return Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: localize(context, 'History', 'السجل'),
                  onPressed: _showHistory,
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
              Expanded(child: _chat(context, wide: false)),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 12, 12, 12),
          child: Row(
            children: [
              SizedBox(width: 264, child: ZeusPane(child: _history(context))),
              Expanded(child: _chat(context, wide: true)),
            ],
          ),
        );
      },
    );
  }
}

class _ChatModelDialog extends StatefulWidget {
  const _ChatModelDialog({
    required this.connections,
    required this.current,
    required this.runtime,
  });
  final List<ProviderConnection> connections;
  final ChatThread current;
  final ChatRuntime runtime;

  @override
  State<_ChatModelDialog> createState() => _ChatModelDialogState();
}

class _ChatModelDialogState extends State<_ChatModelDialog> {
  late ProviderConnection _provider =
      widget.connections
          .where((p) => p.id == widget.current.providerId)
          .firstOrNull ??
      widget.connections.first;
  late final _model = TextEditingController(
    text: widget.current.modelId ?? _provider.manualModel,
  );
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final key = await widget.runtime.providers.credentials.read(_provider.id);
      final models = await widget.runtime.client.listModels(_provider, key);
      if (!mounted) return;
      if (models.isEmpty) {
        setState(
          () => _error = localize(
            context,
            'No models returned. Enter a model ID.',
            'لم يرجع المزوّد نماذج. أدخل المعرّف.',
          ),
        );
        return;
      }
      final selected = await showDialog<ModelDescriptor>(
        context: context,
        builder: (context) => ModelPicker(
          models: models,
          repository: widget.runtime.providers,
          providerId: _provider.id,
        ),
      );
      if (mounted && selected != null) _model.text = selected.id;
    } on ProviderException catch (error) {
      if (mounted) setState(() => _error = providerError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'Could not read the API key.',
            'تعذرت قراءة مفتاح API.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(localize(context, 'Conversation model', 'نموذج المحادثة')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ProviderConnection>(
              initialValue: _provider,
              isExpanded: true,
              onChanged: _loading
                  ? null
                  : (value) => setState(() {
                      _provider = value!;
                      _model.text = value.manualModel;
                      _error = null;
                    }),
              items: [
                for (final p in widget.connections)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: localize(context, 'Model ID', 'معرّف النموذج'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            TextButton.icon(
              onPressed: _loading ? null : _discover,
              icon: const Icon(Icons.refresh),
              label: Text(
                localize(context, 'Discover models', 'اكتشاف النماذج'),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error case final error?) Text(error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localize(context, 'Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: _loading || _model.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_provider, _model.text.trim())),
          child: Text(localize(context, 'Use model', 'استخدم النموذج')),
        ),
      ],
    );
  }
}
