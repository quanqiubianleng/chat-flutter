import 'dart:convert';
import 'dart:io';

import 'package:education/core/utils/chat_media_uploader.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/user/user.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:education/config/app_config.dart';

/// 编辑资料页：昵称、简介、背景图、头像。初始数据来自接口，保存走保存信息接口。
class EditProfilePage extends StatefulWidget {
  final User user;
  final String? intro;
  final String? backgroundUrl;
  final VoidCallback? onSaved;

  const EditProfilePage({
    super.key,
    required this.user,
    this.intro,
    this.backgroundUrl,
    this.onSaved,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nicknameController;
  late TextEditingController _introController;
  final ImagePicker _picker = ImagePicker();

  static const int _introMaxLength = 300;

  String? _backgroundPath;
  String? _avatarPath;
  bool _saving = false;
  bool _uploadingBg = false;
  bool _uploadingAvatar = false;
  final UserApi _api = UserApi();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.user.username);
    _introController = TextEditingController(text: widget.intro ?? '');
    _backgroundPath = widget.backgroundUrl;
    _avatarPath = widget.user.avatarUrl.isNotEmpty && !widget.user.avatarUrl.startsWith('http')
        ? widget.user.avatarUrl
        : null;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<String?> _pickImageToTemp(String prefix) async {
    final XFile? xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}${path.extension(xFile.path)}';
      final dest = File(path.join(dir.path, name));
      await File(xFile.path).copy(dest.path);
      return dest.path;
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '读取图片失败');
      return null;
    }
  }

  Future<void> _pickBackground() async {
    if (_uploadingBg) return;
    final localPath = await _pickImageToTemp('profile_bg');
    if (localPath == null || !mounted) return;
    setState(() => _uploadingBg = true);
    try {
      final urls = await ChatMediaUploader.uploadMedias(
        context: context,
        localPaths: [localPath],
      );
      if (urls.isNotEmpty && mounted) {
        setState(() {
          _backgroundPath = urls.first;
          _uploadingBg = false;
        });
      } else if (mounted) {
        setState(() => _uploadingBg = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingBg = false);
        Fluttertoast.showToast(msg: '背景图上传失败');
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final localPath = await _pickImageToTemp('profile_avatar');
    if (localPath == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final urls = await ChatMediaUploader.uploadMedias(
        context: context,
        localPaths: [localPath],
      );
      if (urls.isNotEmpty && mounted) {
        setState(() {
          _avatarPath = urls.first;
          _uploadingAvatar = false;
        });
      } else if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        Fluttertoast.showToast(msg: '头像上传失败');
      }
    }
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: '请输入昵称');
      return;
    }
    setState(() => _saving = true);
    try {
      // 1. 构造 settings JSON（只包含需要更新的字段）
      final Map<String, dynamic> settingsMap = {};

      // intro（简介）
      final intro = _introController.text.trim();
      if (intro.isNotEmpty) {
        settingsMap['intro'] = intro;
      } else if (widget.intro?.isNotEmpty ?? false) {
        // 可选：如果前端没改，但原来有值，也可以传回去（视后端是否需要）
        settingsMap['intro'] = widget.intro;
      }

      // background_url
      final backgroundUrl = _backgroundPath ?? widget.backgroundUrl;
      settingsMap['background_url'] = backgroundUrl;

      // 转成 JSON 字符串
      final settingsJson = settingsMap.isNotEmpty ? jsonEncode(settingsMap) : null;

      // 2. 准备传给后端的 body
      final updateData = <String, dynamic>{
        'username': nickname,
        'avatar_url': _avatarPath ?? widget.user.avatarUrl,
      };

      // 3. 如果有 settings 内容，才加进去（避免传空字符串）
      if (settingsJson != null && settingsJson != '{}') {
        updateData['settings'] = settingsJson;
      }
      print('settingsMap');
      print(updateData);
      // 4. 调用 API
      final res = await _api.updateUserInfo(updateData);
      if(res['code'] == HttpStatus.success){
        widget.onSaved?.call();
        if (mounted) {
          Navigator.pop(context, true);
          Fluttertoast.showToast(msg: '保存成功');
        }
      }else{
        Fluttertoast.showToast(msg: res['msg']);
      }

    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
        ),
        title: const Text('编辑资料', style: TextStyle(fontSize: 16, color: Colors.black87)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: Color(0xFF00D1A7), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 背景图 + 编辑背景
            Stack(
              children: [
                GestureDetector(
                  onTap: _uploadingBg ? null : _pickBackground,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: _backgroundPath == null
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2C3E50), Color(0xFF4A6FA5)],
                            )
                          : null,
                      color: _backgroundPath == null ? null : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildBackgroundImage() ?? const SizedBox.shrink(),
                        if (_uploadingBg)
                          Container(
                            color: Colors.black38,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _uploadingBg ? null : _pickBackground,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            const Text('编辑背景', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 头像（略重叠背景）
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: _avatarPath != null
                                  ? (_avatarPath!.startsWith('http')
                                      ? Image.network(_avatarPath!, fit: BoxFit.cover, width: 80, height: 80,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Colors.grey))
                                      : Image.file(File(_avatarPath!), fit: BoxFit.cover, width: 80, height: 80))
                                  : (widget.user.avatarUrl.isNotEmpty
                                      ? Image.network(widget.user.avatarUrl, fit: BoxFit.cover, width: 80, height: 80,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Colors.grey))
                                      : const Icon(Icons.person, size: 40, color: Colors.grey)),
                            ),
                            if (_uploadingAvatar)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D1A7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 昵称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('昵称', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nicknameController,
                          cursorColor: const Color(0xFF00D1A7),
                          decoration: const InputDecoration(
                            hintText: '请输入昵称',
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8E8E8))),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8E8E8))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1A7), width: 1.5)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 简介
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('简介', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _introController,
                    maxLength: _introMaxLength,
                    maxLines: 4,
                    cursorColor: const Color(0xFF00D1A7),
                    decoration: InputDecoration(
                      hintText: '在你的个人资料中添加个人简介',
                      border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8E8E8))),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8E8E8))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1A7), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      counterText: '${_introController.text.length}/$_introMaxLength',
                    ),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (_) => setState(() {}),
                  ),

                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
        ),
      ),
    );
  }

  Widget? _buildBackgroundImage() {
    if (_backgroundPath != null && _backgroundPath!.isNotEmpty) {
      if (_backgroundPath!.startsWith('http')) {
        return Image.network(_backgroundPath!, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
      }
      if (File(_backgroundPath!).existsSync()) {
        return Image.file(File(_backgroundPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    }
    return null;
  }
}
