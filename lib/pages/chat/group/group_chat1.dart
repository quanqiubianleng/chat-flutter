import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/widgets/chat/message_bubble.dart';
import 'package:education/widgets/chat/chat_input_bar.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';
import 'package:education/core/global.dart';
import 'package:education/providers/chat_providers.dart'; // 你的 Riverpod providers 文件
import 'package:education/providers/user_provider.dart';
import 'package:education/core/utils/conversation.dart';

import '../../../core/sqlite/user_repository.dart';
import '../../../modules/chat/models/group.dart';
import '../../../providers/group_provider.dart';
import '../../../services/group_service.dart';
import 'group_setting.dart';



class GroupChatPage extends ConsumerStatefulWidget {
  final String chatId;        // conversationId（可以是 int 或 String）

  const GroupChatPage({
    Key? key,
    required this.chatId,
  }) : super(key: key);

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final api = GroupApi();
  int _groupID = 0; // 群组ID
  String _groupTitle = "";
  late bool _isTalk = true;

  @override
  void initState() {
    super.initState();
    _initializeGroupData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // 初始化用户数据的方法
  Future<void> _initializeGroupData() async {
    final userRsp = UserRepository(Global.db);
    try {
      final groupID = getGroupIdByConversationId(widget.chatId);

      // 更新会话昵称
      final userInfo = await api.getGroupInfo({"group_id": groupID});
      final info = GroupInfo.fromJson(userInfo);
      print("userInfo");
      print(userInfo);
      if (info.Name != "") {
        await userRsp.updateUsername(groupID, info.Name, true);
      }
      if (info.Avatar != "") {
        await userRsp.updateAvatar(groupID, info.Avatar, true);
      }
      int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      bool isTalk = false;
      if((info.isMute == 0 && nowSeconds >= info.mutedUntil) || info.role > 0){
        isTalk = true;
      }
      setState(() {
        _groupID = groupID;
        _groupTitle = info.Name;
        _isTalk = isTalk;
      });
    } finally {

    }
  }

  /// 发送消息（乐观更新）
  Future<void> _sendMessage(String text, String type, String mediaUrl, {Map<String, dynamic>? extra,}) async {
    if (text.trim().isEmpty) return;


    // 用 Riverpod 获取当前 UID
    final uidAsync = await ref.read(userProvider.future);
    final currentUid = uidAsync;
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    // 1. 生成临时消息（乐观显示）
    final tempClientMsgId = const Uuid().v4();
    final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final groupID = getGroupIdByConversationId(widget.chatId);


    final tempMessage = pb.Event()
      ..clientMsgId = tempClientMsgId
      ..fromUser = Int64(currentUid)
      ..toUser = Int64(_groupID)
      ..conversationId = widget.chatId
      ..groupId = Int64(groupID)
      ..delivery = WSDelivery.group
      ..type = _mapToWSEventType(type)
      ..content = text.trim()
      ..timestamp = Int64(tempTimestamp)
      ..mediaUrl = mediaUrl
      ..extra = _encodeExtra(extra)
      ..status = WSMessageStatus.sending; // 可在 MessageBubble 中显示“发送中”


    // 保存到本地数据库 → 触发 Riverpod 实时更新 UI
    await ref.read(messageRepositoryProvider).saveMessage(tempMessage);

    // === 关键修复：发送消息后立即滚动到最新消息（底部）===
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,  // reverse: true 时，min 是底部
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // 2. 真正发送到服务器
    print("currentUid");
    print(currentUid);
    try {
      ws.send(tempMessage);
      // 成功后可更新 status 为 'sent'（监听 WebSocket ACK 可实现）
    } catch (e) {
      // 失败：更新本地消息 status 为 'failed'
      await ref.read(messageRepositoryProvider).updateMessageStatus(
        tempMessage.msgId,
        'failed',
      );
    }
  }

  /// 将 UI 类型映射为协议枚举
  String _mapToWSEventType(String type) {
    switch (type) {
      case WSEventType.image:
        return WSEventType.image;
      case WSEventType.video:
        return WSEventType.video;
      case WSEventType.voice:
        return WSEventType.voice;
      case WSEventType.file:
        return WSEventType.file;
      case WSEventType.redPacket:
        return WSEventType.redPacket;
      case WSEventType.transfer:
        return WSEventType.transfer;
      case 'text':
      default:
        return WSEventType.message;
    }
  }

  /// 将 Map<String, dynamic>? 转换为 protobuf 所需的 List<int>（bytes）
  List<int> _encodeExtra(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) {
      return <int>[];  // 返回空 List<int>
    }
    try {
      final jsonString = jsonEncode(extra);
      return utf8.encode(jsonString);  // 直接返回 List<int>，完美匹配 protobuf 的 bytes 字段
    } catch (e) {
      print('Extra 编码失败: $e');
      return <int>[];
    }
  }


