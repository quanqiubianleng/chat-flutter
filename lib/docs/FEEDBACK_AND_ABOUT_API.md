# 问题反馈与关于我们 - 后端 API 与数据表说明

本文档描述「问题反馈」「关于我们」功能所需的后端接口与数据库表结构，便于后端对接。

---

## 一、数据表设计

### 1. 用户反馈表 `user_feedback`

用于存储用户提交的问题反馈。

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | BIGINT PRIMARY KEY AUTO_INCREMENT | 主键 |
| user_id | BIGINT | 用户 ID（可选，未登录时为空） |
| email | VARCHAR(255) NOT NULL | 电子邮箱（必填） |
| content | TEXT NOT NULL | 反馈内容，建议限制 2000 字 |
| image_urls | JSON / TEXT | 图片 URL 列表，如 `["url1","url2"]` |
| status | TINYINT DEFAULT 0 | 处理状态：0 待处理，1 已处理，2 已关闭 |
| created_at | DATETIME DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| remark | VARCHAR(500) | 运营备注（内部使用） |

**索引建议**：`status`, `created_at`, `user_id`。

**建表示例（MySQL）**：

```sql
CREATE TABLE user_feedback (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT DEFAULT NULL,
  email VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  image_urls JSON DEFAULT NULL,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待处理 1已处理 2已关闭',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  remark VARCHAR(500) DEFAULT NULL,
  INDEX idx_status (status),
  INDEX idx_created_at (created_at),
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户问题反馈';
```

---

### 2. 更新日志表 `app_update_log`

用于「关于我们」-「更新日志」展示。

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | BIGINT PRIMARY KEY AUTO_INCREMENT | 主键 |
| version | VARCHAR(32) NOT NULL | 版本号，如 1.0.0 |
| release_date | DATE | 发布日期 |
| content | TEXT | 更新内容说明（支持多行/富文本） |
| platform | VARCHAR(16) | 可选：android / ios / all |
| sort_order | INT DEFAULT 0 | 排序，数值越大越靠前 |
| created_at | DATETIME DEFAULT CURRENT_TIMESTAMP | 创建时间 |

**建表示例（MySQL）**：

```sql
CREATE TABLE app_update_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  version VARCHAR(32) NOT NULL,
  release_date DATE DEFAULT NULL,
  content TEXT,
  platform VARCHAR(16) DEFAULT 'all',
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sort (sort_order DESC),
  INDEX idx_release_date (release_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应用更新日志';
```

---

### 3. 用户协议/应用文案表 `app_agreement`（可选）

若协议内容由后端动态下发（而非固定 H5 链接），可建此表。

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | BIGINT PRIMARY KEY AUTO_INCREMENT | 主键 |
| type | VARCHAR(32) NOT NULL | 类型：user_agreement / privacy_policy |
| version | VARCHAR(32) | 协议版本 |
| content | LONGTEXT | 正文（HTML 或 Markdown） |
| is_active | TINYINT DEFAULT 1 | 是否当前生效 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

当前客户端已支持通过配置的 `agreeUrl` / `privacyUrl` 在 WebView 中打开，若使用固定链接可不必建此表。

---

## 二、后端 API 约定

基础路径与现有项目一致，请求体需支持现有加密方式（除上传接口外）。响应统一格式建议：`{ "code": 200, "msg": "ok", "data": ... }`。

### 1. 提交问题反馈

- **路径**：`POST /v1/feedback/submit`
- **请求体（加密后 JSON）**：
  - `email`： string，必填
  - `content`： string，必填，建议限制 2000 字
  - `image_urls`： string[]，可选，**由客户端直传 OSS 后得到的图片 URL 列表**（与动态发布一致，使用 `ChatMediaUploader.uploadMedias` 上传，后端无需提供图片上传接口）
- **响应**：`{ "code": 200, "msg": "ok", "data": { "id": 123 } }` 或仅 `code`/`msg`

---

### 2. 更新日志列表

- **路径**：`GET /v1/app/updateLogs`
- **可选参数**：`platform`（android/ios）、`limit`
- **响应**：
```json
{
  "code": 200,
  "data": {
    "list": [
      {
        "version": "1.0.0",
        "release_date": "2025-03-01",
        "content": "1. 新增问题反馈\n2. 优化关于我们页面"
      }
    ]
  }
}
```
- 列表建议按 `release_date` 或 `sort_order` 倒序，新版本在前。

---

### 3. 用户协议内容（可选）

若使用动态协议接口（而非固定 H5 链接）：

- **路径**：`GET /v1/app/userAgreement`
- **可选参数**：`type`（user_agreement / privacy_policy）
- **响应**：`{ "code": 200, "data": { "content": "<html>...</html>", "version": "1.0" } }`  
  前端可在 WebView 或富文本中展示 `content`。

---

## 三、前端对接说明

- **关于我们**：应用名、当前版本号在客户端写死或从 `AppConfig` 读取；更新日志、用户协议、官方网站等通过上述接口或配置链接打开。
- **问题反馈**：  
  - 先选图（可选）→ 客户端使用与动态发布相同的 **ChatMediaUploader.uploadMedias** 直传 OSS，得到图片 URL 列表后，再调用 `POST /v1/feedback/submit` 提交邮箱、内容及 `image_urls`。  
  - 后端只需提供 `/v1/feedback/submit` 接口，无需提供图片上传接口。

以上数据表与接口按需实现即可与当前 Flutter 端「问题反馈」「关于我们」功能完整对接。
