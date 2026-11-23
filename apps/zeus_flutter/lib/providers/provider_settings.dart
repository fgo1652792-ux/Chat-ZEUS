import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../design.dart';
import 'provider_client.dart';
import 'provider_protocol.dart';
import 'provider_repository.dart';

String providerError(BuildContext context, ProviderException error) {
  final (en, ar) = switch (error.code) {
    ProviderErrorCode.unauthorized => (
      'Check the API key.',
      'تحقق من مفتاح API.',
    ),
    ProviderErrorCode.forbidden => (
      'This key cannot use the resource.',
      'المفتاح لا يملك صلاحية الوصول.',
    ),
    ProviderErrorCode.notFound => (
      'Check the endpoint and model ID.',
      'تحقق من عنوان الخدمة ومعرّف النموذج.',
    ),
    ProviderErrorCode.rateLimited => (
      'The provider rate limit was reached.',
      'بلغت حد طلبات المزوّد.',
    ),
    ProviderErrorCode.timeout => (
      'The provider took too long to respond.',
      'انتهت مهلة استجابة المزوّد.',
    ),
    ProviderErrorCode.network => (
      'Check your network, endpoint and TLS settings.',
      'تحقق من الشبكة وعنوان الخدمة وإعدادات TLS.',
    ),
    ProviderErrorCode.invalidResponse => (
      'The provider returned an unsupported response.',
      'استجابة المزوّد غير مدعومة.',
    ),
    ProviderErrorCode.rejected => (
      'The provider rejected the request.',
      'رفض المزوّد الطلب.',
    ),
    ProviderErrorCode.unavailable => (
      'The provider is temporarily unavailable.',
      'المزوّد غير متاح مؤقتًا.',
    ),
    ProviderErrorCode.interrupted => (
      'The stream ended before completion.',
      'انقطع البث قبل اكتمال الرد.',
    ),
  };
  final message = localize(context, en, ar);
  final retry = error.retryAfter;
  return retry == null
      ? message
      : '$message ${localize(context, 'Retry after', 'أعد المحاولة بعد')} ${retry.inSeconds}s';
}

class ProviderSettings extends StatefulWidget {
  const ProviderSettings({
    super.key,
    required this.repository,
    this.client = const ProviderClient(),
  });

  final ProviderRepository repository;
  final ProviderClient client;

  @override
  State<ProviderSettings> createState() => _ProviderSettingsState();
}

class _ProviderSettingsState extends State<ProviderSettings> {
  late Future<List<ProviderConnection>> _connections;

  @override
  void initState() {
    super.initState();
    _connections = widget.repository.list();
  }

  void _refresh() => setState(() => _connections = widget.repository.list());

