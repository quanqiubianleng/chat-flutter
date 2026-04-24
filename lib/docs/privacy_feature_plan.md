# DeBox 风格隐私功能 - 评估与实现方案

## 一、功能概述

在「设置」中已有「隐私」入口，需实现与参考图一致的完整隐私设置能力：

| 页面 | 内容 |
|------|------|
| **隐私（主列表）** | 我屏蔽的用户、谁可以私信我、谁可以邀请我入群、关注与粉丝列表、公开展示我的资产（开关） |
| **谁可以私信我** | 单选：任何人 / 我关注的人 / 我的朋友，带绿色勾选 |
| **谁可以邀请我入群** | 单选：全部 / 我关注的人 / 互相关注的人 / 禁止任何人邀请我；另加开关「邀请我入群时需要验证」 |
| **关注与粉丝列表** | 开关：隐藏我的关注列表、隐藏我的粉丝列表 |
| **我屏蔽的用户** | 列表页 + 增删管理（可先做列表与移除，添加可后续补） |

---

## 二、前端方案（Flutter）

### 2.1 入口与路由

- **入口**：`lib/pages/user/setting.dart` 中「隐私」项增加 `onTap`，跳转 `PrivacyPage`。
- **路由**：所有页面使用 `Navigator.push(MaterialPageRoute(...))`，与现有设置/支付与安全一致。

### 2.2 页面与布局（与参考图一致）

1. **隐私主页 `PrivacyPage`**
   - 白底、无左侧图标（与参考图一致），仅文字 + 右侧箭头/开关。
   - 列表项：我屏蔽的用户 →、谁可以私信我 →、谁可以邀请我入群 →、关注与粉丝列表 →、公开展示我的资产 [Switch]。
   - 项与项之间用 `Divider` 分隔，与现有设置页风格统一。

2. **谁可以私信我 `WhoCanPmPage`**
   - 标题「谁可以私信我」。
   - 三行：任何人、我关注的人、我的朋友；单选，选中项右侧绿色勾选图标。

3. **谁可以邀请我入群 `WhoCanInviteGroupPage`**
   - 标题「谁可以邀请我入群」。
   - 四行单选（主标题 + 副标题）：全部、我关注的人、互相关注的人、禁止任何人邀请我。
   - 下方独立一行：「邀请我入群时需要验证」+ 绿色 Switch。

4. **关注与粉丝列表 `FollowListPrivacyPage`**
   - 标题「关注与粉丝列表」。
   - 两行：隐藏我的关注列表 [Switch]、隐藏我的粉丝列表 [Switch]。

5. **我屏蔽的用户 `BlockedUsersPage`**
   - 标题「我屏蔽的用户」。
   - 列表展示已屏蔽用户（头像、昵称），支持移除屏蔽；空状态提示「暂无屏蔽用户」。
   - **屏蔽含义**：与 DeBox 一致，屏蔽 = **屏蔽私信（聊天）**。将用户加入黑名单后，对方无法给你发私信，你也不会收到其消息；在用户资料页可操作「屏蔽/取消屏蔽」并刷新列表。

### 2.3 数据流

- **拉取**：进入隐私主页时请求 `GET /v1/users/privacySettings`，得到当前所有隐私字段，各子页根据传入的初始值展示；子页修改后调用 `POST /v1/users/privacySettings`（或单项目更新接口），保存后返回上一页并可选刷新主页状态。
- **公开展示资产**：主列表上的 Switch 直接绑定接口返回的 `show_assets_publicly`，切换时调用更新接口。

### 2.4 文件结构建议

```
lib/pages/user/
  privacy_page.dart           # 隐私主页
  who_can_pm_page.dart        # 谁可以私信我
  who_can_invite_group_page.dart  # 谁可以邀请我入群
  follow_list_privacy_page.dart    # 关注与粉丝列表
  blocked_users_page.dart         # 我屏蔽的用户
lib/services/
  user_service.dart           # 新增 getPrivacySettings / updatePrivacySettings（及 blocked 相关）
```

---

## 三、后端方案（Go）

### 3.1 数据存储

- **现有**：`user` 表已有 `settings` 字段（JSON 字符串），当前存有 `intro`、`background_url` 等。
- **策略**：隐私配置放入同一 `settings` JSON，**不**新增表；更新隐私时只合并 privacy 相关 key，不覆盖 `intro`、`background_url` 等已有字段。

### 3.2 settings 中隐私字段约定

```json
{
  "intro": "...",
  "background_url": "...",
  "privacy": {
    "can_pm": "everyone|following|friends",
    "can_invite_to_group": "all|following|mutual|none",
    "group_join_verify": true,
    "show_assets_publicly": true,
    "hide_following_list": false,
    "hide_followers_list": false,
    "blocked_user_ids": [1, 2, 3]
  }
}
```

或与现有扁平结构兼容（与前端约定一致即可）：

