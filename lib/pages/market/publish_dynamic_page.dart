import 'dart:io';
import 'package:education/core/utils/chat_media_uploader.dart';
import 'package:education/core/utils/get_string_uuid.dart';
import 'package:education/core/utils/logger.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

/// 发布到动态页面（支持编辑）
class PublishDynamicPage extends StatefulWidget {
  /// 编辑时传入原动态
  final PostInfo? editPost;

  const PublishDynamicPage({super.key, this.editPost});

  @override
  State<PublishDynamicPage> createState() => _PublishDynamicPageState();
}

class _PublishDynamicPageState extends State<PublishDynamicPage> {
  final TextEditingController _contentController = TextEditingController();
  static const int _maxContentLength = 10000;

  // 媒体：本地路径或已上传 URL
  final List<String> _mediaPaths = [];

  // 设置
  bool _allowRewards = true;
  bool _privateOnly = false;

  // @ 提及的用户
  final List<Map<String, dynamic>> _mentions = [];

  // 话题
  final List<Map<String, dynamic>> _topics = [];

  // 代币
  Map<String, dynamic>? _selectedToken;

  @override
  void initState() {
    super.initState();
    final edit = widget.editPost;
    if (edit != null) {
      _contentController.text = edit.content;
      _privateOnly = edit.visibility == 'private';
      if (edit.mediaList.isNotEmpty) {
        for (final m in edit.mediaList) {
          _mediaPaths.add(m.url);
        }
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.editPost != null;

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia();
    if (files.isEmpty || !mounted) return;
    final localPaths = files.map((e) => e.path).toList();
    final remain = 9 - _mediaPaths.length;
    if (remain <= 0) return;
    final toUpload = localPaths.take(remain).toList();
    try {
      final urls = await ChatMediaUploader.uploadMedias(
        context: context,
        localPaths: toUpload,
      );
      if (urls.isNotEmpty && mounted) {
        setState(() => _mediaPaths.addAll(urls));
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '上传失败');
    }
  }

  void _removeMedia(int index) {
    setState(() => _mediaPaths.removeAt(index));
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _mediaPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入描述内容或添加图片视频')),
      );
      return;
    }

    // 组装 media_list（后端格式）
    final mediaList = _mediaPaths.map((url) {
      final isVideo = url.toLowerCase().contains('.mp4') ||
          url.toLowerCase().contains('.mov') ||
          url.toLowerCase().contains('.webm');
      return <String, dynamic>{
        'media_type': isVideo ? 'video' : 'image',
        'url': url,
        'thumbnail_url': isVideo ? url : url,
      };
    }).toList();

    try {
      await DynamicApi().createPost(
        content: content,
        mediaList: mediaList,
        visibility: _privateOnly ? 'private' : 'public',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: ${e.toString()}')),
        );
      }
    }
  }

  void _showMentionPicker() async {
    final height = MediaQuery.of(context).size.height * 0.8;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _MentionSheetContent(
          initialSelected: List.from(_mentions),
          onConfirm: (selected) => Navigator.pop(context, selected),
        ),
      ),
    );
    if (result != null && mounted) {
      final prevIds = _mentions.map((m) => (m['userId'] as num?)?.toInt()).whereType<int>().toSet();
      setState(() {
        _mentions
          ..clear()
          ..addAll(result);
        // 像 DeBox 动态：将 @昵称 插入到内容中
        for (final m in result) {
          final uid = (m['userId'] as num?)?.toInt();
          if (uid != null && !prevIds.contains(uid)) {
            final name = m['username'] as String? ?? '用户';
            final suffix = _contentController.text.isEmpty ? '' : ' ';
            _contentController.text += '$suffix@$name';
            _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
          }
        }
      });
    }
  }

  void _showTopicPicker() async {
    final height = MediaQuery.of(context).size.height * 0.8;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _TopicSheetContent(
          initialSelected: List.from(_topics),
          onConfirm: (selected) => Navigator.pop(context, selected),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _topics
        ..clear()
        ..addAll(result));
    }
  }

  void _showTokenPicker() {
    _showPickerSheet('选择代币', '搜索代币名称');
  }

  void _showPickerSheet(String title, String hint) {
    final height = MediaQuery.of(context).size.height * 0.8;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _PlaceholderSheetContent(title: title, hint: hint),
      ),
    );
  }

  void _showSettings() {
    FocusScope.of(context).unfocus(); // 收起键盘
    setState(() => _showSettingsSection = !_showSettingsSection);
  }

  bool _showSettingsSection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? '编辑动态' : '发布动态',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _publish,
            child: Text(_isEdit ? '保存' : '发布', style: const TextStyle(fontSize: 16, color: Color(0xFF00D1A7), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // 内容区（可滚动）
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _contentController,
                      minLines: 5,
                      maxLines: null,
                      maxLength: _maxContentLength,
                      inputFormatters: [
                        _MentionDeleteFormatter(onMentionDeleted: (deleted) {
                          final name = deleted.startsWith('@') ? deleted.substring(1) : deleted;
                          setState(() {
                            _mentions.removeWhere((m) => (m['username'] as String? ?? '') == name);
                          });
                        }),
                      ],
                      decoration: const InputDecoration(
                        hintText: '请输入描述内容',
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.6),
                      onChanged: (_) => setState(() {}),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_contentController.text.length}/$_maxContentLength',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    if (_topics.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _topics.map((t) {
                          final name = t['name'] as String? ?? '话题';
                          return Chip(
                            label: Text('#$name', style: const TextStyle(fontSize: 13)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _topics.remove(t)),
                            backgroundColor: const Color(0xFF00D1A7).withOpacity(0.2),
                          );
                        }).toList(),
                      ),
                    ],
                    if (_mediaPaths.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_mediaPaths.length, (i) {
                          final path = _mediaPaths[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: path.startsWith('http')
                                      ? Image.network(
                                          path,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey[300],
                                            child: Icon(Icons.play_circle_outline, size: 32, color: Colors.grey[600]),
                                          ),
                                        )
                                      : Image.file(File(path), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // 底部操作栏（固定在底部，键盘弹出时在其上方）
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _bottomBarItem(Icons.photo_library_outlined, '选择图片视频', _pickMedia),
                    const SizedBox(width: 8),
                    _bottomBarItem(Icons.alternate_email, '提醒谁看', _showMentionPicker),
                    const SizedBox(width: 8),
                    _bottomBarItem(Icons.tag, '话题', _showTopicPicker),
                    const SizedBox(width: 8),
                    _bottomBarItem(Icons.currency_bitcoin, '虚拟币', _showTokenPicker),
                    const SizedBox(width: 8),
                    _bottomBarItem(Icons.settings_outlined, '设置', _showSettings),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // 设置面板（在操作栏下方，点击设置时收起键盘并展示，替代键盘区域，固定在底部）
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _showSettingsSection
                  ? Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSettingRow(
                              '打赏',
                              '开启后,将允许任何人打赏此动态',
                              _allowRewards,
                              (v) => setState(() => _allowRewards = v),
                            ),
                            const SizedBox(height: 16),
                            _buildSettingRow(
                              '仅自己可见',
                              '开启后,仅自己可以看见此动态',
                              _privateOnly,
                              (v) => setState(() => _privateOnly = v),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBarItem(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00D1A7),
        ),
      ],
    );
  }
}

