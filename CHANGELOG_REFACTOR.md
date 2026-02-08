# 本次修改清单（P0 / P1 / P2）

以下为已完成的修改，可按模块确认或回滚。

---

## P0：配置 - 环境/URL 按环境配置

| 修改项 | 文件/位置 | 说明 |
|--------|-----------|------|
| 新增环境枚举与配置 | `lib/config/app_env.dart` | `AppEnv`（dev/staging/prod）、`EnvConfig`、`currentEnv`，URL 按环境区分 |
| 配置改为运行时读取 | `lib/config/app_config.dart` | `reqUrl`/`agreeUrl`/`privacyUrl` 改为 `late`，在 `init()` 中从 `currentEnv` 赋值；`getWsUrl()` 使用 `currentEnv.wsUrl` |
| 示例环境文件 | `.env.example` | 仅作说明，实际环境通过 `--dart-define=ENV=dev|staging|prod` 传入 |

**使用方式**：  
- 开发：`flutter run`（默认 ENV=dev）  
- 预发/生产：`flutter run --dart-define=ENV=staging` 或 `--dart-define=ENV=prod`  
- 构建：`flutter build apk --dart-define=ENV=prod`

---

## P1：依赖与资源

| 修改项 | 文件/位置 | 说明 |
|--------|-----------|------|
| 移除未使用依赖 | `pubspec.yaml` | 删除 `provider: ^6.1.5+1`（项目仅用 Riverpod） |
| 补充资源声明 | `pubspec.yaml` → `flutter.assets` | 增加 `assets/icon/` |
| 忽略敏感文件 | `.gitignore` | 增加 `.env`、`.env.*`、`!.env.example`、`secrets.*` |

---

## P1：代码质量

| 修改项 | 文件/位置 | 说明 |
|--------|-----------|------|
| 统一 Logger | `lib/core/utils/logger.dart` | 实现 `AppLogger.d/i/w/e`，release 下仅 e 输出 |
| 用 Logger 替代 print | `lib/main.dart`、`lib/navigation/main_tab_scaffold.dart`、`lib/services/api_service.dart`（CURL）、`lib/widgets/chat/voice_bubble.dart`、`lib/widgets/follower/community_post_card.dart`、`official_reward_card.dart` | 上述文件中 `print` 已改为 `AppLogger`；**其余约 50 个文件中的 print 可后续逐步替换** |
| CURL 仅 debug 打印 | `lib/services/api_service.dart` | 仅在 `AppConfig.isDebug` 时打印 CURL，避免生产泄露 |
| 统一 package 导入 | `lib/main.dart`、`lib/core/global.dart`、`lib/providers/chat_providers.dart`、`lib/services/user_service.dart`、`lib/services/group_service.dart`、`lib/services/public_service.dart`、`lib/core/sqlite/database_helper.dart`、`lib/navigation/main_tab_scaffold.dart`、`lib/pages/market/market_feed_page.dart`、`lib/widgets/chat/voice_bubble.dart` | 相对路径改为 `package:education/...` |
| 死代码删除 | `lib/providers/chat_providers.dart` | 删除 `if (db == null) throw ...`（`Global.db` 已保证非 null） |
| 空 catch 补日志 | `lib/widgets/chat/voice_bubble.dart` | `catch (_) {}` 改为 `catch (e, st) { AppLogger.w(...); }` |
| API 统一错误与 null 处理 | `lib/services/api_service.dart` | 新增 `ApiClient.getDataOrThrow(resp)`、`ApiException`；响应为空或 `_error==true` 时抛异常 |
| API 调用方使用 getDataOrThrow | `lib/services/user_service.dart`、`lib/services/group_service.dart`、`lib/services/public_service.dart` | 所有 `return resp.data` 改为 `return ApiClient.getDataOrThrow(resp)` |
| baseUrl 运行时读取 | `lib/services/api_service.dart` | `baseUrl` 从 `AppConfig.reqUrl` 在运行时读取（配合 P0 多环境） |
| main 异常区分 | `lib/main.dart` | 区分 `ApiException` 与 `DioException`，分别打日志 |

---

## P2：结构与命名

| 修改项 | 文件/位置 | 说明 |
|--------|-----------|------|
| 删除重复/备份文件 | 已删除 | `lib/pages/profile/profile_page copy.dart`、`lib/pages/chat/single_chat1.dart`、`lib/pages/chat/group/group_chat1.dart`、`lib/providers/chat_providers1.dart`、`lib/core/websocket/ws_service1.dart`（均无引用） |
| 文件名改为 snake_case | `lib/widgets/follower/` | `CommunityPostCard.dart` → `community_post_card.dart`，`DeBoxFloatingMenu.dart` → `debox_floating_menu.dart`，`OfficialRewardCard.dart` → `official_reward_card.dart`；引用已在 `market_feed_page.dart` 中更新 |
| modules vs pages 说明 | `lib/README.md` | 新增目录说明：modules 按业务域、pages 为顶层页面入口 |

---

## P2：测试

| 修改项 | 文件/位置 | 说明 |
|--------|-----------|------|
| 修正 widget 测试入口 | `test/widget_test.dart` | 使用 `DeBoxApp` + `ProviderScope`，断言「正在初始化...」存在 |
| 环境配置单测 | `test/config/app_env_test.dart` | 校验 `currentEnv` 各字段非空、dev 为 debug、prod 非 debug |
| API 异常单测 | `test/services/api_exception_test.dart` | 校验 `ApiException` 的 message 与 toString |

---

## 运行与验证建议

1. **环境**：在项目根目录执行 `flutter pub get`（已移除 provider，需拉取最新依赖）。
2. **分析**：`flutter analyze`。
3. **测试**：`flutter test`（含 widget_test、app_env_test、api_exception_test）。
4. **按环境运行**：`flutter run --dart-define=ENV=staging` 等。

如需**回滚**某一块，可按上表对应文件用 Git 还原或说明要还原的模块，我再按模块给出回滚步骤。
