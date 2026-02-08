import 'package:shared_preferences/shared_preferences.dart';

class UserCache {
  static const _tokenKey = 'user_token';
  static const _userIdKey = 'user_id';
  static const _deviceNoKey = 'device_no';
  static const _didIdKey = 'did_id';
  static const _avatarKey = 'avatar';
  static const _nicknameKey = 'nickname';
  static const _introKey = 'user_intro';
  static const _backgroundImageKey = 'user_background_image';
  static const _localAvatarPathKey = 'local_avatar_path';

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

  static Future<void> saveIntro(String intro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_introKey, intro);
  }

  static Future<String?> getIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_introKey);
  }

  static Future<void> saveBackgroundImage(String pathOrUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundImageKey, pathOrUrl);
  }

  static Future<String?> getBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundImageKey);
  }

  static Future<void> saveLocalAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localAvatarPathKey, path);
  }

  static Future<String?> getLocalAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localAvatarPathKey);
  }
}
