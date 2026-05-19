# Telegram App 复现提示词与模块设计文档（精简版）

## 1. 目标

复现当前 `CJMP` Telegram-like app 的完整能力。复现结果必须是三端真实 TDLib 客户端 MVP，不能只复现离线 UI 或 mock demo。

必须覆盖：

- Android / iOS / HarmonyOS 三端。
- TDLib `tdjson` 真实后端接入。
- 真实手机号登录、验证码、二次密码、Session Restore。
- Chats / Contacts / Settings 三 Tab。
- 真实聊天列表、联系人、账号资料、聊天详情、文本消息发送。
- smoke/preview 验收能力。

## 2. 精简主提示词

```text
你要在 TelegramAIDev 仓库中复现当前 CJMP Telegram-like app。

必须先读取当前代码和文档：
- docs/requirements/telegram-commercial-mvp.md
- docs/design/telegram-commercial-mvp.md
- docs/acceptance/telegram-commercial-mvp.md
- docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md
- doc/tdlib_import_run_report.md
- apps/cjmp/lib/*.cj
- apps/cjmp/android/app/src/main/cpp/cjmp.cpp
- apps/cjmp/ios/oc_bridge/cjmp_ffi.m
- apps/cjmp/hos/entry/src/main/cpp/cjmp_ohos_bridge.cpp

复现合同：
1. 主链路必须使用 TDLib tdjson 真实连接 Telegram，禁止退回 mock。
2. 必须保留真实登录状态机：WaitTdlibParameters、WaitEncryptionKey、WaitPhoneNumber、WaitCode、WaitPassword、Ready。
3. 必须保留 API ID/API Hash 输入与持久化。
4. Ready 后必须加载 chats、contacts、settings。
5. Chat detail 必须加载 getChatHistory。
6. 文本发送必须调用 TDLib sendMessage，并处理 sent/error/timeout。
7. Android、iOS、HOS 必须通过统一 FFI ABI 调用 TDLib。
8. HOS 必须有 INTERNET/GET_NETWORK_INFO 权限，并读取系统 HTTP proxy。
9. smoke/preview 只能用于验收，不能替代真实主链路。

交付时必须给出三端构建、TDLib probe、登录、数据加载、发送消息的证据。
```

## 3. 模块设计总览

### 3.1 UI 模块

必须有：

- 启动 loading/failure/login。
- 登录页：Telegram brand、国家、手机号、API ID、API Hash、Keep signed in。
- 验证码页：输入 TDLib code。
- 密码页：输入 Telegram two-step password。
- Home：Chats / Contacts / Settings 三 Tab，Chats 默认选中。
- Chat Detail：顶部栏、消息列表、incoming/outgoing 气泡、composer。

禁止：

- 禁止用单屏 chat list 替代 Home Shell。
- 禁止把 Contacts/Settings 做成空白页。

### 3.2 TDLib Auth 模块

必须实现：

- `getOption("version")` 启动 TDLib。
- `setTdlibParameters`。
- `checkDatabaseEncryptionKey`。
- `setAuthenticationPhoneNumber`。
- `checkAuthenticationCode`。
- `checkAuthenticationPassword`。
- `authorizationStateReady` 后进入 Home。
- Sign out 清理 client、TDLib db/files、runtime config、session 展示数据。

### 3.3 TDLib Bridge 模块

统一 ABI：

- `CreateClient`
- `Send`
- `Poll`
- `Destroy`
- `SetLogVerbosity`
- `GetApplicationFilesDir`
- `ClearLocalData`

平台合同：

- Android：`dlopen("libtdjson.so")`，使用 `td_json_client_*`。
- iOS：从 Frameworks 加载 `libtdjson.dylib`，使用 `td_create_client_id / td_send / td_receive`。
- HOS：CMake 导入 `libtdjson.so`，链接 `td_json_client_*`，读取系统 HTTP proxy。

### 3.4 数据 Store 模块

必须有：

- Chat list store：chatId/title/snippet/time/unread/pinned/muted/order。
- Contacts store：userId/displayName/status。
- Settings store：selfUserId/selfChatId/displayName/phone。
- Messages store：chatId/messageId/text/time/isOutgoing/delivery。
- Send store：idle/pending/sent/error。

UI 禁止直接解析 TDLib JSON；必须由 facade reducer 更新 store。

### 3.5 TDLib Data Facade 模块

必须发送：

- `loadChats`
- `getChats`
- `getChat`
- `getChatHistory`
- `getContacts`
- `getUser`
- `getMe`
- `createPrivateChat`
- `sendMessage`

必须处理：

- `chats`
- `chat`
- `messages`
- `users`
- `user`
- `message`
- `updateNewChat`
- `updateChatPosition`
- `updateChatLastMessage`
- `updateChatReadInbox`
- `updateChatTitle`
- `updateChatNotificationSettings`
- `updateUser`
- `updateNewMessage`
- `updateMessageSendSucceeded`
- `error`

### 3.6 平台验证模块

Android 必须验证：

- APK 包含 `libtdjson.so`。
- TDLib phase0 probe 成功。
- logcat 有 auth/data/send 证据。

iOS 必须验证：

- bundle Frameworks 包含 `libtdjson.dylib`。
- simulator 或真机 smoke 通过。
- bridge 操作串行。

HOS 必须验证：

- HAP/native 输出含 `libtdjson.so`。
- module 权限包含 `INTERNET` 与 `GET_NETWORK_INFO`。
- hilog 有 HTTP proxy 或 no-proxy 判定。
- 能看到 TDLib connection/auth 状态。

## 4. 最小验收清单

- 登录页出现 API ID/API Hash/手机号。
- 输入真实 API 配置和手机号后，TDLib 到达 WaitCode、WaitPassword 或 Ready。
- Ready 后 Home 显示 `Signed in with Telegram`。
- Chats 请求并显示真实主列表或明确空状态。
- Contacts 请求并显示真实联系人或明确空状态。
- Settings 显示真实账号资料。
- Chat Detail 请求真实历史。
- Send 按钮触发 `sendMessage`，并显示成功、失败或超时反馈。
- Sign out 后清理本地 TDLib 数据并回到登录。

## 5. 防退化清单

- 不得删除真实 TDLib bridge。
- 不得删除 HOS proxy/权限路径。
- 不得把 real login 改成本地 demo code。
- 不得把真实 chats/contacts/settings 改成固定 seed data。
- 不得把 receive 改成多线程并发。
- 不得记录手机号、API hash、验证码、密码、encryption key。