/// 退格时整段删除 @昵称（如 DeBox 动态）
class _MentionDeleteFormatter extends TextInputFormatter {
  final void Function(String deletedMention)? onMentionDeleted;

  _MentionDeleteFormatter({this.onMentionDeleted});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length >= oldValue.text.length) return newValue;
    if (oldValue.text.length - newValue.text.length != 1) return newValue;

    final cursor = oldValue.selection.baseOffset;
    if (cursor <= 0) return newValue;

    final beforeCursor = oldValue.text.substring(0, cursor);
    final match = RegExp(r'@[^\s]+$').firstMatch(beforeCursor);
    if (match != null) {
      final deleted = match.group(0)!;
      onMentionDeleted?.call(deleted);
      final newText = oldValue.text.substring(0, match.start) + oldValue.text.substring(cursor);
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: match.start),
      );
    }
    return newValue;
  }
}

/// 提醒谁看弹窗：我关注的人列表，多选（排版与创建群组选择成员一致，不显示「我的关注」）
class _MentionSheetContent extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelected;
  final void Function(List<Map<String, dynamic>>) onConfirm;

  const _MentionSheetContent({
    required this.initialSelected,
    required this.onConfirm,
  });

  @override
  State<_MentionSheetContent> createState() => _MentionSheetContentState();
}

