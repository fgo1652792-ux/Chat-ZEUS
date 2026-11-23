import 'dart:async';

import 'package:flutter/material.dart';

import '../design.dart';
import 'project_repository.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, required this.repository});
  final ProjectRepository repository;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late Future<List<Project>> _projects = widget.repository.list();

  void _reload() => setState(() => _projects = widget.repository.list());

  Future<void> _open([Project? project]) async {
    final title = TextEditingController(text: project?.name ?? '');
    final instructions = TextEditingController(
      text: project?.instructions ?? '',
    );
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            project == null
                ? localize(context, 'New project', 'مشروع جديد')
                : project.name,
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: localize(context, 'Name', 'الاسم'),
                    ),
                  ),
                  TextField(
                    controller: instructions,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      labelText: localize(
                        context,
                        'Project instructions',
                        'تعليمات المشروع',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localize(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(localize(context, 'Save', 'حفظ')),
            ),
          ],
        ),
      );
      if (!mounted || save != true || title.text.trim().isEmpty) return;
      if (project == null) {
        await widget.repository.create(
          title.text.trim(),
          instructions.text.trim(),
        );
      } else {
        await widget.repository.update(
          project,
          title.text.trim(),
          instructions.text.trim(),
        );
      }
      if (mounted) _reload();
    } finally {
      title.dispose();
      instructions.dispose();
    }
  }

  Future<void> _delete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localize(
            context,
            'Remove project and its notes?',
            'حذف المشروع وملاحظاته؟',
          ),
        ),
        content: Text(project.name),
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
    if (confirmed == true && mounted) {
      await widget.repository.delete(project);
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(localize(context, 'Projects', 'المشاريع'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FutureBuilder(
          future: _projects,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.add),
                label: Text(localize(context, 'New project', 'مشروع جديد')),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
              if (snapshot.hasError)
                TextButton(
                  onPressed: _reload,
                  child: Text(
                    localize(
                      context,
                      'Could not load projects. Retry',
                      'تعذر تحميل المشاريع. أعد المحاولة',
                    ),
                  ),
                ),
              for (final project in snapshot.data ?? const <Project>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: ZeusPane(
                    child: ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(project.name),
                      subtitle: project.instructions.isEmpty
                          ? null
                          : Text(
                              project.instructions,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => unawaited(
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => _MemoryScreen(
                              project: project,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => unawaited(
                          action == 'edit' ? _open(project) : _delete(project),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              localize(
                                context,
                                'Edit instructions',
                                'تعديل التعليمات',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              localize(
                                context,
                                'Remove project',
                                'حذف المشروع',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MemoryScreen extends StatefulWidget {
  const _MemoryScreen({required this.project, required this.repository});
  final Project project;
  final ProjectRepository repository;

  @override
  State<_MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<_MemoryScreen> {
  late Future<List<ProjectMemory>> _notes = widget.repository.memories(
    widget.project.id,
  );

  Future<void> _edit([ProjectMemory? existing]) async {
    final field = TextEditingController(text: existing?.text ?? '');
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localize(context, 'Project note', 'ملاحظة المشروع')),
          content: TextField(
            controller: field,
            minLines: 2,
            maxLines: 6,
            maxLength: 1000,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localize(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, field.text.trim()),
              child: Text(localize(context, 'Save', 'حفظ')),
            ),
          ],
        ),
      );
      if (!mounted || value == null || value.isEmpty) return;
      if (existing == null) {
        await widget.repository.addMemory(widget.project.id, value);
      } else {
        await widget.repository.editMemory(existing, value);
      }
      if (mounted) {
        setState(() => _notes = widget.repository.memories(widget.project.id));
      }
    } finally {
      field.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.project.name)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FutureBuilder(
          future: _notes,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                localize(
                  context,
                  'These notes are included only in requests from conversations in this project.',
                  'تُضاف هذه الملاحظات فقط إلى طلبات المحادثات داخل هذا المشروع.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: Text(localize(context, 'Add note', 'إضافة ملاحظة')),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
              for (final note in snapshot.data ?? const <ProjectMemory>[])
                ListTile(
                  title: Text(note.text),
                  onTap: () => unawaited(_edit(note)),
                  trailing: IconButton(
                    onPressed: () async {
                      await widget.repository.removeMemory(note);
                      if (mounted) {
                        setState(
                          () => _notes = widget.repository.memories(
                            widget.project.id,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    tooltip: localize(context, 'Remove note', 'حذف الملاحظة'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
