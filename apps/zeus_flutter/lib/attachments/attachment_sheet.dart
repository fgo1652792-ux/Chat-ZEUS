import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../design.dart';
import 'attachments.dart';

class AttachmentSheet extends StatefulWidget {
  const AttachmentSheet({
    super.key,
    required this.library,
    required this.threadId,
  });

  final AttachmentLibrary library;
  final String threadId;

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet> {
  late Future<List<ConversationFile>> _files = widget.library.list(
    widget.threadId,
  );
  bool _importing = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final selected = await openFiles(
        acceptedTypeGroups: [AttachmentLibrary.allowed],
      );
      for (final file in selected) {
        await widget.library.importFile(widget.threadId, file);
      }
    } on AttachmentException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.reason) {
            'size' => localize(
              context,
              'Choose a non-empty file up to 8 MB.',
              'اختر ملفًا غير فارغ بحجم لا يتجاوز 8 ميغابايت.',
            ),
            'quota' => localize(
              context,
              'This conversation has reached its attachment limit.',
              'بلغت المحادثة حد المرفقات.',
            ),
            _ => localize(
              context,
              'The file type or content is unsupported.',
              'نوع الملف أو محتواه غير مدعوم.',
            ),
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'Could not import the file.',
            'تعذر استيراد الملف.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _files = widget.library.list(widget.threadId);
        });
      }
    }
  }

  Future<void> _remove(ConversationFile file) async {
    await widget.library.remove(file);
    if (mounted) setState(() => _files = widget.library.list(widget.threadId));
  }

  Future<void> _open(ConversationFile file) async {
    final content = await widget.library.contents(file);
    if (!mounted) return;
    final insert = await showDialog<String>(
      context: context,
      builder: (context) => _Preview(file: file, content: content),
    );
    if (insert != null && mounted) Navigator.pop(context, insert);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(
                  localize(context, 'Attachments', 'المرفقات'),
                  style: theme.textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: const Icon(Icons.attach_file),
                  label: Text(localize(context, 'Add files', 'إضافة ملفات')),
                ),
              ],
            ),
            Text(
              localize(
                context,
                'Files here are stored on this device. Insert text into your draft to share it with the model.',
                'تبقى الملفات هنا على هذا الجهاز. أدرج النص في المسودة لمشاركته مع النموذج.',
              ),
            ),
            if (_importing) const LinearProgressIndicator(),
            if (_error case final error?)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder(
                future: _files,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        localize(
                          context,
                          'Could not read files.',
                          'تعذرت قراءة الملفات.',
                        ),
                      ),
                    );
                  }
                  final files = snapshot.data!;
                  return ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${(file.size / 1024).toStringAsFixed(1)} KB',
                        ),
                        leading: Icon(switch (file.kind) {
                          AttachmentKind.image => Icons.image_outlined,
                          AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
                          AttachmentKind.text => Icons.notes,
                        }),
                        onTap: () => unawaited(_open(file)),
                        trailing: IconButton(
                          onPressed: () => unawaited(_remove(file)),
                          tooltip: localize(
                            context,
                            'Remove attachment',
                            'حذف المرفق',
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
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

class _Preview extends StatefulWidget {
  const _Preview({required this.file, required this.content});

  final ConversationFile file;
  final Uint8List content;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool _working = false;
  String? _error;

  Future<void> _insert() async {
    setState(() => _working = true);
    try {
      final text = switch (widget.file.kind) {
        AttachmentKind.text => utf8.decode(widget.content),
        AttachmentKind.pdf => await _pdfText(),
        AttachmentKind.image => '',
      };
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(
          () => _error = localize(
            context,
            'This file has no extractable text.',
            'لا يوجد نص قابل للاستخراج في هذا الملف.',
          ),
        );
        return;
      }
      final bounded = String.fromCharCodes(text.runes.take(16000));
      final truncated = bounded.length < text.length;
      Navigator.pop(
        context,
        '\n\n${widget.file.name}\n$bounded${truncated ? '\n[Text truncated]' : ''}',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'Could not extract text from the file.',
            'تعذر استخراج النص من الملف.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String> _pdfText() async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      widget.content,
      sourceName: widget.file.name,
    );
    try {
      final text = StringBuffer();
      for (final page in document.pages.take(24)) {
        final value = await page.loadText();
        if (value == null || value.fullText.trim().isEmpty) continue;
        text.writeln('[Page ${page.pageNumber}]');
        text.writeln(value.fullText.trim());
        if (text.length >= 16000) break;
      }
      if (document.pages.length > 24) {
        text.writeln('[Extraction limited to the first 24 pages]');
      }
      return text.toString();
    } finally {
      await document.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    return AlertDialog(
      title: Text(file.name),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .47,
        child: switch (file.kind) {
          AttachmentKind.image => InteractiveViewer(
            child: Image.memory(
              widget.content,
              cacheWidth: 1600,
              errorBuilder: (context, _, _) => Center(
                child: Text(
                  localize(
                    context,
                    'Could not decode the image.',
                    'تعذر فك ترميز الصورة.',
                  ),
                ),
              ),
            ),
          ),
          AttachmentKind.pdf => PdfViewer.data(
            widget.content,
            sourceName: file.name,
          ),
          AttachmentKind.text => SingleChildScrollView(
            child: SelectableText(
              String.fromCharCodes(
                utf8.decode(widget.content).runes.take(50000),
              ),
            ),
          ),
        },
      ),
      actions: [
        if (_working) const LinearProgressIndicator(),
        if (_error case final error?) Text(error),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localize(context, 'Close', 'إغلاق')),
        ),
        if (file.kind != AttachmentKind.image)
          FilledButton(
            onPressed: _working ? null : _insert,
            child: Text(
              localize(
                context,
                'Insert text in draft',
                'إدراج النص في المسودة',
              ),
            ),
          ),
      ],
    );
  }
}
