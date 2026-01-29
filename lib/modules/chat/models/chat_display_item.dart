import 'package:education/pb/protos/chat.pb.dart'; // 你的 Event

sealed class ChatDisplayItem {}

class DateSeparator extends ChatDisplayItem {
  final String text;
  DateSeparator(this.text);
}

class MessageBubbleItem extends ChatDisplayItem {
  final Event message;
  final bool showTime;      // 是否显示气泡下面的具体时间
  final bool isFirstInGroup;// 是否是该5分钟组的第一条（可选，用于微调样式）

  MessageBubbleItem(this.message, {this.showTime = true, this.isFirstInGroup = false});
}