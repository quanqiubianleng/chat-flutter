import 'package:shared_preferences/shared_preferences.dart';

/// 行情页「自选」代币列表缓存：存储 key 为 chain|contractAddress
class MarketFavoritesCache {
  static const String _key = 'market_favorites_list';

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key);
    return list ?? [];
  }

  static Future<void> setFavorites(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys);
  }

  /// 添加自选，key 格式：chain|contractAddress（如 bnb-mainnet|0x832...）
  static Future<void> add(String chain, String contractAddress) async {
    final list = await getFavorites();
    final key = _makeKey(chain, contractAddress);
    if (list.contains(key)) return;
    list.add(key);
    await setFavorites(list);
  }

  /// 移除自选
  static Future<void> remove(String chain, String contractAddress) async {
    final list = await getFavorites();
    final key = _makeKey(chain, contractAddress);
    list.remove(key);
    await setFavorites(list);
  }

  static bool isFavorite(List<String> favorites, String chain, String contractAddress) {
    return favorites.contains(_makeKey(chain, contractAddress));
  }

  static String _makeKey(String chain, String contractAddress) {
    return '$chain|${contractAddress.toLowerCase()}';
  }
}
