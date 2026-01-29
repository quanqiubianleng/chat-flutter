import 'package:education/pages/chat/group/group_nickname_edit.dart';
import 'package:education/pages/chat/group/group_report.dart';
import 'package:education/pages/chat/group/speak_frequency.dart';
import 'package:flutter/material.dart';

import 'package:education/config/app_config.dart';
import 'package:education/modules/chat/models/friend.dart';
import 'package:education/modules/chat/models/group.dart';
import 'package:education/services/group_service.dart';
import 'package:education/widgets/chat/group/add_group_member.dart';
import 'package:education/widgets/chat/group/group_avatar.dart';
import 'package:education/widgets/chat/group/remove_group_member.dart';
import 'package:education/widgets/common/plus_minus.dart';
import '../../../core/global.dart';
import '../../../core/utils/conversation.dart';
import '../../../core/websocket/ws_event.dart';
import '../../../pb/protos/chat.pb.dart' as pb;
import '../../../providers/chat_providers.dart';
import '../../../widgets/chat/group/group_manager_handle.dart';
import '../../user/user_info.dart';
import 'package:education/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';

import 'group_announcement.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  final int groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  bool _newMemberNotify = true; // 新成员加入提醒
  bool _muteNotifications = false; // 消息免打扰
  bool _pinChat = false;  // 置顶
  bool _isMute = false;  // 全员禁言
  bool _restrictAddFriend = false;  // 禁止群成员互加好友

  int page = 1;
  int pageSize = 100;

  late final GroupApi api;
  // 朋友列表
  List<Friend> memberList = [];
  List<String> groupAvatar = [];

  late int role = 0;
  late int total = 0;
  late String _avatar = "";
  bool isLoading = true;        // 加载中
  bool hasError = false;        // 是否出错
  String? errorMessage;
  GroupInfo? groupInfo;
  String? nicknameInGroup;
  int? _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    api = GroupApi();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 第一次進入時才執行（避免重複呼叫）
    if (groupInfo == null) {
      _getGroupInfo();
      _loadMembers();
    }
  }

  // 获取群组信息
  Future<void> _getGroupInfo() async {
    // 当前用户
    final currentUid = ref.watch(userProvider.select((value) => value.value));
    try {
      final response = await api.getGroupInfo({"group_id": widget.groupId});

      print("_getGroupInfo response");
      print(response);

      final GroupInfo info = GroupInfo.fromJson(response);
      String cAvatar = info.Avatar;
      if(info.Avatar.isNotEmpty && info.Avatar.contains("、")){
        cAvatar = "";
      }

      setState(() {
        groupInfo = info;
        _avatar = cAvatar;
        _isMute = info.isMute == 1;
        _restrictAddFriend = info.restrictAddFriend == 1;
        _newMemberNotify = info.showNewMemberTip == 0;
        _currentUserId = currentUid;
      });
    } catch (e, stackTrace) {
      print("_getGroupInfo error: $e");
      print(stackTrace);
    }
  }

  // 获取群成员
  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await api.getGroupMembers({"group_id": widget.groupId, "page": page, "page_size": pageSize});
      String? nickname = ref.read(myNicknameProvider).value;

      print("loadFriends response");
      print(response);
      if(response['nickname_in_group'] != ""){
        nickname = response['nickname_in_group'];
      }

      final List<dynamic> rawList = response['data'] ?? [];

      final List<Friend> members = rawList
          .map((item) => Friend.fromJson(item as Map<String, dynamic>))
          .toList();
      final List<String> avatars = rawList
          .take(9)                      // 只取前 9 个元素
          .map((item) => item['avatar_url'] as String? ?? '')  // 安全取值 + 默认空字符串
          .toList();
      print(avatars);
      members.sort((a, b) => a.username.compareTo(b.username));

      setState(() {
        memberList = members;
        role = response['role'];
        total = response['total'];
        nicknameInGroup = nickname!;
        groupAvatar = avatars;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print("loadFriends error: $e");
      print(stackTrace);

      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  // 禁言
  Future<void> _handleSwitch(String req, bool status) async {

    List<String> fields = [];
    fields.add("group_id");
    fields.add(req);
    Map<String, dynamic> params = {
      "group_id": widget.groupId,
      req: status ? 0 : 1,
      "field":  fields
    };
    try {
      final response = await api.updateGroupInfo(params);

      print("_updateGroupInfo");
      print(response);
      if(response['code'] == HttpStatus.success){
        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        final convID = generateTempConversationId(userIdA: 0, userIdB: widget.groupId, isGroup: true);
        final content = status ? "取消全员禁言" : "开启全员禁言";
        final type = status ? WSEventType. groupClearMute: WSEventType.groupMute;
        final tempMessage = pb.Event()
          ..clientMsgId = tempClientMsgId
          ..fromUser = Int64(_currentUserId!)
          ..toUser = Int64(widget.groupId)
          ..conversationId = convID
          ..groupId =  Int64(widget.groupId)
          ..delivery = WSDelivery.group
          ..type = type
          ..content = content
          ..timestamp = Int64(tempTimestamp)
          ..status = WSMessageStatus.sending;
        print(tempMessage);
        // 保存到本地数据库 → 触发 Riverpod 实时更新 UI
        await ref.read(messageRepositoryProvider).saveMessage(tempMessage);
        // 发送消息
        ws.send(tempMessage);

        // 模拟保存成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg']),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          if(req == "is_mute"){
            _isMute = !_isMute;
          }
          if(req == "show_new_member_tip"){
            _newMemberNotify = !_newMemberNotify;
          }
          if(req == "restrict_add_friend"){
            _restrictAddFriend = !_restrictAddFriend;
          }

        });
        return;
      }
      // 模拟保存失败
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['msg']),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (groupInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('聊天設置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          const Divider(height: 1),
          // 頭像選擇區域
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 16, right: 16),
            color: Colors.white,
            child: GridView.count(
              shrinkWrap: true,           // 重要！讓它只佔所需高度
              physics: const NeverScrollableScrollPhysics(), // 禁止內部滾動
              crossAxisCount: 5,          // ★ 每行放幾個就改這裡 (建議4或5)
              mainAxisSpacing: 10,        // 垂直間距
              crossAxisSpacing: 10,       // 水平間距
              childAspectRatio: 0.75,      // 正方形比例
              children: [
                // 动态渲染成员头像（最多显示前 N 个，剩余用“查看更多”）
                ...memberList.take(7).map((friend) => _buildAvatarOption(
                  friend.avatarUrl ?? 'https://example.com/default-avatar.png', // 默认头像
                  friend.username.length > 6
                      ? '${friend.username.substring(0, 5)}...'
                      : friend.username, friend.userId
                )),

                // role > 0 时显示添加/移除按钮（群主/管理员权限）
                if (role > 0) ...[
                  _buildAddAvatarButton(),
                  _buildRemoveAvatarButton(),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(
              child: Text(
                '查看更多($total) >',
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ),
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200],),

          // 群資料相關
          _buildListTile(
            title: '群资料',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if(_avatar == "") GroupAvatar(avatarUrls: groupAvatar),
                if(_avatar != "") Image.network(
                  groupInfo!.Avatar,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // 加载失败时的占位图（建议加上）
                    return Image.asset('assets/images/default_avatar.png');
                  },
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupEditPage(
                    groupId: widget.groupId,
                    role: role,
                    name: groupInfo!.Name,
                    avatar: groupInfo!.Avatar,
                    description: groupInfo!.description != "" ? groupInfo!.description : 'MOD很懒，还沒有设置简介哦~',
                    onSaved: _getGroupInfo,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '简介',
            subtitle: groupInfo!.description != "" ? groupInfo!.description : 'MOD很懒，还沒有设置简介哦~',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '公告',
            subtitle: groupInfo!.notice != "" ? groupInfo!.notice : 'MOD很懶，还沒有设置简介哦~',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupAnnouncementEditor(
                    groupId: widget.groupId,
                    role: role,
                    notice: groupInfo!.notice != "" ? groupInfo!.notice : 'MOD很懒，还沒有设置公告哦~',
                    onSaved: _getGroupInfo,
                  ),
                ),
              );
            },
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200]),

          // 開關類設定
          _buildSwitchTile(
            title: '启用开票',
            subtitle: '成员可通过该功能反馈',
            value: false,
            onChanged: (v) => {
              if(role > 0){

              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: '新成员加入提醒',
            value: _newMemberNotify,
            onChanged: (v) => {
              if(role > 0){
                _handleSwitch("show_new_member_tip", _newMemberNotify),
              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: '全员禁言',
            value: _isMute,
            onChanged: (v) => {
              if(role > 0){
                _handleSwitch("is_mute", _isMute),
              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: '群內加好友限制',
            subtitle: '开启后，群成员之间不能互加好友，mod不受影响。',
            value: _restrictAddFriend,
            onChanged: (v) => {
              if(role > 0){
                _handleSwitch("restrict_add_friend", _restrictAddFriend),
              }
            },
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200]),

          // 其他可點擊項目
          _buildListTile(
            title: '进群设置',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if(groupInfo!.joinMode == 0) const Text('无条件', style: TextStyle(color: Colors.grey, fontSize: 13)),
                if(groupInfo!.joinMode == 1) const Text('需审核', style: TextStyle(color: Colors.grey, fontSize: 13)),
                if(groupInfo!.joinMode == 2) const Text('持仓门控(Token/NFT)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                if(groupInfo!.joinMode == 3) const Text('邀请制', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {},
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '发言頻率',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if(groupInfo!.speakFrequencyLimit == 0) Text('不限制', style: TextStyle(color: Colors.grey, fontSize: 13)),
                if(groupInfo!.speakFrequencyLimit > 0) Text('${groupInfo!.speakFrequencyLimit}s', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpeakFrequencyPage(
                    groupId: groupInfo!.groupId,
                    currentLimit: groupInfo!.speakFrequencyLimit,
                    onConfirm: _getGroupInfo,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),

          _buildSwitchTile(
            title: '自动刪除',
            value: false,
            onChanged: (v) => {
              if(role > 0){

              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '成员角色管理',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupManagerHandle(
                    groupId: widget.groupId,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '群容量',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${groupInfo!.maxMembers}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Icon(Icons.chevron_right),
              ],
            ),
            subtitle: '任何人可花費BBT進行扩容',
            onTap: () {},
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200]),

          _buildListTile(
            title: '升級为Club',
            subtitle: '解锁更多公域流量',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200]),

          _buildSwitchTile(
            title: '置頂',
            value: _pinChat,
            onChanged: (v) => {
              if(role > 0){
                setState(() => _pinChat = v)
              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: '消息免打扰',
            value: _muteNotifications,
            onChanged: (v) => {
              if(role > 0){
                setState(() => _muteNotifications = v)
              }
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '我在本群的昵称',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(nicknameInGroup ?? '未設定', style: TextStyle(color: Colors.grey, fontSize: 13),),
                Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {},
          ),
          Divider(height: 12, thickness: 8, color: Colors.grey[200]),
          _buildListTile(
            title: '举报',
            trailing: const Icon(Icons.chevron_right),
            textColor: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupReportPage(
                    groupId: groupInfo!.groupId,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
          _buildListTile(
            title: '清除历史消息',
            trailing: const Icon(Icons.chevron_right),
            textColor: Colors.red,
            onTap: () {},
          ),

          Divider(height: 12, thickness: 8, color: Colors.grey[200]),
          Center(
            child: TextButton(
              onPressed: () {
                // 退出群邏輯
              },
              child: const Text(
                '退出',
                style: TextStyle(color: Colors.red, fontSize: 17),
              ),
            ),
          ),

          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildAvatarOption(String imageUrl, String text, int userId) {
    return GestureDetector(
        onTap: () {
          // TODO: 跳转个人信息页
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserInfo(
                userId: userId,
                // 你可以根据需要传更多字段
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片容器
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey[200], // 固定背景色
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8), // 比容器小2px
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 24,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                )
                    : Center(
                  child: Icon(
                    Icons.person,
                    size: 28,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 文字标签
            Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        )
    );
  }

  Widget _buildAddAvatarButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddGroupMember(groupId: widget.groupId,onSaved: _loadMembers,),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: const Icon(Icons.add, size: 32, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(''),
        ],
      )
    );
  }

  Widget _buildRemoveAvatarButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RemoveGroupMember(groupId: widget.groupId,onSaved: _loadMembers,),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: const Icon(Icons.remove, size: 32, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(''),
        ],
      )
    );
  }

  Widget _buildListTile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.black87),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      )
          : null,
      trailing: trailing, 
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile({required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged,}) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      inactiveTrackColor: Colors.grey.shade200,     // 關閉時軌道顏色（淡一點）
      inactiveThumbColor: Colors.grey[350],     // 關閉時拇指顏色（淡一點）
      // 關鍵：控制邊框顏色（track outline）
      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}