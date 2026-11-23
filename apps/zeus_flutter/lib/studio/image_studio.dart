import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:uuid/uuid.dart';

import '../design.dart';
import '../providers/provider_protocol.dart';
import '../providers/provider_repository.dart';
import '../rich/rich_message.dart';
import 'image_api.dart';

class ImageStudio extends StatefulWidget {
  const ImageStudio({
    super.key,
    required this.repository,
    this.api = const ImageApi(),
  });

  final ProviderRepository repository;
  final ImageApi api;

  @override
  State<ImageStudio> createState() => _ImageStudioState();
}

class _ImageStudioState extends State<ImageStudio> {
  final _model = TextEditingController(text: 'gpt-image-1');
  final _prompt = TextEditingController();
  Uint8List? _source;
  String? _sourceName;
  Uint8List? _preview;
  String? _description;
  String? _error;
  String? _provider;
  bool _busy = false;
  StudioAction _action = StudioAction.generate;
  late Future<List<ProviderConnection>> _providers = _loadProviders();
  late Future<List<Map<String, Object?>>> _gallery = _loadGallery();

  Future<List<ProviderConnection>> _loadProviders() async =>
      (await widget.repository.list())
          .where((p) => p.kind == ProviderKind.openai)
          .toList();

  Future<List<Map<String, Object?>>> _loadGallery() =>
      widget.repository.store.db.query(
        'generated_images',
        columns: ['id', 'prompt', 'model'],
        orderBy: 'created_at DESC',
      );

