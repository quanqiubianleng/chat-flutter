# BBT 余额与转账记录 - 服务端 API 说明

客户端（BBT 中心页）**只请求服务端**；服务端再请求第三方（Alchemy）获取 BBT 余额与转账记录，并统一鉴权、日志与限流。

---

## 一、流程说明

- **原状**：客户端通过 `walletProxyBaseUrl` 直连网关（或未实现时无日志）。
- **现状**：客户端请求 **`/v1/bbt/balance`**、**`/v1/bbt/transfers`**（与现有接口同域、同鉴权、同加密），服务端收到后**再请求 Alchemy（或其它第三方）**，把结果整理后返回给客户端。
- **效果**：所有 BBT 相关请求都会打在服务端，便于打日志、鉴权、限流与监控。

---

## 二、接口约定

### 1. BBT 余额

- **路径**：`GET /v1/bbt/balance`
- **鉴权**：与现有接口一致（如 Header `Authorization`），请求体与现有接口一样参与统一加解密。
- **请求参数**：客户端通过 GET 请求传递，参数与现有项目一致（可能在 query 或解密后的 body 中，以实际客户端实现为准）：
  - `address`：string，必填，钱包地址 0x...
  - `chain`：string，可选，默认 `bnb-mainnet`，如：`eth-mainnet`、`bnb-mainnet`。
- **响应体（与现有统一格式一致，若启用加密则先解密再解析）**：
```json
{
  "code": 200,
  "msg": "ok",
  "data": {
    "balanceFormatted": "123.456789",
    "balanceWei": "123456789000000000000",
    "symbol": "BBT"
  }
}
```
- **业务错误**：可返回 `code` ≠ 200，并带 `msg`；客户端会展示为错误提示。

**服务端实现要点**：
1. 校验 `address` 格式（0x 开头、长度等）。
2. 使用 Alchemy：对指定 `chain` 调用 RPC，对 BBT 合约 `0x832AB3f581ADD131D50C24d9a85087648bd16934` 调 ERC20 `balanceOf(address)`，或使用 `alchemy_getTokenBalances` 只查该合约。
3. 将余额 wei 转为十进制字符串填入 `balanceWei`，并格式化为最多 6 位小数填入 `balanceFormatted`，`symbol` 固定为 `"BBT"`。
4. 打日志：请求参数、第三方耗时、是否成功等，便于排查“看不到服务端请求”的问题。

---

### 2. BBT 转账记录

- **路径**：`GET /v1/bbt/transfers`
- **鉴权**：与现有接口一致，请求体参与统一加解密。
- **请求参数**：与现有项目一致（query 或解密后 body）：
  - `address`：string，必填，钱包地址 0x...
  - `chain`：string，可选，默认 `bnb-mainnet`。
  - `pageSize`：int，可选，默认 20，单页条数。
- **响应体**：
```json
{
  "code": 200,
  "msg": "ok",
  "data": {
    "transfers": [
      {
        "from": "0x...",
        "to": "0x...",
        "value": "100.5",
        "hash": "0x...",
        "blockNum": "12345678",
        "direction": "in"
      }
    ]
  }
}
```
- **单条记录**：
  - `from` / `to`：转账方/接收方地址。
  - `value`：已按人类可读的数值字符串（如 "100.5"）。
  - `hash`：交易哈希。
  - `blockNum`：区块号（字符串即可）。
  - `direction`：`"in"` 表示当前 `address` 为接收方（收入），`"out"` 表示转出（支出）。客户端据此做「全部/收入/支出」筛选。

**服务端实现要点**：
1. 使用 Alchemy **Transfers API**（如 `alchemy_getAssetTransfers` 或等价接口），筛选：
   - 合约地址为 BBT：`0x832AB3f581ADD131D50C24d9a85087648bd16934`
   - 与 `address` 相关的转入/转出记录。
2. 将每笔转为上述结构，并设置 `direction`（对比 `from`/`to` 与 `address`）。
3. 按区块或时间倒序，取前 `pageSize` 条返回。
4. 若 Alchemy 不支持 BNB 链的该 API，可改用该链的区块浏览器 API 或自建索引，接口格式保持上述 `data.transfers` 即可。
5. 建议打请求日志与第三方调用日志，便于确认“请求已到服务端、服务端已请求第三方”。

---

## 三、客户端调用方式

- 使用统一 `ApiClient`（与登录、用户信息等接口一致）：带鉴权、走统一加解密。
- 余额：`GET /v1/bbt/balance?address=xxx&chain=bnb-mainnet`
- 记录：`GET /v1/bbt/transfers?address=xxx&chain=bnb-mainnet&pageSize=20`
- 不再使用 `walletProxyBaseUrl` 下的 `/bbt/balance`、`/bbt/transfers`。

---

## 四、Alchemy 参考

- **余额**：RPC `eth_call` 到 BBT 合约 `balanceOf(address)`，或 `alchemy_getTokenBalances(owner, [contractAddress])`。
- **转账记录**：Transfers API 的 `getAssetTransfers`，按 `fromAddress`/`toAddress` 及合约地址筛选；若 BNB 链文档有差异，以 Alchemy 当前文档为准。
- BBT 合约地址（EVM 多链同地址）：`0x832AB3f581ADD131D50C24d9a85087648bd16934`。

实现上述两个接口后，BBT 中心页的余额与记录将全部经服务端转发，可在服务端看到完整请求与第三方调用日志。
