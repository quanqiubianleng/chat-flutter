import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:education/core/sqlite/wallet_table.dart';
import 'package:education/core/utils/mnemonic_derive.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:sqflite/sqflite.dart';

import '../utils/logger.dart';

/// 钱包仓库：PBKDF2 推导 Key + AES 加密助记词，存储到 SQLite
class WalletRepository {
  WalletRepository(this.db);

  final Database db;

  static const int _pbkdf2Iterations = 10000;
  static const int _keyBits = 256;

  /// PBKDF2 从密码推导 AES 密钥
  static Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: _keyBits,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// AES-256-CBC 加密
  static String _encryptAes(String plaintext, Uint8List key, Uint8List iv) {
    final aes = enc.AES(enc.Key(key), mode: enc.AESMode.cbc);
    final encIv = enc.IV(iv);
    final encrypted = aes.encrypt(Uint8List.fromList(utf8.encode(plaintext)), iv: encIv);
    return base64Encode(encrypted.bytes);
  }

  /// AES-256-CBC 解密
  static String _decryptAes(String base64Cipher, Uint8List key, Uint8List iv) {
    final aes = enc.AES(enc.Key(key), mode: enc.AESMode.cbc);
    final encIv = enc.IV(iv);
    final decrypted = aes.decrypt(enc.Encrypted.fromBase64(base64Cipher), iv: encIv);
    return utf8.decode(decrypted);
  }

  /// 保存加密助记词（创建钱包 / 导入助记词成功后调用，私钥从助记词派生无需存储）
  /// 同时保存 plain_password 用于当前设备统一密码，便于后续添加账号时复用
  Future<void> saveEncryptedMnemonic({
    required int userId,
    required String didId,
    required String walletAddress,
    required String mnemonic,
    required String password,
    String? deviceNo,
  }) async {
    final random = Random.secure();
    final secureSalt = Uint8List(16);
    final secureIv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      secureSalt[i] = random.nextInt(256);
      secureIv[i] = random.nextInt(256);
    }

    final key = await _deriveKey(password, secureSalt);
    final encryptedMnemonic = _encryptAes(mnemonic, key, secureIv);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'wallet_keystore',
      {
        'user_id': userId,
        'did_id': didId,
        'wallet_address': walletAddress,
        'encrypted_mnemonic': encryptedMnemonic,
        'salt': base64Encode(secureSalt),
        'iv': base64Encode(secureIv),
        'device_no': deviceNo,
        'plain_password': password,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.d('WalletRepository: 已保存加密助记词 did=$didId');
  }

  /// 获取指定 did 的 plain_password（用于重置密码时传入正确的旧密码）
  Future<String?> getStoredPasswordForDid(String didId) async {
    final rows = await db.query(
      'wallet_keystore',
      columns: ['plain_password'],
      where: 'did_id = ?',
      whereArgs: [didId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final pwd = rows.first['plain_password'] as String?;
    return (pwd != null && pwd.isNotEmpty) ? pwd : null;
  }

  /// 获取当前设备已保存的密码（所有账号共用同一密码）
  /// 用于添加新账号时复用，无记录时返回 null
  Future<String?> getDevicePassword() async {
    final rows = await db.query(
      'wallet_keystore',
      columns: ['plain_password'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final pwd = rows.first['plain_password'] as String?;
    return (pwd != null && pwd.isNotEmpty) ? pwd : null;
  }

  /// 导出助记词（需验证用户输入的密码，不 fallback 到 plain_password）
  Future<String?> exportMnemonic(String didId, String password) async {
    final rows = await db.query(
      'wallet_keystore',
      where: 'did_id = ?',
      whereArgs: [didId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final salt = base64Decode(row['salt'] as String);
    final iv = base64Decode(row['iv'] as String);
    final encrypted = row['encrypted_mnemonic'] as String;

    try {
      final key = await _deriveKey(password, Uint8List.fromList(salt));
      return _decryptAes(encrypted, key, Uint8List.fromList(iv));
    } catch (e) {
      AppLogger.e('WalletRepository exportMnemonic 解密失败', e, null);
      return null;
    }
  }

  /// 根据 didId 导出私钥（需验证密码，从助记词派生，与后端 BIP44 路径一致）
  Future<String?> exportPrivateKey(String didId, String password) async {
    final mnemonic = await exportMnemonic(didId, password);
    if (mnemonic == null || mnemonic.isEmpty) return null;
    // 从助记词派生 ETH 私钥（m/44'/60'/0'/0/0）
    return MnemonicDerive.deriveEthPrivateKey(mnemonic);
  }

  /// 导出 ETH 和 TRX 私钥
  Future<Map<String, String>> exportPrivateKeys(String didId, String password) async {
    final mnemonic = await exportMnemonic(didId, password);
    if (mnemonic == null || mnemonic.isEmpty) return {};
    return MnemonicDerive.derivePrivateKeys(mnemonic);
  }

  /// 检查该 did 是否有存储的助记词
  Future<bool> hasMnemonicForDid(String didId) async {
    final rows = await db.query(
      'wallet_keystore',
      columns: ['id'],
      where: 'did_id = ?',
      whereArgs: [didId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 移除账号的加密数据
  Future<int> removeByDid(String didId) async {
    return db.delete(
      'wallet_keystore',
      where: 'did_id = ?',
      whereArgs: [didId],
    );
  }

  /// 获取当前设备下所有有助记词的 did 列表（用于验证旧密码）
  Future<List<Map<String, dynamic>>> getAllWalletRows() async {
    return db.query('wallet_keystore');
  }

  /// 重置密码：用旧密码解密所有助记词，用新密码重新加密并更新
  /// 至少需要一条记录能用 oldPassword 解密成功
  Future<bool> updateAllPasswords(String oldPassword, String newPassword) async {
    final rows = await db.query('wallet_keystore');
    if (rows.isEmpty) return true;

    final toUpdate = <Map<String, dynamic>>[];
    for (final row in rows) {
      final didId = row['did_id'] as String;
      final mnemonic = await exportMnemonic(didId, oldPassword);
      if (mnemonic == null || mnemonic.isEmpty) {
        AppLogger.e('WalletRepository updateAllPasswords: did=$didId 解密失败，旧密码可能错误', null, null);
        return false;
      }
      toUpdate.add({
        'row': row,
        'mnemonic': mnemonic,
      });
    }

    for (final item in toUpdate) {
      final row = item['row'] as Map<String, dynamic>;
      final mnemonic = item['mnemonic'] as String;
      final didId = row['did_id'] as String;
      final userId = row['user_id'] as int;
      final walletAddress = row['wallet_address'] as String;
      final deviceNo = row['device_no'] as String?;

      await saveEncryptedMnemonic(
        userId: userId,
        didId: didId,
        walletAddress: walletAddress,
        mnemonic: mnemonic,
        password: newPassword,
        deviceNo: deviceNo,
      );
    }
    AppLogger.d('WalletRepository: 已更新所有助记词密码及 plain_password');
    return true;
  }
}
