import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../data/local_store.dart';

enum MessageState { completed, streaming, cancelled, interrupted, failed }

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.draft,
    required this.updatedAt,
    this.providerId,
    this.modelId,
    this.projectId,
    this.archived = false,
    this.pinned = false,
    this.deleted = false,
  });

  final String id;
  final String title;
  final String draft;
  final int updatedAt;
  final String? providerId;
  final String? modelId;
  final String? projectId;
  final bool archived;
  final bool pinned;
  final bool deleted;

  factory ChatThread.fromRow(Map<String, Object?> row) => ChatThread(
    id: row['id']! as String,
    title: row['title']! as String,
    draft: row['draft']! as String,
    updatedAt: row['updated_at']! as int,
    providerId: row['provider_id'] as String?,
    modelId: row['model_id'] as String?,
    projectId: row['project_id'] as String?,
    archived: row['archived'] == 1,
    pinned: row['pinned'] == 1,
    deleted: row['deleted'] == 1,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.ordinal,
    required this.role,
    required this.text,
    required this.state,
    this.providerId,
    this.modelId,
    this.error,
    this.inputTokens,
    this.outputTokens,
  });

  final String id;
  final String threadId;
  final int ordinal;
  final String role;
  final String text;
  final MessageState state;
  final String? providerId;
  final String? modelId;
  final String? error;
  final int? inputTokens;
  final int? outputTokens;

  factory ChatMessage.fromRow(Map<String, Object?> row) => ChatMessage(
    id: row['id']! as String,
    threadId: row['conversation_id']! as String,
    ordinal: row['ordinal']! as int,
    role: row['role']! as String,
    text: row['content']! as String,
    state: MessageState.values.byName(row['status']! as String),
    providerId: row['provider_id'] as String?,
    modelId: row['model_id'] as String?,
    error: row['error_code'] as String?,
    inputTokens: row['input_tokens'] as int?,
    outputTokens: row['output_tokens'] as int?,
  );
}

class ChatRepository {
  ChatRepository(this.store);

  final LocalStore store;
  Database get _db => store.db;
  static const _uuid = Uuid();

  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<void> recoverInterrupted() async {
    await _db.update(
      'messages',
      {'status': MessageState.interrupted.name},
      where: 'status = ?',
      whereArgs: [MessageState.streaming.name],
    );
  }

  Future<List<ChatThread>> list({
    bool archived = false,
    bool deleted = false,
    String search = '',
  }) async {
    final filters = ['deleted = ?', if (!deleted) 'archived = ?'];
    final args = <Object?>[deleted ? 1 : 0, if (!deleted) archived ? 1 : 0];
    if (search.trim().isNotEmpty) {
      final term =
          '%${search.trim().replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%';
      filters.add(
        '''(title LIKE ? ESCAPE '!' OR id IN
        (SELECT conversation_id FROM messages WHERE content LIKE ? ESCAPE '!'))''',
      );
      args.addAll([term, term]);
    }
    final data = await _db.query(
      'conversations',
      where: filters.join(' AND '),
      whereArgs: args,
      orderBy: 'pinned DESC, updated_at DESC, id',
    );
    return data.map(ChatThread.fromRow).toList(growable: false);
  }

  Future<ChatThread> create(
    String title, {
    String? providerId,
    String? modelId,
  }) async {
    final id = _uuid.v4();
    await _db.insert('conversations', {
      'id': id,
      'title': title,
      'created_at': _now,
      'updated_at': _now,
      'provider_id': providerId,
      'model_id': modelId,
    });
    return await get(id);
  }

  Future<ChatThread> get(String id) async => ChatThread.fromRow(
    (await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    )).single,
  );

  Future<List<ChatMessage>> messages(String threadId) async {
    final data = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [threadId],
      orderBy: 'ordinal',
    );
    return data.map(ChatMessage.fromRow).toList(growable: false);
  }

  Future<void> setDraft(String id, String text) => _update(id, {'draft': text});

  Future<void> setModel(String id, String providerId, String modelId) =>
      _update(id, {'provider_id': providerId, 'model_id': modelId});

  Future<void> moveToProject(String id, String? project) =>
      _update(id, {'project_id': project});

  Future<void> rename(String id, String title) => _update(id, {'title': title});

  Future<void> archive(String id, bool archived) =>
      _update(id, {'archived': archived ? 1 : 0});

  Future<void> pin(String id, bool pinned) =>
      _update(id, {'pinned': pinned ? 1 : 0});

  Future<void> trash(String id, bool deleted) =>
      _update(id, {'deleted': deleted ? 1 : 0});

  Future<void> _update(String id, Map<String, Object?> values) async {
    await _db.update('conversations', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<ChatMessage> beginTurn(
    String id,
    String? prompt,
    String provider,
    String model,
  ) async {
    return _db.transaction((tx) async {
      final existing = await tx.query(
        'conversations',
        where: 'id = ? AND deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('The conversation is unavailable.');
      }
      final result = await tx.rawQuery(
        'SELECT COALESCE(MAX(ordinal), 0) as last FROM messages WHERE conversation_id = ?',
        [id],
      );
      var ordinal = result.single['last']! as int;
      if (prompt != null) {
        await tx.insert('messages', {
          'id': _uuid.v4(),
          'conversation_id': id,
          'ordinal': ++ordinal,
          'role': 'user',
          'content': prompt,
          'status': MessageState.completed.name,
          'created_at': _now,
        });
      }
      final assistant = {
        'id': _uuid.v4(),
        'conversation_id': id,
        'ordinal': ++ordinal,
        'role': 'assistant',
        'content': '',
        'status': MessageState.streaming.name,
        'provider_id': provider,
        'model_id': model,
        'created_at': _now,
      };
      await tx.insert('messages', assistant);
      await tx.update(
        'conversations',
        {if (prompt != null) 'draft': '', 'updated_at': _now},
        where: 'id = ?',
        whereArgs: [id],
      );
      return ChatMessage.fromRow(assistant);
    });
  }

  Future<void> saveResponse(
    String id,
    String text,
    MessageState state, {
    int? inputTokens,
    int? outputTokens,
    String? error,
  }) async {
    await _db.update(
      'messages',
      {
        'content': text,
        'status': state.name,
        'error_code': error,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, MessageState.streaming.name],
    );
  }

  Future<ChatThread> fork(
    ChatThread source,
    ChatMessage anchor,
    String title, {
    String? editedText,
  }) async {
    if (source.id != anchor.threadId ||
        (editedText != null && anchor.role != 'user')) {
      throw ArgumentError(
        'The message must belong to the selected conversation.',
      );
    }
    final id = _uuid.v4();
    await _db.transaction((tx) async {
      await tx.insert('conversations', {
        'id': id,
        'title': title,
        'provider_id': source.providerId,
        'model_id': source.modelId,
        'created_at': _now,
        'updated_at': _now,
        'parent_thread': source.id,
        'project_id': source.projectId,
        'parent_message': anchor.id,
      });
      final from = await tx.query(
        'messages',
        where: 'conversation_id = ? AND ordinal <= ?',
        whereArgs: [source.id, anchor.ordinal],
        orderBy: 'ordinal',
      );
      final batch = tx.batch();
      for (final row in from) {
        batch.insert('messages', {
          ...row,
          'id': _uuid.v4(),
          'conversation_id': id,
          if (row['id'] == anchor.id && editedText != null)
            'content': editedText,
          if (row['status'] == MessageState.streaming.name)
            'status': MessageState.interrupted.name,
        });
      }
      await batch.commit(noResult: true);
    });
    return await get(id);
  }
}
