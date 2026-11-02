import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../features/screening/domain/screening_result.dart';

class EncryptedHistoryStore {
  static const _keyName = 'hemo_scan_history_key';
  static const _fileName = 'screening_history.bin';

  final FlutterSecureStorage _secureStorage;
  final AesGcm _cipher;

  EncryptedHistoryStore({
    FlutterSecureStorage? secureStorage,
    AesGcm? cipher,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _cipher = cipher ?? AesGcm.with256bits();

  Future<List<ScreeningResult>> readAll() async {
    final file = await _historyFile();
    if (!await file.exists()) return const [];

    final encoded = await file.readAsString();
    final combined = base64Url.decode(encoded);
    if (combined.length < 13) {
      throw StateError('Encrypted history file is invalid.');
    }

    final nonce = combined.sublist(0, 12);
    final macBytes = combined.sublist(12, 28);
    final cipherText = combined.sublist(28);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final clear = await _cipher.decrypt(
      secretBox,
      secretKey: await _secretKey(),
    );
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! List) {
      throw StateError('Encrypted history payload is invalid.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ScreeningResult.fromJson)
        .toList(growable: false);
  }

  Future<void> append(ScreeningResult result) async {
    final results = [...await readAll(), result];
    final clear =
        utf8.encode(jsonEncode(results.map((item) => item.toJson()).toList()));
    final box = await _cipher.encrypt(clear, secretKey: await _secretKey());
    final combined = <int>[
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
    final file = await _historyFile();
    await file.writeAsString(base64UrlEncode(combined), flush: true);
  }

  Future<void> deleteAll() async {
    final file = await _historyFile();
    if (await file.exists()) await file.delete();
  }

  Future<SecretKey> _secretKey() async {
    var encoded = await _secureStorage.read(key: _keyName);
    if (encoded == null) {
      final key = await _cipher.newSecretKey();
      encoded = base64UrlEncode(await key.extractBytes());
      await _secureStorage.write(key: _keyName, value: encoded);
    }
    return SecretKey(base64Url.decode(encoded));
  }

  Future<File> _historyFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, _fileName));
  }
}
