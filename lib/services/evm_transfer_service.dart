import 'dart:convert';
import 'dart:typed_data';

import 'package:education/config/app_env.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// 网关 `/v1/wallet/proxy/*` 与业务接口一样需要 JWT；直连 Alchemy 则不需要。
bool _rpcUrlNeedsGatewayJwt(String rpcUrl) => rpcUrl.contains('/wallet/proxy/');

/// 为 JSON-RPC 请求自动带上与 [ApiClient] 相同的 Authorization（仅走网关代理时）。
class _GatewayJwtHttpClient extends http.BaseClient {
  _GatewayJwtHttpClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await UserCache.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = token;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

http.Client _newRpcHttpClient(String rpcUrl) {
  if (_rpcUrlNeedsGatewayJwt(rpcUrl)) {
    return _GatewayJwtHttpClient(http.Client());
  }
  return http.Client();
}

/// EVM 链转账服务：原生币与 ERC20，本地签名后通过 RPC 广播（方案 A，BBT 式不展示 gas）
class EvmTransferService {
  static String? get _apiKey => currentEnv.alchemyApiKey;

  static String _rpcUrl(String chain) {
    final proxy = currentEnv.walletProxyBaseUrl;
    if (proxy != null && proxy.isNotEmpty) {
      return '$proxy/alchemy/rpc?chain=${Uri.encodeComponent(chain)}';
    }
    final base = currentEnv.alchemyBaseUrl;
    if (base != null && base.isNotEmpty) {
      return '$base/$chain/v2/${_apiKey ?? ''}';
    }
    return 'https://$chain.g.alchemy.com/v2/${_apiKey ?? ''}';
  }

  static int _chainId(String networkId) {
    switch (networkId) {
      case 'eth-mainnet':
        return 1;
      case 'bnb-mainnet':
        return 56;
      case 'base-mainnet':
        return 8453;
      case 'x-layer':
        return 196;
      default:
        return 1;
    }
  }

  /// ERC20 transfer(address,uint256) 选择器
  static const int _transferSelector = 0xa9059cbb;
  /// ERC20 approve(address,uint256) 选择器
  static const int _approveSelector = 0x095ea7b3;
  /// ERC20 allowance(address owner, address spender) 选择器
  static const String _allowanceSelectorHex = 'dd62ed3e';

  static Uint8List _encodeErc20Transfer(EthereumAddress to, BigInt amountWei) {
    final out = ByteData(4 + 32 + 32);
    out.setUint32(0, _transferSelector, Endian.big);
    // address 右对齐 20 字节
    final toHex = to.hexNo0x;
    for (int i = 0; i < 20; i++) {
      out.setUint8(4 + 12 + i, int.parse(toHex.substring(i * 2, i * 2 + 2), radix: 16));
    }
    // uint256 32 字节
    final amountBytes = _bigIntToBytes32(amountWei);
    for (int i = 0; i < 32; i++) {
      out.setUint8(4 + 32 + i, amountBytes[i]);
    }
    return out.buffer.asUint8List();
  }

  static Uint8List _encodeErc20Approve(EthereumAddress spender, BigInt amountWei) {
    final out = ByteData(4 + 32 + 32);
    out.setUint32(0, _approveSelector, Endian.big);
    final spenderHex = spender.hexNo0x;
    for (int i = 0; i < 20; i++) {
      out.setUint8(4 + 12 + i, int.parse(spenderHex.substring(i * 2, i * 2 + 2), radix: 16));
    }
    final amountBytes = _bigIntToBytes32(amountWei);
    for (int i = 0; i < 32; i++) {
      out.setUint8(4 + 32 + i, amountBytes[i]);
    }
    return out.buffer.asUint8List();
  }

