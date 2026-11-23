import 'package:uuid/uuid.dart';

import '../data/local_store.dart';

class Project {
  const Project(this.id, this.name, this.instructions);
  final String id;
  final String name;
  final String instructions;

  factory Project.fromRow(Map<String, Object?> value) => Project(
    value['id']! as String,
    value['name']! as String,
    value['instructions']! as String,
  );
}

class ProjectMemory {
  const ProjectMemory(this.id, this.projectId, this.text);
  final String id;
  final String projectId;
  final String text;
}

class ProjectRepository {
  const ProjectRepository(this.store);
  final LocalStore store;

  Future<List<Project>> list() async {
    final rows = await store.db.query(
      'projects',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return rows.map(Project.fromRow).toList();
  }

  Future<void> create(String name, String instructions) => store.db.insert(
    'projects',
    {'id': const Uuid().v4(), 'name': name, 'instructions': instructions},
  );

  Future<void> update(Project project, String name, String instructions) =>
      store.db.update(
        'projects',
        {'name': name, 'instructions': instructions},
        where: 'id = ?',
        whereArgs: [project.id],
      );

  Future<void> delete(Project project) =>
      store.db.delete('projects', where: 'id = ?', whereArgs: [project.id]);

  Future<List<ProjectMemory>> memories(String projectId) async {
    final rows = await store.db.query(
      'project_memories',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at',
    );
    return [
      for (final row in rows)
        ProjectMemory(
          row['id']! as String,
          row['project_id']! as String,
          row['text']! as String,
        ),
    ];
  }

  Future<void> addMemory(String projectId, String text) =>
      store.db.insert('project_memories', {
        'id': const Uuid().v4(),
        'project_id': projectId,
        'text': text,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> editMemory(ProjectMemory memory, String text) => store.db.update(
    'project_memories',
    {'text': text},
    where: 'id = ? AND project_id = ?',
    whereArgs: [memory.id, memory.projectId],
  );

  Future<void> removeMemory(ProjectMemory memory) => store.db.delete(
    'project_memories',
    where: 'id = ? AND project_id = ?',
    whereArgs: [memory.id, memory.projectId],
  );

  Future<String> instructionsForThread(String id) async {
    return store.db.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''
        SELECT p.id, p.instructions FROM projects p
        JOIN conversations c ON p.id = c.project_id WHERE c.id = ?
      ''',
        [id],
      );
      if (rows.isEmpty) return '';
      final memories = await tx.query(
        'project_memories',
        columns: ['text'],
        where: 'project_id = ?',
        whereArgs: [rows.single['id']],
        orderBy: 'created_at',
        limit: 24,
      );
      return [
        rows.single['instructions']! as String,
        if (memories.isNotEmpty)
          'Project notes supplied by the user:\n${memories.map((row) => row['text']).join('\n')}',
      ].where((text) => text.isNotEmpty).join('\n\n');
    });
  }
}
