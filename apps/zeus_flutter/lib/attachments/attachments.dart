import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';

import '../data/local_store.dart';

enum AttachmentKind { image, pdf, text }

class ConversationFile {
  const ConversationFile({
    required this.id,
    required this.threadId,
    required this.name,
    required this.kind,
    required this.size,
  });

  final String id;
  final String threadId;
  final String name;
  final AttachmentKind kind;
  final int size;

  factory ConversationFile.fromRow(Map<String, Object?> row) =>
      ConversationFile(
        id: row['id']! as String,
        threadId: row['conversation_id']! as String,
        name: row['name']! as String,
        kind: AttachmentKind.values.byName(row['kind']! as String),
        size: row['size']! as int,
      );
}

class AttachmentException implements Exception {
  const AttachmentException(this.reason);
  final String reason;
}

class AttachmentLibrary {
  const AttachmentLibrary(this.store);

  final LocalStore store;
  static const maxFileBytes = 8 * 1024 * 1024;
  static const maxThreadBytes = 32 * 1024 * 1024;
  static const allowed = XTypeGroup(
    label: 'Documents and images',
    extensions: [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'pdf',
      'txt',
      'csv',
      'md',
      'json',
    ],
    uniformTypeIdentifiers: [
      'public.png',
      'public.jpeg',
      'org.webmproject.webp',
      'com.adobe.pdf',
      'public.plain-text',
      'public.comma-separated-values-text',
      'public.json',
    ],
  );

  Future<List<ConversationFile>> list(String threadId) async {
    final rows = await store.db.query(
      'attachments',
      columns: ['id', 'conversation_id', 'name', 'kind', 'size'],
      where: 'conversation_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at DESC, id',
    );
    return rows.map(ConversationFile.fromRow).toList();
  }

  Future<ConversationFile> importFile(String threadId, XFile file) async {
    final declaredSize = await file.length();
    if (declaredSize == 0 || declaredSize > maxFileBytes) {
      throw const AttachmentException('size');
    }
    final content = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (content.length + chunk.length > maxFileBytes) {
        throw const AttachmentException('size');
      }
      content.add(chunk);
    }
    final bytes = content.takeBytes();
    final name = file.name.split(RegExp(r'[/\\]')).last.trim();
    if (name.isEmpty || name.length > 240) {
      throw const AttachmentException('format');
    }
    final kind = _fileKind(name, bytes);
    final id = const Uuid().v4();
    final row = <String, Object?>{
      'id': id,
      'conversation_id': threadId,
      'name': name,
      'kind': kind.name,
      'size': bytes.length,
      'payload': bytes,
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    await store.db.transaction((transaction) async {
      final result = await transaction.rawQuery(
        'SELECT COALESCE(SUM(size), 0) AS bytes, COUNT(*) AS files FROM attachments WHERE conversation_id = ?',
        [threadId],
      );
      final total = result.single['bytes']! as int;
      final count = result.single['files']! as int;
      if (total + bytes.length > maxThreadBytes || count >= 24) {
        throw const AttachmentException('quota');
      }
      await transaction.insert('attachments', row);
    });
    return ConversationFile.fromRow(row);
  }

  Future<Uint8List> contents(ConversationFile attachment) async {
    final row = await store.db.query(
      'attachments',
      columns: ['payload'],
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [attachment.id, attachment.threadId],
      limit: 1,
    );
    if (row.isEmpty) throw const AttachmentException('missing');
    return row.single['payload']! as Uint8List;
  }

  Future<void> remove(ConversationFile attachment) async {
    await store.db.delete(
      'attachments',
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [attachment.id, attachment.threadId],
    );
  }

  static AttachmentKind _fileKind(String name, Uint8List data) {
    final extension = name.split('.').last.toLowerCase();
    bool matches(List<int> signature) {
      if (data.length < signature.length) return false;
      for (var offset = 0; offset < signature.length; offset++) {
        if (data[offset] != signature[offset]) return false;
      }
      return true;
    }

    if (extension == 'pdf' && matches(const [37, 80, 68, 70, 45])) {
      return AttachmentKind.pdf;
    }
    if (extension == 'png' &&
        matches(const [137, 80, 78, 71, 13, 10, 26, 10])) {
      return AttachmentKind.image;
    }
    if (['jpg', 'jpeg'].contains(extension) && matches(const [255, 216, 255])) {
      return AttachmentKind.image;
    }
    if (extension == 'webp' &&
        matches(const [82, 73, 70, 70]) &&
        data.length >= 12 &&
        String.fromCharCodes(data.sublist(8, 12)) == 'WEBP') {
      return AttachmentKind.image;
    }
    if (['txt', 'csv', 'md', 'json'].contains(extension) && !data.contains(0)) {
      try {
        utf8.decode(data);
        return AttachmentKind.text;
      } on FormatException {
        throw const AttachmentException('format');
      }
    }
    throw const AttachmentException('format');
  }
}