  static List<int> _bigIntToBytes32(BigInt n) {
    final hex = n.toRadixString(16).padLeft(64, '0');
    final list = <int>[];
    for (int i = 0; i < 32; i++) {
      list.add(int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    }
    return list;
  }

  static String _padAddress32(String addr) {
    addr = addr.replaceFirst(RegExp(r'^0x'), '');
    if (addr.length > 40) addr = addr.substring(addr.length - 40);
    return addr.padLeft(64, '0');
  }

  /// 查询 ERC20 对 spender 的授权额度（allowance(owner, spender)），失败返回 null
  static Future<BigInt?> getErc20Allowance({
    required String tokenContractAddress,
    required String ownerAddress,
    required String spenderAddress,
    required String networkId,
  }) async {
    final rpcUrl = _rpcUrl(networkId);
    final dataHex = '0x$_allowanceSelectorHex' +
        _padAddress32(ownerAddress) +
        _padAddress32(spenderAddress);
    try {
      final body = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [
          {'to': tokenContractAddress.startsWith('0x') ? tokenContractAddress : '0x$tokenContractAddress', 'data': dataHex},
          'latest',
        ],
      };
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_rpcUrlNeedsGatewayJwt(rpcUrl)) {
        final token = await UserCache.getToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = token;
        }
      }
      final resp = await http.post(
        Uri.parse(rpcUrl),
        headers: headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200) return null;
      final map = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (map == null) return null;
      final err = map['error'];
      if (err != null) return null;
      final result = map['result'] as String?;
      if (result == null || result == '0x' || result.length < 66) return null;
      final hex = result.startsWith('0x') ? result.substring(2) : result;
      return BigInt.parse(hex, radix: 16);
    } catch (_) {
      return null;
    }
  }

  /// 发送原生币（BNB/ETH）。BBT 式：若 amountWei == balanceWei（全部），则自动扣减预估 gas
  static Future<String> sendNative({
    required String fromAddress,
    required String toAddress,
    required BigInt amountWei,
    required BigInt balanceWei,
    required String privateKeyHex,
    required String networkId,
  }) async {
    final rpcUrl = _rpcUrl(networkId);
    final httpClient = _newRpcHttpClient(rpcUrl);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final cred = EthPrivateKey.fromHex(privateKeyHex);
      final to = EthereumAddress.fromHex(toAddress);
      final from = EthereumAddress.fromHex(fromAddress);

      final nonce = await client.getTransactionCount(from);
      var gasPrice = await client.getGasPrice();
      // 部分链 gas 偏低，设下限避免卡住
      final minGasPrice = BigInt.from(1) * BigInt.from(10).pow(9); // 1 Gwei
      if (gasPrice.getInWei < minGasPrice) {
        gasPrice = EtherAmount.inWei(minGasPrice);
      }

      var valueWei = amountWei;
      const gasLimit = 21000;
      final gasCost = gasPrice.getInWei * BigInt.from(gasLimit);
      if (amountWei == balanceWei && balanceWei > gasCost) {
        valueWei = balanceWei - gasCost;
      } else if (amountWei > balanceWei - gasCost) {
        throw Exception('余额不足（需预留网络费用）');
      }

      final tx = Transaction(
        to: to,
        value: EtherAmount.inWei(valueWei),
        gasPrice: gasPrice,
        maxGas: gasLimit,
        nonce: nonce.toInt(),
      );

      final chainId = _chainId(networkId);
      final txHash = await client.sendTransaction(cred, tx, chainId: chainId);
      AppLogger.d('EvmTransferService sendNative txHash: $txHash');
      return txHash;
    } finally {
      client.dispose();
      httpClient.close();
    }
  }

  /// 发送 ERC20。Gas 由原生币支付，不展示 gas；不足时抛异常
  static Future<String> sendErc20({
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amountWei,
    required String privateKeyHex,
    required String networkId,
  }) async {
    final rpcUrl = _rpcUrl(networkId);
    final httpClient = _newRpcHttpClient(rpcUrl);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final cred = EthPrivateKey.fromHex(privateKeyHex);
      final to = EthereumAddress.fromHex(toAddress);
      final from = EthereumAddress.fromHex(fromAddress);
      final contract = EthereumAddress.fromHex(contractAddress);

      final nonce = await client.getTransactionCount(from);
      var gasPrice = await client.getGasPrice();
      final minGasPrice = BigInt.from(1) * BigInt.from(10).pow(9);
      if (gasPrice.getInWei < minGasPrice) {
        gasPrice = EtherAmount.inWei(minGasPrice);
      }

      final data = _encodeErc20Transfer(to, amountWei);
      final gasLimitEstimated = await client.estimateGas(
        sender: from,
        to: contract,
        data: data,
        value: EtherAmount.zero(),
      );
      final gasLimitInt = (gasLimitEstimated.toInt() * 12) ~/ 10;
      final gasLimitSafe = gasLimitInt.clamp(65000, 200000);

      final tx = Transaction(
        to: contract,
        value: EtherAmount.zero(),
        gasPrice: gasPrice,
        maxGas: gasLimitSafe,
        nonce: nonce.toInt(),
        data: data,
      );

      final chainId = _chainId(networkId);
      final txHash = await client.sendTransaction(cred, tx, chainId: chainId);
      AppLogger.d('EvmTransferService sendErc20 txHash: $txHash');
      return txHash;
    } finally {
      client.dispose();
      httpClient.close();
    }
  }

  /// ERC20 授权：approve(spender, amount)，用于闪兑前授权代币给聚合器代理合约。amountWei 可传极大值表示无限授权
  static Future<String> sendErc20Approve({
    required String fromAddress,
    required String tokenContractAddress,
    required String spenderAddress,
    required BigInt amountWei,
    required String privateKeyHex,
    required String networkId,
  }) async {
    final rpcUrl = _rpcUrl(networkId);
    final httpClient = _newRpcHttpClient(rpcUrl);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final cred = EthPrivateKey.fromHex(privateKeyHex);
      final from = EthereumAddress.fromHex(fromAddress);
      final contract = EthereumAddress.fromHex(tokenContractAddress);
      final spender = EthereumAddress.fromHex(spenderAddress);

      final nonce = await client.getTransactionCount(from);
      var gasPrice = await client.getGasPrice();
      final minGasPrice = BigInt.from(1) * BigInt.from(10).pow(9);
      if (gasPrice.getInWei < minGasPrice) {
        gasPrice = EtherAmount.inWei(minGasPrice);
      }

      final data = _encodeErc20Approve(spender, amountWei);
      final gasLimitEstimated = await client.estimateGas(
        sender: from,
        to: contract,
        data: data,
        value: EtherAmount.zero(),
      );
      final gasLimitInt = (gasLimitEstimated.toInt() * 12) ~/ 10;
      final gasLimitSafe = gasLimitInt.clamp(50000, 100000);

      final tx = Transaction(
        to: contract,
        value: EtherAmount.zero(),
        gasPrice: gasPrice,
        maxGas: gasLimitSafe,
        nonce: nonce.toInt(),
        data: data,
      );

      final chainId = _chainId(networkId);
      final txHash = await client.sendTransaction(cred, tx, chainId: chainId);
      AppLogger.d('EvmTransferService sendErc20Approve txHash: $txHash');
      return txHash;
    } finally {
      client.dispose();
      httpClient.close();
    }
  }

  /// 发送 1inch 返回的 swap 交易（to、data、value、gas 等）
  static Future<String> sendSwapTransaction({
    required String fromAddress,
    required String toAddress,
    required String dataHex,
    required BigInt valueWei,
    required int gasLimit,
    BigInt? gasPriceWei,
    required String privateKeyHex,
    required String networkId,
  }) async {
    final rpcUrl = _rpcUrl(networkId);
    final httpClient = _newRpcHttpClient(rpcUrl);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final cred = EthPrivateKey.fromHex(privateKeyHex);
      final to = EthereumAddress.fromHex(toAddress);
      final from = EthereumAddress.fromHex(fromAddress);

      final nonce = await client.getTransactionCount(from);
      var gasPrice = gasPriceWei != null ? EtherAmount.inWei(gasPriceWei) : await client.getGasPrice();
      final minGasPrice = BigInt.from(1) * BigInt.from(10).pow(9);
      if (gasPrice.getInWei < minGasPrice) {
        gasPrice = EtherAmount.inWei(minGasPrice);
      }

      final data = _hexToBytes(dataHex);
      final tx = Transaction(
        to: to,
        value: EtherAmount.inWei(valueWei),
        gasPrice: gasPrice,
        maxGas: gasLimit,
        nonce: nonce.toInt(),
        data: data,
      );

      final chainId = _chainId(networkId);
      final txHash = await client.sendTransaction(cred, tx, chainId: chainId);
      AppLogger.d('EvmTransferService sendSwapTransaction txHash: $txHash');
      return txHash;
    } finally {
      client.dispose();
      httpClient.close();
    }
  }

  static Uint8List _hexToBytes(String hex) {
    String h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.length % 2 != 0) h = '0$h';
    final list = <int>[];
    for (int i = 0; i < h.length; i += 2) {
      list.add(int.parse(h.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(list);
  }
}
