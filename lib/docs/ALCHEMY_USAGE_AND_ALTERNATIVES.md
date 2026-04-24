# 本项目 Alchemy 使用说明与国内访问替代方案

## 一、当前使用的 Alchemy 接口

所有请求均发往 Alchemy 域名：`https://{chain}.g.alchemy.com`，在国内可能被限流或返回 HTML 导致“无法访问节点”。

### 1. AlchemyService（`lib/services/alchemy_service.dart`）

| 用途           | 方法                | Alchemy 接口/方法                  | 说明                     |
|----------------|---------------------|------------------------------------|--------------------------|
| 代币余额(ERC20)| `getTokenBalances`  | POST JSON-RPC `alchemy_getTokenBalances` | 指定合约或全部代币余额   |
| 原生币余额     | `getNativeBalance`  | POST JSON-RPC `eth_getBalance`     | ETH/BNB 余额             |
| NFT 列表       | `getNfts`           | GET `.../nft/v2/.../getNFTs/`      | 用户持有的 NFT           |

**使用场景：**

- **token_list_page**：代币列表、原生币余额、NFT 列表（按链）
- **swap_token_sheet**：选币弹窗里的代币余额、原生币余额
- **quick_buy_swap_page**：闪兑页余额、原生币
- **transfer_token_sheet**：转账页余额
- **receive_token_page**：收款页（仅链标识）
- **nft_list_page**：NFT 列表
- **asset_grid**：资产入口（跳转代币/NFT）

### 2. EvmTransferService（`lib/services/evm_transfer_service.dart`）

| 用途     | Alchemy 使用方式              | 说明                     |
|----------|-------------------------------|--------------------------|
| 发交易   | 同一 RPC URL 的 Web3 调用     | nonce、gasPrice、发交易  |

同一套 Alchemy RPC URL 用于：查询 nonce、gas 价格、发送已签名的原生币/ERC20 交易。

---

## 二、为何国内常报“网络返回 HTML”

- 直连 `*.g.alchemy.com` 在某些地区会被拦截或返回非 JSON（如 HTML 错误页、验证页），从而触发“网络返回 HTML(无法访问节点)”的日志。
- 解决思路：**不直连 Alchemy**，改为通过**自建后端代理**或**国内可访问的 RPC** 访问链上数据。

---

## 三、替代方案（国内更稳定）

### 方案 A：后端代理 Alchemy（推荐）

由你们自己的后端统一请求 Alchemy，App 只请求后端，这样不依赖国内能否直连 Alchemy。

1. **后端**：提供与 Alchemy 同语义的接口，例如：
   - `POST /rpc`：转发 JSON-RPC（`alchemy_getTokenBalances`、`eth_getBalance` 等）
   - `GET /nft/getNFTs`：转发 Alchemy NFT 接口
   后端服务器放在海外或可访问 Alchemy 的机房即可。

2. **App**：已支持通过环境配置“自定义基地址”`alchemyBaseUrl`（见下），配置后所有 Alchemy 请求会发往 `$alchemyBaseUrl/$chain/v2/$key`（RPC）或 `$alchemyBaseUrl/$chain/nft/v2/$key/...`（NFT）。代理需将这些请求转发到 Alchemy 官方地址（如 `https://$chain.g.alchemy.com/v2/$key`），国内访问更稳定。

### 方案 B：公共 RPC 仅做部分能力（仅读、无 Alchemy 专属接口）

- **eth_getBalance**（原生币余额）：可用公共 RPC 替代，例如：
  - Ethereum: `https://eth.llamarpc.com`, `https://rpc.ankr.com/eth`
  - BNB Chain: `https://bsc-dataseed.binance.org`, `https://rpc.ankr.com/bsc`
  - Base: `https://mainnet.base.org`
- **alchemy_getTokenBalances**、**Alchemy NFT**：属于 Alchemy 专属接口，公共节点一般**不支持**，只能：
  - 继续走 Alchemy（通过方案 A 代理），或
  - 自建后端用“公共 RPC + 批量 eth_call(balanceOf)” 自己算代币余额（实现复杂、请求多）。

因此：**国内要稳定用现有功能，建议用方案 A（后端代理 Alchemy）**。

### 方案 C：仅配置多个 Alchemy 端点（仍直连）

若只是偶尔超时，可尝试在 Alchemy Dashboard 为同一 App 开多个端点或不同区域，在 App 里配置多个 base URL 做故障转移（需要代码支持多 URL 重试）。但若域名在国内被拦截，仅换 URL 无法根本解决，仍需代理。

---

## 四、已支持的可选配置（自定义基地址 / 代理）

在 `app_env.dart` 中已增加可选配置：

- **alchemyBaseUrl**（可选）：  
  若配置，则所有 Alchemy 请求（RPC + NFT）都会发往该基地址，不再使用 `https://{chain}.g.alchemy.com/...`。  
  用于：
  - 填写你们**后端代理地址**（推荐），例如：`https://your-api.com/alchemy`
  - 或填写其他兼容 Alchemy 的网关地址。

配置方式：

- 构建时传入：`flutter run --dart-define=ALCHEMY_BASE_URL=https://your-proxy.com/alchemy`（不要末尾斜杠）。
- 代理需支持的路径格式：
  - RPC：`POST $alchemyBaseUrl/$chain/v2/$apiKey` 转发到 `POST https://$chain.g.alchemy.com/v2/$apiKey`
  - NFT：`GET $alchemyBaseUrl/$chain/nft/v2/$apiKey/getNFTs/?owner=...` 转发到 `GET https://$chain.g.alchemy.com/nft/v2/$apiKey/getNFTs/?owner=...`

配置后：

- **AlchemyService** 的 RPC 与 NFT 请求都会使用 `alchemyBaseUrl` + 原有路径/参数。
- **EvmTransferService** 的发交易 RPC 也会使用同一基地址（若已接好），这样余额查询和发交易在国内都走代理，更稳定。

---

## 五、总结

| 能力           | 当前来源        | 国内更稳做法                    |
|----------------|-----------------|---------------------------------|
| 代币余额       | Alchemy 专属 API| 后端代理 Alchemy（推荐）        |
| 原生币余额     | eth_getBalance  | 后端代理 或 公共 RPC 备用       |
| NFT 列表       | Alchemy NFT API | 后端代理 Alchemy                |
| 发送交易       | Alchemy RPC     | 后端代理 Alchemy                |

**建议**：国内环境统一采用**后端代理 Alchemy**，在 `app_env` 中配置 `alchemyBaseUrl` 指向该代理，即可在不改业务逻辑的前提下提升国内访问稳定性，并避免“网络返回 HTML(无法访问节点)”的报错。
