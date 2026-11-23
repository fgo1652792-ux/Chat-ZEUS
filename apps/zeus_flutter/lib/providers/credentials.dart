import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class Credentials {
  Future<String?> read(String id);
  Future<void> write(String id, String value);
  Future<void> delete(String id);
}

Credentials createCredentials() =>
    kIsWeb ? SessionCredentials() : const DeviceCredentials();

class SessionCredentials implements Credentials {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String id) async => _values[id];

  @override
  Future<void> write(String id, String value) async => _values[id] = value;

  @override
  Future<void> delete(String id) async => _values.remove(id);
}

class DeviceCredentials implements Credentials {
  const DeviceCredentials();

  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  String _key(String id) => 'zeus.provider.$id';

  @override
  Future<String?> read(String id) => _storage.read(key: _key(id));

  @override
  Future<void> write(String id, String value) =>
      _storage.write(key: _key(id), value: value);

  @override
  Future<void> delete(String id) => _storage.delete(key: _key(id));
}
