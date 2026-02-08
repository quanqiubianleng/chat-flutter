# Follower 多账号隔离与同步

## 是否需要 owner_user_id？

**不需要。** 当前表结构 `(from_user_id, to_user_id)` 已能按账号隔离：

- 查询「我关注的」：`from_user_id = 当前用户`
- 查询「关注我的」：`to_user_id = 当前用户`
- 多账号时，每条关系只存一次，不同账号查各自的 from/to 即可。

加 `owner_user_id` 会冗余且难维护（一条「A 关注 B」同时属于 A 和 B 的视角）。

## 同步方式

1. **调用服务端接口** 拉取当前用户的关注数据：
   - 使用 **`getFollowerData`**（`POST /v1/users/getFollowerData`）一次请求拿到「我关注的」`follower` 与「关注我的」`followers`，再落库。

2. **本地只替换「当前用户」相关行**：
   - 使用 `FollowerRepository.replaceFollowDataForUser(myUserId, following: [...], followers: [...])`
   - 内部会先执行：`DELETE FROM follower WHERE from_user_id = ? OR to_user_id = ?`
   - 再插入本次拉取的 `following`（我关注的）和 `followers`（关注我的）。

3. **调用时机建议**：
   - 登录/切换账号后拉一次；
   - 进入「通讯录/关注」页时拉一次（或按需下拉刷新）。

这样每个账号的数据在同步时被整块替换，不会串号，也无需 `owner_user_id`。
