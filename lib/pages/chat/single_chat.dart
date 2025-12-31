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



class DeBoxChatPage extends ConsumerStatefulWidget {
  final String chatId;        // conversationId（可以是 int 或 String）
  final String chatName;
  final Int64 toUser;         // 单聊时用，群聊可传 0
  final bool isGroup;

  const DeBoxChatPage({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.toUser,
    this.isGroup = false,
  }) : super(key: key);

  @override
  ConsumerState<DeBoxChatPage> createState() => _DeBoxChatPageState();
}

class _DeBoxChatPageState extends ConsumerState<DeBoxChatPage> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _toUserId = 0; // 定义为成员变量
  int _currentUserId = 0; // 存储当前用户ID
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // 初始化用户数据的方法
  Future<void> _initializeUserData() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // 获取当前用户ID
      final uidAsync = await ref.read(userProvider.future);
      _currentUserId = uidAsync!;

      // 计算 toUser
      _toUserId = widget.toUser.toInt();
      if (widget.toUser.toInt() == 0 && widget.chatId.isNotEmpty) {
        _toUserId = getUserIDsByConversationId(widget.chatId, _currentUserId!);
      }

      print('初始化完成: currentUserId=$_currentUserId, toUserId=$_toUserId');

      // 初始化完成后刷新UI
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isInitializing = false;
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
    final convID = generateTempConversationId(isGroup: widget.isGroup, userIdA: _toUserId, userIdB: currentUid!);


    final tempMessage = pb.Event()
      ..clientMsgId = tempClientMsgId
      ..fromUser = Int64(currentUid)
      ..toUser = Int64(_toUserId)
      ..conversationId = widget.chatId != "" ? widget.chatId : convID
      ..delivery = widget.isGroup ? WSDelivery.group : WSDelivery.single
      ..type = _mapToWSEventType(type)
      ..content = text.trim()
      ..timestamp = Int64(tempTimestamp)
      ..senderNickname = widget.chatName
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
    print(Int64(_toUserId));
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
      case 'image':
        return WSEventType.image;
      case 'video':
        return WSEventType.video;
      case 'voice':
        return WSEventType.voice;
      case 'file':
        return WSEventType.file;
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
    final currentUid = ref.watch(userProvider.select((value) => value.value));

    // 如果正在初始化，显示加载中
    if (_currentUserId == 0 || _toUserId == 0 || currentUid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String convID = generateTempConversationId(isGroup: widget.isGroup, userIdA: _toUserId, userIdB: currentUid!);
    if(widget.chatId != ""){
      convID = widget.chatId;
    }

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
          widget.chatName,
          style: const TextStyle(color: Color.fromARGB(255, 56, 55, 55)),
        ),
        leading: const BackButton(color: Color.fromARGB(255, 56, 55, 55)),
        actions: const [
          Icon(Icons.more_vert, color: Color.fromARGB(255, 56, 55, 55)),
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
                        // 可选：播放语音等
                        // onPlayAudio: () => _playAudio(message.mediaUrl),
                      );
                    },
                  ),
                );

              },
            ),
          ),

          // 输入栏
          ChatInputBar(
            onSendMessage: _sendMessage,
          ),
        ],
      ),
    );
  }
}