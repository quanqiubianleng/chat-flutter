import 'package:education/services/api_service.dart';
import 'package:education/services/alchemy_service.dart';

/// BBT 余额与转账记录：客户端只请求服务端，由服务端再请求第三方（如 Alchemy）
/// 接口：GET /v1/bbt/balance、GET /v1/bbt/transfers（需鉴权，服务端内部调 Alchemy 后返回）
class BbtService {
  static final ApiClient _client = ApiClient();

  /// 当前账号 BBT 数量（由服务端请求第三方后返回）
  static Future<BbtBalanceResult> getBalance(
    String address, {
    String chain = AlchemyService.bnbMainnet,
  }) async {
    if (address.isEmpty || !address.startsWith('0x')) {
      return BbtBalanceResult(error: '无效的钱包地址');
    }
    try {
      final resp = await _client.get(
        '/v1/bbt/balance',
        data: {'address': address, 'chain': chain},
      );
      final full = ApiClient.getDataOrThrow(resp);
      final data = full['data'];
      if (data is! Map<String, dynamic>) {
        return BbtBalanceResult(error: '返回格式异常');
      }
      final balanceFormatted = data['balanceFormatted']?.toString() ?? '0';
      final balanceWei = data['balanceWei']?.toString() ?? '0';
      final symbol = data['symbol']?.toString() ?? 'BBT';
      return BbtBalanceResult(
        balanceFormatted: balanceFormatted,
        balanceWei: balanceWei,
        symbol: symbol,
      );
    } on ApiException catch (e) {
      return BbtBalanceResult(error: e.message);
    } catch (e) {
      return BbtBalanceResult(error: e.toString());
    }
  }

  /// BBT 转账记录（由服务端请求第三方后返回；收入/支出由前端按 direction 筛选）
  static Future<BbtTransfersResult> getTransfers(
    String address, {
    String chain = AlchemyService.bnbMainnet,
    int pageSize = 20,
  }) async {
    if (address.isEmpty || !address.startsWith('0x')) {
      return BbtTransfersResult(error: '无效的钱包地址');
    }
    try {
      final resp = await _client.get(
        '/v1/bbt/transfers',
        data: {'address': address, 'chain': chain, 'pageSize': pageSize},
      );
      final full = ApiClient.getDataOrThrow(resp);
      final data = full['data'];
      if (data is! Map<String, dynamic>) {
        return BbtTransfersResult(error: '返回格式异常');
      }
      final list = data['transfers'];
      final transfers = <BbtTransferItem>[];
      if (list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            try {
              transfers.add(BbtTransferItem.fromJson(e));
            } catch (_) {}
          }
        }
      }
      return BbtTransfersResult(transfers: transfers);
    } on ApiException catch (e) {
      return BbtTransfersResult(error: e.message);
    } catch (e) {
      return BbtTransfersResult(error: e.toString());
    }
  }
}

class BbtBalanceResult {
  final String? balanceFormatted;
  final String? balanceWei;
  final String? symbol;
  final String? error;

  BbtBalanceResult({
    this.balanceFormatted,
    this.balanceWei,
    this.symbol,
    this.error,
  });
}

class BbtTransferItem {
  final String from;
  final String to;
  final String value;
  final String hash;
  final String blockNum;
  /// "in" | "out"
  final String direction;

  BbtTransferItem({
    required this.from,
    required this.to,
    required this.value,
    required this.hash,
    required this.blockNum,
    required this.direction,
  });

  static BbtTransferItem fromJson(Map<String, dynamic> json) {
    return BbtTransferItem(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      value: json['value']?.toString() ?? '0',
      hash: json['hash'] as String? ?? '',
      blockNum: json['blockNum'] as String? ?? '',
      direction: json['direction'] as String? ?? 'out',
    );
  }

  bool get isIn => direction == 'in';
}

class BbtTransfersResult {
  final List<BbtTransferItem> transfers;
  final String? error;

  BbtTransfersResult({List<BbtTransferItem>? transfers, this.error})
      : transfers = transfers ?? [];
}
