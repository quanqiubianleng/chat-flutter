# lib 目录说明

## 结构约定

- **config/**：应用配置（环境、URL、常量）。
- **core/**：核心能力：数据库、WebSocket、缓存、工具类、通知等。
- **message_handler/**：消息处理（单聊、群聊、广播）。
- **modules/**：按功能划分的模块，每个模块内包含 `models/`、`providers/`、`screens/` 等。
- **navigation/**：主导航（如底部 Tab 脚手架）。
- **pages/**：顶层页面/路由对应的页面，直接供导航使用。
- **providers/**：全局或跨页面的 Riverpod Provider。
- **services/**：API 封装（HTTP 请求）。
- **widgets/**：可复用 UI 组件。

## modules 与 pages 的关系

- **modules/**：按业务域组织（如 chat、education），内含该域的数据模型、状态、屏幕；适合复用到多入口。
- **pages/**：当前应用内实际用到的「页面」入口，会引用 modules 或 providers，并挂到导航上。

命名与导入建议：文件名使用 **snake_case**，导入统一使用 **package:education/...**。