  @override
  Widget build(BuildContext context) {
    // 禁言信息
    final muteStatus = ref.watch(groupMuteResultStreamProvider(_groupID));
    print("muteStatus");
    print(muteStatus);
    // 当前用户
    final currentUid = ref.watch(userProvider.select((value) => value.value));

    // 如果正在初始化，显示加载中
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String convID = widget.chatId;

    // 动态监听当前会话的消息
    final asyncMessages = ref.watch(messagesProvider(convID));


    // 监听消息变化，智能滚动到底部
    ref.listen<AsyncValue<List<pb.Event>>>(
      messagesProvider(convID),
          (previous, next) {
        // 只在有新消息且用户已经在底部附近时，才自动滚动到底部
        next.whenData((newList) {
          if (previous == null || previous.isLoading) {
            // 首次加载完成，直接跳到底部
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(_scrollController.position.minScrollExtent);
              }
            });
            return;
          }

          // 如果列表变长了（新消息到来）
          if (newList.length > (previous.valueOrNull?.length ?? 0)) {
            // 判断用户是否已经在底部（距离底部 < 100px）
            if (_scrollController.hasClients) {
              final position = _scrollController.position;
              final bool isNearBottom = position.pixels <= position.minScrollExtent + 100;

              if (isNearBottom) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollController.animateTo(
                    position.minScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            }
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _groupTitle,
          style: const TextStyle(color: Color.fromARGB(255, 56, 55, 55)),
        ),
        leading: const BackButton(color: Color.fromARGB(255, 56, 55, 55)),
        actions:  [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color.fromARGB(255, 56, 55, 55)),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -4), // ← 关键：压缩密度
            padding: EdgeInsets.zero,                                        // 去除按钮内边距
            constraints: const BoxConstraints(),                             // 去除最小48dp限制
            onPressed: () {
              // 处理更多按钮点击
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsPage(
                    groupId: _groupID,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.blur_circular, color: Color.fromARGB(255, 56, 55, 55)),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4), // ← 关键：压缩密度
            padding: EdgeInsets.zero,                                        // 去除按钮内边距
            constraints: const BoxConstraints(),                             // 去除最小48dp限制
            onPressed: () {
              // 处理更多按钮点击
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsPage(
                    groupId: _groupID,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color.fromARGB(255, 56, 55, 55)),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -4), // ← 关键：压缩密度
            padding: EdgeInsets.zero,                                        // 去除按钮内边距
            constraints: const BoxConstraints(),                             // 去除最小48dp限制
            onPressed: () {
              // 处理更多按钮点击
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsPage(
                    groupId: _groupID,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 240, 241, 241),
      body: Column(
        children: [
          Expanded(
            child: asyncMessages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('加载消息失败: $err')),
              data: (messageList) {
                if (messageList.isEmpty) {
                  return const Center(child: Text('暂无消息，开始聊天吧'));
                }

                print('=== 当前消息列表（旧→新） ===');
                for (var msg in messageList) {
                  print('id: ${msg.msgId} | from: ${msg.fromUser} | time: ${msg.timestamp} | content: ${msg.content}');
                }

                return GestureDetector(
                  // 点击空白区域或消息时，收起键盘
                  onTap: () {
                    // 收起键盘
                    FocusScope.of(context).unfocus();
                    // 可选：同时隐藏表情/媒体面板（更好体验）
                    // 如果你有控制这些的变量，可以在这里 setState 隐藏
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    reverse: true,  // 关键：倒置列表，新消息自然在底部
                    itemCount: messageList.length,
                    itemBuilder: (context, index) {
                      final message = messageList[messageList.length - 1 - index];
                      return MessageBubble(
                        message: message,
                        showTime: true,
                        // 可选：播放语音等
                        // onPlayAudio: () => _playAudio(message.mediaUrl),
                      );
                    },
                  ),
                );

              },
            ),
          ),

          // 输入区域（禁言时替换成提示条）
          muteStatus.when(
            data: (status) {
              print("status");
              print(status);
              if (!status.isMuted || _isTalk) {
                // 正常状态：显示输入栏
                return ChatInputBar(
                  isGroup: true,
                  toUserId: _groupID,
                  onSendMessage: _sendMessage,
                );
              }

              // ── 禁言状态：显示提示条 ──
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final remainingSec = status.muteUntil != null ? status.muteUntil! - now : null;

              String tipText;
              Color tipColor = Colors.orange[800]!;
              Color bgColor = Colors.orange[50]!;

              if (status.muteUntil == null) {
                // 永久禁言
                tipText = status.isAllMute ? "全员永久禁言中" : "你已被永久禁言";
                tipColor = Colors.red!;
                bgColor = Colors.white!;
              } else if (remainingSec != null && remainingSec > 0) {
                // 有时限禁言
                final days = (remainingSec / 86400).floor();
                final hours = (remainingSec / 3600).floor();
                final minutes = (remainingSec / 60).ceil();

                if (days >= 1) {
                  tipText = status.isAllMute
                      ? "全员禁言中 • 剩余 $days 天"
                      : "你已被禁言 • 剩余 $days 天";
                } else if (hours >= 1) {
                  tipText = status.isAllMute
                      ? "全员禁言中 • 剩余 $hours 小时"
                      : "你已被禁言 • 剩余 $hours 小时";
                } else {
                  tipText = status.isAllMute
                      ? "全员禁言中 • 剩余 $minutes 分钟"
                      : "你已被禁言 • 剩余 $minutes 分钟";
                }
              } else {
                // 理论上不会走到这里（因为 provider 已过滤过期），但做兜底
                tipText = status.isAllMute ? "全员禁言中" : "你已被禁言";
              }

              return Container(
                height: 56,  // 和 ChatInputBar 高度保持一致
                color: bgColor,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volume_off_rounded,
                      color: tipColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tipText,
                        style: TextStyle(
                          color: tipColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },

            loading: () => const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),

            error: (_, __) => const SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  "禁言状态加载中…",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}