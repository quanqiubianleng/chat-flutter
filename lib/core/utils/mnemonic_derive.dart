import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;

/// 从助记词派生私钥（与后端 multichain_wallet.go BIP44 路径一致）
class MnemonicDerive {
  /// 以太坊 BIP44 路径: m/44'/60'/0'/0/0
  static const String ethPath = "m/44'/60'/0'/0/0";
  /// 波场 BIP44 路径: m/44'/195'/0'/0/0
  static const String trxPath = "m/44'/195'/0'/0/0";

  /// 从助记词派生 ETH 私钥（hex 格式 0x + 64 字符）
  static String? deriveEthPrivateKey(String mnemonic) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic.trim());
      final node = bip32.BIP32.fromSeed(seed);
      final child = node.derivePath(ethPath);
      final pk = child.privateKey;
      if (pk == null) return null;
      return '0x${_bytesToHex(pk)}';
    } catch (_) {
      return null;
    }
  }

  /// 从助记词派生 TRX 私钥（hex 格式 0x + 64 字符）
  static String? deriveTrxPrivateKey(String mnemonic) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic.trim());
      final node = bip32.BIP32.fromSeed(seed);
      final child = node.derivePath(trxPath);
      final pk = child.privateKey;
      if (pk == null) return null;
      return '0x${_bytesToHex(pk)}';
    } catch (_) {
      return null;
    }
  }

  /// 派生 ETH 和 TRX 私钥
  static Map<String, String> derivePrivateKeys(String mnemonic) {
    return {
      'eth': deriveEthPrivateKey(mnemonic) ?? '',
      'trx': deriveTrxPrivateKey(mnemonic) ?? '',
    };
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 校验助记词是否有效
  static bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic.trim());
  }
}