```json
{
  "intro": "...",
  "background_url": "...",
  "can_pm": "everyone",
  "can_invite_to_group": "following",
  "group_join_verify": true,
  "show_assets_publicly": true,
  "hide_following_list": false,
  "hide_followers_list": false,
  "blocked_user_ids": [1, 2, 3]
}
```

建议采用**扁平结构**，便于与现有 `intro`、`background_url` 一致，合并时只更新隐私 key。

### 3.3 API 设计

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/v1/users/privacySettings` | 获取当前用户隐私设置（从 user.settings 解析并返回） |
| POST | `/v1/users/privacySettings` | 更新隐私设置（body 为部分字段即可；后端合并进 settings 后写库） |
| GET | `/v1/users/blockedUsers` | 获取屏蔽用户列表（含头像、昵称等简要信息） |
| POST | `/v1/users/blockUser` | 添加屏蔽（body: userId） |
| POST | `/v1/users/unblockUser` | 取消屏蔽（body: userId） |

- 所有接口需 **JWT 鉴权**，用户 ID 从 token 取。
- 若采用「合并写入」方案，需要在 users 服务内：先查当前 user.settings → 解析 JSON → 合并传入的 privacy 字段 → 再写回。

### 3.4 Gateway 与 Users 服务

- **gateway.api**：增加上述 5 个接口的请求/响应类型及路由（放在现有 user 组、JWT 中间件下）。
- **gateway**：生成 handler，并调用 users RPC（需在 users 的 proto 中增加 GetPrivacySettings、UpdatePrivacySettings、GetBlockedUsers、BlockUser、UnblockUser）。
- **users 服务**：
  - 实现上述 RPC：读/写 `user.settings`，合并逻辑在 users 内完成；屏蔽列表可存于 `blocked_user_ids`，GetBlockedUsers 根据 id 列表查 user 表或现有用户信息接口拼装返回。
  - 若暂时不建 `user_block` 表，则「屏蔽」仅用 settings 里的 `blocked_user_ids` 数组即可；后续若有性能或查询需求再拆表。

### 3.5 后端文件/模块

- **gateway**：`gateway.api` 类型与路由 → 生成 handler；在 `internal/logic/user/` 下新增 `getprivacysettingslogic.go`、`updateprivacysettingslogic.go`、`getblockeduserslogic.go`、`blockuserlogic.go`、`unblockuserlogic.go`（或合并为少量 handler）。
- **users**：proto 新增 5 个 RPC；`internal/logic` 下对应实现；若用 customUserModel，可在 `user_model_custom.go` 中增加 `GetSettings`、`UpdateSettingsMerged(ctx, userID, partialSettingsJSON)` 等，便于合并写。

---

## 四、页面布局与交互要点（与参考图一致）

- **导航**：所有子页 AppBar 左侧返回箭头、居中标题、白底。
- **列表**：白底、黑色/深灰主文案，右侧箭头或 Switch；Switch 使用绿色激活色（如 `#00D1A7` 或 Material 主色）。
- **谁可以私信我 / 谁可以邀请我入群**：单选列表，选中项右侧绿色勾选图标；谁可以邀请我入群带副标题说明。
- **关注与粉丝列表**：仅两个 Switch，关闭时为灰色。
- **我屏蔽的用户**：列表项展示头像+昵称，左滑或右侧按钮「移除」取消屏蔽。

---

## 五、实施顺序建议

1. **后端**  
   - 在 users 中实现 settings 的「按 key 合并」逻辑（或专用 UpdatePrivacySettings）。  
   - 实现 GetPrivacySettings、UpdatePrivacySettings、GetBlockedUsers、BlockUser、UnblockUser 的 RPC 与 gateway 接口。

2. **前端**  
   - 在 `user_service.dart` 中增加 `getPrivacySettings`、`updatePrivacySettings`、屏蔽相关接口调用。  
   - 实现 `PrivacyPage`（含公开展示资产 Switch）→ `WhoCanPmPage` → `WhoCanInviteGroupPage` → `FollowListPrivacyPage` → `BlockedUsersPage`。  
   - 在 `setting.dart` 为「隐私」增加 `onTap` 跳转 `PrivacyPage`。

3. **联调与校验**  
   - 校验各页与参考图一致（标题、选项文案、勾选与开关位置、颜色）。  
   - 校验保存后再次进入或刷新，状态正确；屏蔽列表增删正常。

---

## 六、枚举与默认值（前后端统一）

| 字段 | 可选值 | 默认 |
|------|--------|------|
| can_pm | everyone, following, friends | everyone |
| can_invite_to_group | all, following, mutual, none | all |
| group_join_verify | boolean | false |
| show_assets_publicly | boolean | true |
| hide_following_list | boolean | false |
| hide_followers_list | boolean | false |
| blocked_user_ids | number[] | [] |

前端展示文案与枚举值对应关系在常量或枚举中统一维护，避免硬编码。

---

按此方案可实现与参考图一致的 DeBox 风格隐私功能，前后端职责清晰，且复用现有 `user.settings` 存储，无需改表结构。
