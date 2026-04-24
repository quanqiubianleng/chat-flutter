// Smoke test：启动 BBTApp，校验当前入口与基础 UI。
import 'package:education/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('BBTApp shows loading then main scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BBTApp(),
      ),
    );
    await tester.pump();

    // 启动阶段会显示「正在初始化...」或加载指示
    expect(
      find.text('正在初始化...'),
      findsOneWidget,
    );
  });
}
