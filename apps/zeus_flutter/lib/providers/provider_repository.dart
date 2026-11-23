import 'package:sqflite_common/sqlite_api.dart';

import '../data/local_store.dart';
import 'credentials.dart';
import 'provider_protocol.dart';

class ProviderRepository {
  ProviderRepository(this.store, this.credentials);

  final LocalStore store;
  final Credentials credentials;

  Future<List<ProviderConnection>> list() async {
    final rows = await store.db.query(
      'providers',
      orderBy: 'label COLLATE NOCASE, id',
    );
    return rows.map(ProviderConnection.fromRow).toList();
  }

  Future<void> save(ProviderConnection connection, {String? apiKey}) async {
    final previous = await credentials.read(connection.id);
    if (apiKey != null) await _setKey(connection.id, apiKey);
    try {
      await store.db.insert(
        'providers',
        connection.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      if (apiKey != null) await _setKey(connection.id, previous ?? '');
      rethrow;
    }
  }

  Future<void> remove(ProviderConnection connection) async {
    final previous = await credentials.read(connection.id);
    await credentials.delete(connection.id);
    try {
      await store.db.delete(
        'providers',
        where: 'id = ?',
        whereArgs: [connection.id],
      );
    } catch (_) {
      if (previous != null) await credentials.write(connection.id, previous);
      rethrow;
    }
  }

  Future<void> _setKey(String id, String key) =>
      key.isEmpty ? credentials.delete(id) : credentials.write(id, key);
}