  Future<void> _edit([ProviderConnection? connection]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ProviderEditor(
        initial: connection,
        repository: widget.repository,
        client: widget.client,
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _remove(ProviderConnection connection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localize(context, 'Remove connection?', 'حذف الاتصال؟')),
        content: Text(connection.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localize(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localize(context, 'Remove', 'حذف')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.repository.remove(connection);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localize(
                context,
                'Could not remove the connection.',
                'تعذر حذف الاتصال.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FutureBuilder(
          future: _connections,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    localize(context, 'Connections', 'الاتصالات'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: Text(
                      localize(context, 'Add provider', 'إضافة مزوّد'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    localize(
                      context,
                      'API keys are retained for this browser session.',
                      'تُحفظ مفاتيح API لجلسة المتصفح الحالية.',
                    ),
                  ),
                ),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                TextButton(
                  onPressed: _refresh,
                  child: Text(
                    localize(
                      context,
                      'Could not load connections. Retry',
                      'تعذر تحميل الاتصالات. أعد المحاولة',
                    ),
                  ),
                )
              else if (snapshot.data!.isEmpty)
                Text(
                  localize(
                    context,
                    'Connect a provider or a local model server to start chatting.',
                    'اربط مزوّدًا أو خادم نماذج محليًا لبدء المحادثة.',
                  ),
                )
              else
                for (final connection in snapshot.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ZeusPane(
                      child: ListTile(
                        leading: const Icon(Icons.hub_outlined),
                        title: Text(connection.label),
                        subtitle: Text(
                          connection.endpoint.host,
                          textDirection: TextDirection.ltr,
                        ),
                        onTap: () => _edit(connection),
                        trailing: IconButton(
                          tooltip: localize(
                            context,
                            'Remove connection',
                            'حذف الاتصال',
                          ),
                          onPressed: () => _remove(connection),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({
    required this.initial,
    required this.repository,
    required this.client,
  });

  final ProviderConnection? initial;
  final ProviderRepository repository;
  final ProviderClient client;

  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late ProviderKind _kind = widget.initial?.kind ?? ProviderKind.openai;
  late final _id = widget.initial?.id ?? const Uuid().v4();
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late final _endpoint = TextEditingController(
    text: widget.initial?.endpoint.toString() ?? _kind.defaultEndpoint,
  );
  late final _model = TextEditingController(
    text: widget.initial?.manualModel ?? '',
  );
  final _key = TextEditingController();
  bool _busy = false;
  bool _clearKey = false;
  bool _tested = false;
  String? _error;
  List<ModelDescriptor> _models = const [];

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    _label.dispose();
    _endpoint.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _apply({required bool save}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _busy = true;
      _tested = false;
      _models = const [];
    });
    try {
      final endpoint = ProviderConnection.parseEndpoint(_kind, _endpoint.text);
      final connection = ProviderConnection(
        id: _id,
        kind: _kind,
        endpoint: endpoint,
        label: _label.text.trim().isEmpty ? _kind.label : _label.text.trim(),
        manualModel: _model.text.trim(),
      );
      final existing = widget.initial;
      final reuse =
          existing != null &&
          existing.kind == _kind &&
          existing.endpoint == endpoint &&
          !_clearKey;
      final entered = _key.text.trim();
      final key = entered.isNotEmpty ? entered : (reuse ? null : '');
      if (endpoint.scheme == 'http' &&
          (key?.isNotEmpty ??
              (await widget.repository.credentials.read(_id))?.isNotEmpty ??
              false)) {
        if (mounted) {
          setState(
            () => _error = localize(
              context,
              'Use HTTPS to send an API key.',
              'استخدم HTTPS لإرسال مفتاح API.',
            ),
          );
        }
        return;
      }
      if (save) {
        await widget.repository.save(connection, apiKey: key);
        if (mounted) Navigator.pop(context, true);
      } else {
        final models = await widget.client.listModels(
          connection,
          key ?? await widget.repository.credentials.read(_id),
        );
        if (mounted) {
          setState(() {
            _models = models;
            _tested = true;
          });
        }
      }
    } on ProviderException catch (error) {
      if (mounted) setState(() => _error = providerError(context, error));
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'Enter a valid HTTPS URL or a local HTTP endpoint.',
            'أدخل رابط HTTPS صالحًا أو عنوان HTTP محليًا.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'Could not access secure storage.',
            'تعذر الوصول إلى التخزين الآمن.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(localize(context, 'Provider connection', 'اتصال المزوّد')),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<ProviderKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: localize(context, 'Provider', 'المزوّد'),
                  ),
                  onChanged: _busy || widget.initial != null
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _kind = value;
                            _endpoint.text = value.defaultEndpoint;
                            _models = const [];
                            _tested = false;
                          });
                        },
                  items: [
                    for (final kind in ProviderKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _label,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: localize(
                      context,
                      'Connection name',
                      'اسم الاتصال',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _endpoint,
                  enabled: !_busy && _kind.editableEndpoint,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: localize(context, 'Base URL', 'عنوان الخدمة'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _key,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: widget.initial == null
                        ? localize(context, 'API key', 'مفتاح API')
                        : localize(
                            context,
                            'Replace API key',
                            'استبدال مفتاح API',
                          ),
                  ),
                ),
                if (widget.initial != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      localize(
                        context,
                        'Clear stored key',
                        'حذف المفتاح المخزّن',
                      ),
                    ),
                    value: _clearKey,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _clearKey = value!;
                            if (_clearKey) _key.clear();
                          }),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _model,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: localize(
                      context,
                      'Default model ID',
                      'معرّف النموذج الافتراضي',
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                if (_tested)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      localize(
                        context,
                        'Connected · ${_models.length} models',
                        'تم الاتصال · ${_models.length} نموذج',
                      ),
                    ),
                  ),
                if (_models.isNotEmpty)
                  ListTile(
                    title: Text(
                      localize(
                        context,
                        'Choose a discovered model',
                        'اختر نموذجًا تم اكتشافه',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () async {
                            final choice = await showDialog<ModelDescriptor>(
                              context: context,
                              builder: (context) =>
                                  ModelPicker(models: _models),
                            );
                            if (choice != null && mounted) {
                              _model.text = choice.id;
                            }
                          },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(localize(context, 'Cancel', 'إلغاء')),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => unawaited(_apply(save: false)),
            child: Text(localize(context, 'Test connection', 'اختبار الاتصال')),
          ),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_apply(save: true)),
            child: Text(localize(context, 'Save', 'حفظ')),
          ),
        ],
      ),
    );
  }
}

class ModelPicker extends StatefulWidget {
  const ModelPicker({super.key, required this.models});
  final List<ModelDescriptor> models;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final models = widget.models
        .where(
          (m) =>
              m.id.toLowerCase().contains(_search) ||
              (m.label ?? '').toLowerCase().contains(_search),
        )
        .toList();
    return AlertDialog(
      title: Text(localize(context, 'Choose a model', 'اختر نموذجًا')),
      content: SizedBox(
        width: 450,
        height: 380,
        child: Column(
          children: [
            TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: localize(context, 'Search models', 'البحث عن نموذج'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  return ListTile(
                    title: Text(
                      model.label ?? model.id,
                      textDirection: TextDirection.ltr,
                    ),
                    subtitle: model.label != null && model.label != model.id
                        ? Text(model.id, textDirection: TextDirection.ltr)
                        : null,
                    trailing: model.contextWindow == null
                        ? null
                        : Text('${model.contextWindow}'),
                    onTap: () => Navigator.pop(context, model),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