  @override
  void dispose() {
    _model.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PNG or JPEG',
            extensions: ['png', 'jpg', 'jpeg'],
            uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
          ),
        ],
      );
      if (picked == null || !mounted) return;
      if (await picked.length() > 8 * 1024 * 1024)
        throw const FormatException();
      final content = await picked.readAsBytes();
      if (content.length > 8 * 1024 * 1024 ||
          ImageApi.imageType(content) == null) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() {
          _source = content;
          _sourceName = picked.name;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = localize(
            context,
            'Choose a PNG or JPEG up to 8 MB.',
            'اختر صورة PNG أو JPEG حتى 8 ميغابايت.',
          ),
        );
    }
  }

  Future<void> _submit(String provider) async {
    final prompt = _prompt.text.trim();
    final model = _model.text.trim();
    if (prompt.isEmpty ||
        model.isEmpty ||
        (_action != StudioAction.generate && _source == null)) {
      setState(
        () => _error = localize(
          context,
          'Enter a prompt and model ID and choose an image if required.',
          'أدخل طلبًا ومعرّف نموذج واختر صورة عند الحاجة.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _description = null;
      _preview = null;
    });
    try {
      final key = await widget.repository.credentials.read(provider);
      if (key == null || key.isEmpty) {
        if (mounted)
          setState(
            () => _error = localize(
              context,
              'Add an OpenAI API key in Providers.',
              'أضف مفتاح OpenAI في المزوّدين.',
            ),
          );
        return;
      }
      final result = await widget.api.request(
        action: _action,
        key: key,
        model: model,
        prompt: prompt,
        image: _source,
      );
      final image = result.image;
      if (image != null) {
        final db = widget.repository.store.db;
        await db.transaction((tx) async {
          await tx.insert('generated_images', {
            'id': const Uuid().v4(),
            'model': model,
            'prompt': prompt,
            'payload': image,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
          await tx.execute(
            'DELETE FROM generated_images WHERE id IN (SELECT id FROM generated_images ORDER BY created_at DESC, id LIMIT -1 OFFSET 12)',
          );
        });
      }
      if (mounted) {
        setState(() {
          _preview = image;
          _description = result.description;
          _gallery = _loadGallery();
        });
      }
    } on StudioException catch (error) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'OpenAI returned HTTP ${error.status}. Check the model, API key and usage limits.',
            'أعاد OpenAI حالة HTTP ${error.status}. تحقق من النموذج والمفتاح وحدود الاستخدام.',
          ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = localize(
            context,
            'The image request could not be completed.',
            'تعذّر إكمال طلب الصورة.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String id) async {
    final rows = await widget.repository.store.db.query(
      'generated_images',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (mounted && rows.isNotEmpty) {
      setState(() {
        _description = null;
        _preview = rows.single['payload'] as Uint8List;
      });
    }
  }

  Future<void> _share(Uint8List image) async {
    final view = context.findRenderObject() as RenderBox;
    final type = ImageApi.imageType(image)!;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(image, mimeType: type)],
        fileNameOverrides: [
          'zeus-image.${type == 'image/png' ? 'png' : 'jpg'}',
        ],
        sharePositionOrigin: view.localToGlobal(Offset.zero) & view.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(localize(context, 'Image Studio', 'استوديو الصور')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder(
              future: _providers,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const LinearProgressIndicator();
                final providers = snapshot.data ?? const [];
                if (providers.isEmpty) {
                  return Text(
                    localize(
                      context,
                      'Connect an OpenAI account in Providers to use Image Studio.',
                      'اربط اتصال OpenAI في المزوّدين لاستخدام استوديو الصور.',
                    ),
                  );
                }
                final selected =
                    providers.where((p) => p.id == _provider).firstOrNull ??
                    providers.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButton<String>(
                      value: selected.id,
                      isExpanded: true,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _provider = value),
                      items: [
                        for (final provider in providers)
                          DropdownMenuItem(
                            value: provider.id,
                            child: Text(provider.label),
                          ),
                      ],
                    ),
                    DropdownButton<StudioAction>(
                      value: _action,
                      isExpanded: true,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _action = value!;
                              _model.text = _action == StudioAction.describe
                                  ? 'gpt-4.1-mini'
                                  : 'gpt-image-1';
                            }),
                      items: [
                        DropdownMenuItem(
                          value: StudioAction.generate,
                          child: Text(localize(context, 'Generate', 'توليد')),
                        ),
                        DropdownMenuItem(
                          value: StudioAction.edit,
                          child: Text(localize(context, 'Edit', 'تعديل')),
                        ),
                        DropdownMenuItem(
                          value: StudioAction.describe,
                          child: Text(localize(context, 'Describe', 'وصف')),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _model,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: localize(
                          context,
                          'Model ID',
                          'معرّف النموذج',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _prompt,
                      enabled: !_busy,
                      maxLines: 4,
                      maxLength: 12000,
                      decoration: InputDecoration(
                        labelText: localize(context, 'Prompt', 'الطلب'),
                      ),
                    ),
                    if (_action != StudioAction.generate)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickFile,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _sourceName ??
                              localize(context, 'Choose an image', 'اختر صورة'),
                        ),
                      ),
                    if (_action != StudioAction.generate && _source != null)
                      Text(
                        localize(
                          context,
                          'The selected image is sent to OpenAI when you run this request.',
                          'تُرسل الصورة المختارة إلى OpenAI عند تشغيل هذا الطلب.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_submit(selected.id)),
                      child: Text(
                        localize(context, 'Run request', 'تشغيل الطلب'),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_description case final description?) RichMessage(description),
            if (_preview case final image?) ...[
              const SizedBox(height: 12),
              Image.memory(image, cacheWidth: 1200),
              TextButton.icon(
                onPressed: () => unawaited(_share(image)),
                icon: const Icon(Icons.download),
                label: Text(localize(context, 'Export image', 'تصدير الصورة')),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              localize(context, 'Gallery', 'المعرض'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder(
              future: _gallery,
              builder: (context, snapshot) => Column(
                children: [
                  for (final row
                      in snapshot.data ?? const <Map<String, Object?>>[])
                    ListTile(
                      title: Text(
                        row['prompt']! as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(row['model']! as String),
                      leading: const Icon(Icons.image_outlined),
                      onTap: () => unawaited(_open(row['id']! as String)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
