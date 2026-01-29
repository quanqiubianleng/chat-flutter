import 'package:shared_preferences/shared_preferences.dart';

class UserCache {
  static const _tokenKey = 'user_token';
  static const _userIdKey = 'user_id';
  static const _deviceNoKey = 'device_no';
  static const _didIdKey = 'did_id';
  static const _avatarKey = 'avatar';
  static const _nicknameKey = 'nickname';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, nickname);
  }

  static Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }

  static Future<void> saveAvatar(String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, avatar);
  }

  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarKey);
  }

  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> saveDevice(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNoKey, token);
  }

  static Future<String?> getDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNoKey);
  }

  static Future<void> saveDid(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_didIdKey, token);
  }

  static Future<String?> getDid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_didIdKey);
  }
}
