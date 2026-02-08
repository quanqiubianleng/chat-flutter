import 'package:sqflite/sqflite.dart';

/// 钱包加密存储表：助记词、私钥等敏感数据经 PBKDF2+AES 加密后存储
Future<void> createWalletTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS wallet_keystore (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      did_id TEXT NOT NULL,
      wallet_address TEXT NOT NULL,
      encrypted_mnemonic TEXT NOT NULL,
      encrypted_private_key TEXT,
      salt TEXT NOT NULL,
      iv TEXT NOT NULL,
      device_no TEXT,
      plain_password TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(did_id)
    );
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_wallet_user_id ON wallet_keystore(user_id);
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_wallet_did_id ON wallet_keystore(did_id);
  ''');
}

class WalletKeystore {
  final int? id;
  final int userId;
  final String didId;
  final String walletAddress;
  final String encryptedMnemonic;
  final String? encryptedPrivateKey;
  final String salt;
  final String iv;
  final String? deviceNo;
  final int createdAt;
  final int updatedAt;

  WalletKeystore({
    this.id,
    required this.userId,
    required this.didId,
    required this.walletAddress,
    required this.encryptedMnemonic,
    this.encryptedPrivateKey,
    required this.salt,
    required this.iv,
    this.deviceNo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletKeystore.fromMap(Map<String, dynamic> map) {
    return WalletKeystore(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      didId: map['did_id'] as String,
      walletAddress: map['wallet_address'] as String,
      encryptedMnemonic: map['encrypted_mnemonic'] as String,
      encryptedPrivateKey: map['encrypted_private_key'] as String?,
      salt: map['salt'] as String,
      iv: map['iv'] as String,
      deviceNo: map['device_no'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'did_id': didId,
      'wallet_address': walletAddress,
      'encrypted_mnemonic': encryptedMnemonic,
      'encrypted_private_key': encryptedPrivateKey,
      'salt': salt,
      'iv': iv,
      'device_no': deviceNo,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