class _MentionSheetContentState extends State<_MentionSheetContent> {
  List<Map<String, dynamic>> _list = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final m in widget.initialSelected) {
      final id = m['userId'];
      if (id != null) _selectedIds.add(id is num ? id.toInt() : id as int);
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 从 getFollowerList(type:1) 接口解析「我关注的人」列表
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await UserApi().getFollowerList({'type': 1});
      final raw = (resp['data'] ?? resp['list']) as List<dynamic>? ?? [];
      final list = raw.map((e) {
        final m = e as Map<String, dynamic>;
        final uid = m['userId'] ?? m['user_id'];
        final userId = uid is num ? uid.toInt() : (uid as int? ?? 0);
        return {
          'userId': userId,
          'username': m['username'] ?? m['name'] ?? m['nickname'] ?? '匿名用户',
          'avatar_url': m['avatar_url'] ?? m['avatar'] ?? '',
          'wallet_address': m['wallet_address'] ?? m['address'] ?? '',
        };
      }).toList();
      if (mounted) {  
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredList {
    final kw = _searchController.text.trim().toLowerCase();
    if (kw.isEmpty) return _list;
    return _list.where((m) {
      final name = (m['username'] as String? ?? '').toLowerCase();
      final addr = (m['wallet_address'] as String? ?? '').toLowerCase();
      return name.contains(kw) || addr.contains(kw);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text('提醒谁看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        // 搜索框（与创建群组一致）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索用户备注、名称或地址',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('加载失败: $_error', style: TextStyle(color: Colors.red[700])))
                  : _filteredList.isEmpty
                      ? Center(child: Text('暂无关注的人', style: TextStyle(color: Colors.grey[600])))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          itemCount: _filteredList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                          itemBuilder: (_, i) {
                            final m = _filteredList[i];
                            final userId = (m['userId'] as num?)?.toInt() ?? 0;
                            final name = m['username'] as String? ?? '匿名';
                            final avatar = m['avatar_url'] as String? ?? '';
                            final addr = m['wallet_address'] as String? ?? '';
                            final checked = _selectedIds.contains(userId);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (checked) {
                                    _selectedIds.remove(userId);
                                  } else {
                                    _selectedIds.add(userId);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: avatar.isNotEmpty
                                          ? Image.network(
                                              avatar,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                                            )
                                          : _buildAvatarPlaceholder(),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                          if (addr.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              truncateString(addr),
                                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: checked ? const Color(0xFF00D29D) : Colors.transparent,
                                        border: Border.all(
                                          color: checked ? const Color(0xFF00D29D) : Colors.grey[400]!,
                                          width: 2,
                                        ),
                                      ),
                                      child: checked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final selected = _list.where((m) => _selectedIds.contains(m['userId'])).toList();
                widget.onConfirm(selected);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00D1A7)),
              child: const Text('完成'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white, size: 28),
      );
}

/// 话题选择弹窗
class _TopicSheetContent extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelected;
  final void Function(List<Map<String, dynamic>>) onConfirm;

  const _TopicSheetContent({
    required this.initialSelected,
    required this.onConfirm,
  });

  @override
  State<_TopicSheetContent> createState() => _TopicSheetContentState();
}

class _TopicSheetContentState extends State<_TopicSheetContent> {
  List<Map<String, dynamic>> _list = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final t in widget.initialSelected) {
      final id = t['id'] as int?;
      if (id != null) _selectedIds.add(id);
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await DynamicApi().getTopicList(keyword: keyword);
      final raw = resp['data'] as List<dynamic>? ?? [];
      final list = raw.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id': m['id'] ?? m['topic_id'] ?? 0,
          'name': m['name'] ?? m['topic_name'] ?? '',
        };
      }).toList();
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredList {
    final kw = _searchController.text.trim().toLowerCase();
    if (kw.isEmpty) return _list;
    return _list.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      return name.contains(kw);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text('选择话题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索话题',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('加载失败: $_error', style: TextStyle(color: Colors.red[700])))
                  : _filteredList.isEmpty
                      ? Center(child: Text('暂无话题', style: TextStyle(color: Colors.grey[600])))
                      : ListView.builder(
                          itemCount: _filteredList.length,
                          itemBuilder: (_, i) {
                            final m = _filteredList[i];
                            final id = m['id'] as int? ?? 0;
                            final name = m['name'] as String? ?? '';
                            final checked = _selectedIds.contains(id);
                            return ListTile(
                              title: Text(name.isEmpty ? '话题$id' : name),
                              trailing: Checkbox(
                                value: checked,
                                onChanged: (_) {
                                  setState(() {
                                    if (checked) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF00D1A7),
                              ),
                              onTap: () {
                                setState(() {
                                  if (checked) {
                                    _selectedIds.remove(id);
                                  } else {
                                    _selectedIds.add(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final selected = _list.where((m) => _selectedIds.contains(m['id'])).toList();
                widget.onConfirm(selected);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00D1A7)),
              child: const Text('完成'),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部弹窗内容（代币占位，高度占屏幕 80%）
class _PlaceholderSheetContent extends StatelessWidget {
  final String title;
  final String hint;

  const _PlaceholderSheetContent({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Text('$title 列表待接入接口', style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      ],
    );
  }
}

/// 占位页（提醒谁看、话题、代币待接入真实接口）
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String hint;

  const _PlaceholderPage({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('发布', style: TextStyle(color: Color(0xFF00D1A7))),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Text('$title 列表待接入接口', style: TextStyle(color: Colors.grey[600])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
