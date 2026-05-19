# Telegram App 全量复现提示词与模块设计文档（详细版）

## 1. 任务需求分析

目标是让后续模型在新的交付轮次中复现当前 `CJMP` Telegram-like app 的完整能力，而不是只复现早期离线 UI MVP。复现材料必须覆盖两类能力：

- 前端产品能力：启动路由、登录页、验证码页、二次密码页、Session Restore、Chats / Contacts / Settings 三 Tab、真实聊天列表、联系人列表、设置页、聊天详情、消息 composer、发送反馈、错误/空/加载状态。
- 后端与三端能力：通过 TDLib `tdjson` 接入真实 Telegram 后端；在 Android / iOS / HarmonyOS 三端提供原生桥；保存 API 配置和 TDLib 本地数据；按 TDLib 授权状态机完成真实账号登录；从 TDLib 更新中维护聊天、联系人、账号资料、消息历史和发送状态。

后续模型必须把当前 app 视为“真实 TDLib 客户端 MVP”，禁止退回为纯 mock、demo code 或本地假登录。mock/smoke preview 仅用于自动化验收和离线回归，不得替代真实主链路。

## 2. 当前能力基线

### 2.1 关键源码入口

- 应用入口与登录状态：`apps/cjmp/lib/index.cj`
- TDLib 授权状态：`apps/cjmp/lib/telegram_auth_store.cj`
- TDLib 请求、轮询与 update reducer：`apps/cjmp/lib/telegram_tdlib_facade.cj`
- 跨平台 FFI 声明：`apps/cjmp/lib/telegram_tdlib_bridge.cj`
- 运行时配置与代理策略：`apps/cjmp/lib/telegram_runtime_config.cj`
- Chats 数据：`apps/cjmp/lib/telegram_chat_list_store.cj`
- Contacts 数据：`apps/cjmp/lib/telegram_contact_store.cj`
- Settings 数据：`apps/cjmp/lib/telegram_settings_store.cj`
- Chat history 数据：`apps/cjmp/lib/telegram_chat_message_store.cj`
- Send message 状态：`apps/cjmp/lib/telegram_message_send_store.cj`
- 首页 UI：`apps/cjmp/lib/home_shell_page.cj`
- 聊天详情 UI：`apps/cjmp/lib/chat_detail_page.cj`
- Android bridge：`apps/cjmp/android/app/src/main/cpp/cjmp.cpp`
- iOS bridge：`apps/cjmp/ios/oc_bridge/cjmp_ffi.m`
- HarmonyOS bridge：`apps/cjmp/hos/entry/src/main/cpp/cjmp_ohos_bridge.cpp`
- HOS native build：`apps/cjmp/hos/entry/src/main/cpp/CMakeLists.txt`
- HOS 权限：`apps/cjmp/hos/entry/src/main/module.json5`
- Smoke 验收：`apps/cjmp/lib/ui_test_smoke_case.cj`

### 2.2 当前产品能力

- 启动页必须有 loading、login、failure 三态。
- 登录页必须展示 Telegram brand、国家/手机号输入、Telegram API ID、Telegram API Hash、Keep signed in、主 CTA。
- 登录必须通过 TDLib 真实状态机推进：`WaitTdlibParameters -> WaitEncryptionKey -> WaitPhoneNumber -> WaitCode -> WaitPassword(可选) -> Ready`。
- 登录成功必须进入 Home Shell，默认 `Chats` tab。
- Session Restore 必须使用保存的 API 配置和 TDLib 本地数据库恢复，不能只依赖本地手机号。
- `Chats` 必须展示 TDLib 主聊天列表，并保留 `Saved Messages` 自发消息入口。
- `Contacts` 必须使用 `getContacts + getUser` 加载真实联系人，同时保留搜索、quick actions、空/加载/错误状态。
- `Settings` 必须使用 `getMe` 展示真实 Telegram 用户资料，提供 session 状态与 Sign out。
- `Chat Detail` 必须支持 `getChatHistory` 加载真实消息，并显示已有离线 seed 消息用于 smoke 预览。
- 发送消息必须调用 TDLib `sendMessage`，并通过返回 message / `updateMessageSendSucceeded` 或 error 更新 UI 状态。
- Android / iOS / HOS 必须都有 `FfiTdBridgeCreateClient / Send / Poll / Destroy / SetLogVerbosity / ClearLocalData / GetApplicationFilesDir` 等桥接能力。
- HOS 必须申请 `INTERNET` 与 `GET_NETWORK_INFO`，并通过 `OH_NetConn_GetDefaultHttpProxy` 读取系统 HTTP 代理；真实设备登录页禁止默认暴露 proxy host 输入框。

## 3. 复现总提示词

将下面提示词作为后续模型的主任务提示词使用。

```text
你在 /Users/user/Desktop/project/TelegramAIDev 仓库中复现当前 CJMP Telegram-like app 的全部能力。

硬性目标：
1. 复现的 app 必须是三端 CJMP Telegram-like 客户端 MVP，支持 Android、iOS、HarmonyOS。
2. 主链路必须接入真实 Telegram 后端，使用 TDLib tdjson C/JSON 接口，不得退回为本地 mock 登录或纯 demo session。
3. 必须保留现有 Telegram-like 前端能力：启动页、真实登录、验证码、二次密码、Session Restore、Chats / Contacts / Settings 三 Tab、聊天列表、联系人搜索、设置页、聊天详情、发送消息、加载/空/错误状态。
4. 必须保留三端 native bridge：Android C++ dlopen libtdjson.so、iOS Objective-C bridge 加载 libtdjson.dylib、HOS C++ bridge 链接 libtdjson.so 并读取系统 HTTP 代理。
5. 必须使用 TDLib 官方状态机：setTdlibParameters、checkDatabaseEncryptionKey、setAuthenticationPhoneNumber、checkAuthenticationCode、checkAuthenticationPassword、authorizationStateReady。
6. 必须用 TDLib update 驱动 UI store：loadChats/getChats/getChat、getChatHistory、getContacts/getUser、getMe/createPrivateChat、sendMessage、updateNewChat、updateChatLastMessage、updateChatPosition、updateChatReadInbox、updateUser、updateNewMessage、updateMessageSendSucceeded。
7. 必须保留 smoke/preview 路径用于自动化验收，但 smoke/preview 不得替代真实主链路。

执行规则：
- 先读当前仓库文档和代码：docs/requirements、docs/design、docs/acceptance、doc/tdlib_import_run_report.md、apps/cjmp/lib、apps/cjmp/android、apps/cjmp/ios、apps/cjmp/hos。
- 需要 TDLib、CJMP、CJ-UI、仓颉语法或工具链资料时，必须先用 Context7 或项目 skill 查询当前文档。
- 改动必须外科手术式完成。禁止重写整套 UI，禁止引入无关抽象，禁止删除用户已有变更。
- 对 Cangjie/CJMP 代码必须沿用当前 @When 条件编译、foreign func、store + facade + UI 页面分层。
- 对三端 bridge 必须保持同名 FFI ABI，禁止让页面直接调用平台原生代码。
- 真实账号凭证必须由用户输入或本地安全配置提供，禁止把 API hash、验证码、密码、手机号硬编码到仓库。
- 日志必须脱敏敏感字段：phone_number、api_hash、code、password、encryption_key。

验收门禁：
- 编译必须覆盖目标平台对应链路。
- TDLib phase0 probe 必须成功。
- 登录必须至少到达 WaitCode / WaitPassword / Ready 中可识别状态；完整验收必须进入 authorizationStateReady。
- Ready 后必须请求 chats、contacts、settings 三类数据。
- 聊天详情必须能请求历史消息。
- 发送消息必须调用 sendMessage，并对 accepted / failed / timeout 给出 UI 反馈。
- HOS 必须验证 module 权限、libtdjson.so 打包、系统 HTTP 代理读取、connectionStateReady 或可诊断日志。

交付物：
- 实现代码。
- 运行/验证记录。
- 若无法完成某平台，必须给出确切阻塞点、日志证据和未完成范围，禁止用“可能是环境问题”收尾。
```

## 4. 分阶段提示词包

### 4.1 仓库基线读取提示词

```text
请先只做仓库基线分析，不修改代码。

读取并整理：
- docs/requirements/telegram-commercial-mvp.md
- docs/design/telegram-commercial-mvp.md
- docs/acceptance/telegram-commercial-mvp.md
- docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md
- doc/tdlib_import_run_report.md
- apps/cjmp/lib/*.cj
- apps/cjmp/android/app/src/main/cpp/cjmp.cpp
- apps/cjmp/ios/oc_bridge/cjmp_ffi.m
- apps/cjmp/hos/entry/src/main/cpp/cjmp_ohos_bridge.cpp

输出：
1. 当前真实能力清单。
2. mock/smoke 能力与真实主链路的边界。
3. 三端 bridge 差异。
4. 后续需要实现或验证的模块清单。

禁止：
- 禁止直接改代码。
- 禁止把旧文档里的“未接入真实后端”结论当作当前事实，必须以当前源码为准。
```

### 4.2 TDLib 官方合同提示词

```text
请使用 Context7 查询 TDLib 当前官方文档，然后为本仓库固定 TDLib 合同。

必须覆盖：
- td_json_client_create / send / receive / execute / destroy
- td_create_client_id / td_send / td_receive / td_execute 的 iOS 替代接口
- receive 单线程要求
- setTdlibParameters 的必填字段
- authorizationStateWaitTdlibParameters / WaitEncryptionKey / WaitPhoneNumber / WaitCode / WaitPassword / Ready / Closed
- checkDatabaseEncryptionKey / setAuthenticationPhoneNumber / checkAuthenticationCode / checkAuthenticationPassword
- addProxy + proxyTypeSocks5 / proxyTypeHttp
- loadChats / getChats / getChat / getChatHistory / getContacts / getUser / getMe / createPrivateChat / sendMessage
- updateNewChat / updateChatPosition / updateChatLastMessage / updateChatReadInbox / updateChatTitle / updateChatNotificationSettings / updateUser / updateNewMessage / updateMessageSendSucceeded

输出：
- 本仓库必须遵守的接口顺序。
- 哪些函数可多线程调用，哪些必须串行。
- 本仓库 store/reducer 应响应的 update 类型。
```

### 4.3 登录与 Session Restore 提示词

```text
请实现或复现 Telegram 真实登录与 Session Restore。

必须读取：
- apps/cjmp/lib/index.cj
- apps/cjmp/lib/telegram_auth_store.cj
- apps/cjmp/lib/telegram_tdlib_facade.cj
- apps/cjmp/lib/telegram_runtime_config.cj
- apps/cjmp/lib/demo_session_store.cj

必须实现：
- API ID / API Hash 输入、校验、持久化。
- Keep signed in 控制。
- 手机号提交前必须等待 authorizationStateWaitPhoneNumber。
- 验证码页必须对应 authorizationStateWaitCode。
- 密码页必须对应 authorizationStateWaitPassword。
- Ready 后必须进入 Home Shell。
- Restore 必须从持久化 API 配置和 TDLib database 恢复，不得只用 demo phone。
- Restart / Sign out 必须销毁 client、清理 TDLib db/files、清理 runtime/session 数据。
- 登录超时必须显示可恢复提示。

禁止：
- 禁止把验证码写死。
- 禁止用 demo code 判定真实登录成功。
- 禁止在真机登录 UI 中暴露 proxy host 默认输入框。
```

### 4.4 TDLib Bridge 三端提示词

```text
请复现三端 TDLib bridge。

共享 CJMP 层：
- apps/cjmp/lib/telegram_tdlib_bridge.cj 必须使用 @When target_platform 条件编译。
- 必须提供 create/send/poll/destroy/setLogVerbosity/getApplicationFilesDir/clearLocalData。
- 页面和 store 禁止直接调用 Android/iOS/HOS 原生 API。

Android：
- apps/cjmp/android/app/src/main/cpp/cjmp.cpp 必须 dlopen libtdjson.so。
- 必须解析 td_json_client_create/send/receive/execute/destroy。
- 必须用 mutex 管理 handle -> client。
- 必须能清理 telegram_tdlib_db 与 telegram_tdlib_files。
- 必须检测 emulator 与 127.0.0.1:7897 loopback，以决定默认 SOCKS5 代理。

iOS：
- apps/cjmp/ios/oc_bridge/cjmp_ffi.m 必须从 app bundle Frameworks 加载 libtdjson.dylib。
- 必须使用 td_create_client_id / td_send / td_receive / td_execute。
- 必须用单一锁串行 bridge 操作。
- 必须使用 Application Support 下的 app 专属目录保存 TDLib db/files。

HarmonyOS：
- apps/cjmp/hos/entry/src/main/cpp/CMakeLists.txt 必须导入 ohos/arm64-v8a/libtdjson.so。
- apps/cjmp/hos/entry/src/main/cpp/cjmp_ohos_bridge.cpp 必须链接 td_json_client_* 符号。
- module.json5 必须声明 INTERNET 与 GET_NETWORK_INFO。
- 必须通过 OH_NetConn_GetDefaultHttpProxy 读取系统 HTTP 代理，并在 CJMP 层转成 proxyTypeHttp。
```

### 4.5 数据面 Store 与 Reducer 提示词

```text
请复现真实 Telegram 数据面。

必须读取：
- telegram_chat_list_store.cj
- telegram_chat_message_store.cj
- telegram_contact_store.cj
- telegram_settings_store.cj
- telegram_message_send_store.cj
- telegram_tdlib_facade.cj

必须实现：
- ChatListRow：chatId、title、snippet、timestampLabel、unreadCount、isPinned、isMuted、orderKey。
- Chat list 状态：idle/loading/populated/empty/error。
- Contacts Row：userId、displayName、statusLabel。
- Contacts 状态：idle/loading/populated/empty/error。
- Settings：kind、notice、selfUserId、selfChatId、displayName、phone。
- Chat messages：按 chatId 保存 rows，支持 loading/populated/empty/error。
- Send state：idle/pending/sent/error，使用 @extra send-message-N 关联响应。
- reducer 必须处理 response 与 update 两类 TDLib JSON。
- 解析失败不得 crash，必须忽略或转 error state。

禁止：
- 禁止让 UI 直接解析 TDLib JSON。
- 禁止把 TDLib 原始 JSON 泄漏到用户可见 UI，敏感日志必须脱敏。
```

### 4.6 Home / Contacts / Settings UI 提示词

```text
请复现 Home Shell。

必须读取：
- apps/cjmp/lib/home_shell_page.cj
- apps/cjmp/lib/platform_scroller.cj
- apps/cjmp/lib/ui_test_selectors.cj

必须实现：
- 默认进入 Chats。
- 顶部标题随 tab 切换。
- Chats / Contacts / Settings 三 Tab 始终可见。
- Chats 必须展示 loading/empty/error/populated，真实链路使用 telegramChatListRows。
- Chats 必须显示 Saved Messages 入口，当 telegramSettingsSelfChatId != 0 时可进入 tdchat:selfChatId。
- 真实 chat row 必须显示头像初始字母、标题、snippet、timestamp、unread、pinned/muted。
- Contacts 必须有搜索、Quick Actions、真实联系人列表、空/加载/错误状态。
- Settings 必须有真实 profile、session headline/body、Sign out、Account/Preferences 分组。
- smoke preview 必须保留 seed rows，用于无真实账号的 UI 验收。

禁止：
- 禁止把 Contacts 和 Settings 做成空白 placeholder。
- 禁止深挖未要求的 settings drill-down。
- 禁止用单屏 chat list 代替三 Tab shell。
```

### 4.7 Chat Detail 与发送提示词

```text
请复现聊天详情和消息发送。

必须读取：
- apps/cjmp/lib/chat_detail_page.cj
- apps/cjmp/lib/telegram_chat_message_store.cj
- apps/cjmp/lib/telegram_message_send_store.cj
- apps/cjmp/lib/telegram_tdlib_facade.cj

必须实现：
- 支持 seed conversation 和真实 tdchat:<chatId> 两类路由。
- 真实 chat detail 打开时必须 requestTelegramChatHistoryIfNeeded(chatId)。
- UI 必须显示日期分隔、incoming/outgoing 气泡、delivery label。
- 消息历史必须从 getChatHistory 的 messages response 构造 TelegramChatMessageRow。
- updateNewMessage 必须 upsert message。
- updateMessageSendSucceeded 必须替换 pending message。
- composer 非空才能发送。
- 真实 chat 必须调用 sendTelegramTextMessage -> TDLib sendMessage。
- 发送必须处理 accepted、failed、timeout 三种反馈。
- 非真实 seed chat 可保留本地 pending -> sent，用于 smoke。

禁止：
- 禁止把真实发送伪造成本地 append。
- 禁止引入附件、语音、贴纸、媒体库等超范围能力。
```

### 4.8 Smoke 与验收提示词

```text
请复现自动化验收入口。

必须覆盖：
- TDLib phase0 native probe。
- 登录页 UI selector。
- Home shell preview。
- Contacts 搜索与 quick action。
- Settings profile/session/sign out。
- Chat detail composer。
- Android/iOS/HOS 平台差异。

必须注意：
- Android UI hierarchy 可能只暴露根视图，验收必须允许截图/logcat/状态文件作为补充证据。
- iOS 必须通过 Xcode UI Test shell 或等价外层 harness 驱动。
- HOS 必须用 hdc/hilog 或等价方式验证 bridge、权限、proxy、connection state。
- smoke preview 只证明 UI，不证明真实 Telegram 后端；真实后端必须看 TDLib auth/data/send 日志或 UI 状态。
```

## 5. 功能模块设计文档

### 5.1 产品范围模块

**目标**

复现一个可商业演示的 Telegram-like 客户端 MVP，用于评估 CJMP 三端 AI 辅助开发效率。产品必须足够真实，以暴露 UI、状态、路由、原生桥、工具链、验收和真实后端接入问题。

**范围内**

- 真实 Telegram 登录。
- 真实 Session Restore。
- Home Shell 三 Tab。
- 真实聊天列表、联系人、账号设置资料。
- 聊天详情与历史消息。
- 文本消息发送。
- Android / iOS / HOS 真机或模拟器链路。
- smoke/preview 验收路径。

**范围外**

- 语音/视频通话。
- 媒体附件发送。
- sticker / voice composer。
- bots、channels、payments、stories、mini apps。
- 完整 contacts 编辑。
- 深层 settings 页面。
- E2EE 实现细节。

**验收**

- 主路径必须能进入真实 TDLib Ready。
- Ready 后必须展示真实数据面，不得只展示 seed data。
- 任一平台未完成必须明确标注，不能模糊成“已复现”。

### 5.2 架构模块

**分层**

1. UI 层：`index.cj`、`home_shell_page.cj`、`chat_detail_page.cj`。
2. Store 层：auth、chat list、messages、contacts、settings、send store。
3. Facade 层：`telegram_tdlib_facade.cj` 负责构造 TDLib JSON、轮询、解析 update、驱动 store。
4. FFI 声明层：`telegram_tdlib_bridge.cj` 负责统一 ABI。
5. Native bridge 层：Android C++、iOS Objective-C、HOS C++。
6. TDLib 原生库：`libtdjson.so` / `libtdjson.dylib`。

**硬性合同**

- UI 只读取 store 和调用 facade 暴露函数。
- Facade 是唯一 TDLib JSON 构造和 update reducer 入口。
- Native bridge 只提供通用 send/poll/client/storage/proxy 能力，不承载页面业务。
- 任何平台差异必须封在 `@When` 或 native bridge 内。

### 5.3 启动与路由模块

**状态**

- `loading`
- `login`
- `failure`

**路由**

- 首次启动进入 login。
- 已保存 runtime config 且 keep signed in 为 true 时，启动自动尝试 TDLib session restore。
- Ready 后进入 `ROUTE_HOME_SHELL`。
- Chat row 进入 `ROUTE_CHAT_DETAIL`。
- 真实 chat detail 路由参数必须是 `tdchat:<chatId>`。

**验收**

- loading 不得永久停留。
- failure 必须有可恢复 CTA。
- restore 中间状态必须有提示，不得空白。

### 5.4 登录与授权模块

**输入**

- 国家区域固定展示 `China`。
- Phone number 输入拼接 `+86`。
- Telegram API ID。
- Telegram API Hash。
- Keep me signed in。
- Verification code。
- Two-step verification password。

**状态机映射**

- `authorizationStateWaitTdlibParameters` -> 发送 `setTdlibParameters`。
- `authorizationStateWaitEncryptionKey` -> 发送 `checkDatabaseEncryptionKey`。
- `authorizationStateWaitPhoneNumber` -> 显示手机号输入，可提交 `setAuthenticationPhoneNumber`。
- `authorizationStateWaitCode` -> 显示验证码页，提交 `checkAuthenticationCode`。
- `authorizationStateWaitPassword` -> 显示密码页，提交 `checkAuthenticationPassword`。
- `authorizationStateReady` -> 标记 ready、请求数据面、进入 Home。
- `authorizationStateClosed` -> 标记 failure，要求重新登录。

**错误处理**

- `PHONE_CODE_INVALID` -> 验证码错误提示。
- `PASSWORD_HASH_INVALID` -> 密码错误提示。
- `FLOOD_WAIT` -> 等待提示。
- code 401 -> 授权数据被拒绝，要求重新登录。
- phone submit timeout -> 可恢复提示。

**禁止**

- 禁止 demo 验证码通过真实登录。
- 禁止自动提交验证码或密码。
- 禁止把敏感字段写入普通日志。

### 5.5 Runtime Config 与代理模块

**存储字段**

- `api_id`
- `api_hash`
- `keep_signed_in`

**校验**

- `api_id` 必须全数字。
- `api_hash` 必须非空。
- proxy 仅当 host 非空时启用。

**代理策略**

- Android emulator 使用 `10.0.2.2:7897`。
- Android 真机如能连通 `127.0.0.1:7897`，使用本机 loopback SOCKS5。
- 非 Android 默认无代理。
- HOS 从系统 HTTP proxy 读取 host/port，映射为 `proxyTypeHttp`。
- 真实设备 UI 默认不显示 proxy host 字段。

### 5.6 TDLib Bridge 模块

**共享 ABI**

- `FfiTdBridgeCreateClient() -> Int64`
- `FfiTdBridgeSend(handle, requestJson) -> Int64`
- `FfiTdBridgePoll(handle, timeoutMs) -> CString`
- `FfiTdBridgeDestroy(handle) -> Int64`
- `FfiTdBridgeSetLogVerbosity(level) -> Int64`
- `FfiGetApplicationFilesDir() -> CString`
- `FfiClearTelegramTdLocalData() -> Int64`
- `FfiFreeString(ptr)`

**官方约束**

- `send` 可被多线程调用，但本仓库必须通过 bridge mutex 保持实现简单。
- `receive` 禁止多线程同时调用；本仓库必须只有一个 poll loop。
- `execute` 只用于同步请求，例如设置日志级别。

**三端差异**

- Android 使用 `td_json_client_create/send/receive/execute/destroy`。
- iOS 使用 `td_create_client_id/td_send/td_receive/td_execute`。
- HOS 链接 `td_json_client_*` 符号并复制 `libtdjson.so`。

### 5.7 TDLib Facade 模块

**请求构造**

- `getOption("version")` 用于 kickstart。
- `addProxy` 必须在需要代理时先发送。
- `setTdlibParameters` 必须包含 database/files 目录、api_id、api_hash、语言、device、app version。
- `loadChats` 与 `getChats` 联合用于主列表加载。
- `getChat` 用于获取 snapshot。
- `getChatHistory` 用于聊天详情。
- `getContacts` + `getUser` 用于联系人。
- `getMe` + `createPrivateChat` 用于 settings 与 Saved Messages。
- `sendMessage` 用于真实文本发送。

**Update reducer**

必须处理：

- `updateConnectionState`
- `addedProxy`
- `error`
- `updateAuthorizationState`
- `chats`
- `chat`
- `messages`
- `user`
- `users`
- `message`
- `updateNewMessage`
- `updateMessageSendSucceeded`
- `updateUser`
- `updateNewChat`
- `updateChatPosition`
- `updateChatLastMessage`
- `updateChatReadInbox`
- `updateChatTitle`
- `updateChatNotificationSettings`

### 5.8 Chats 模块

**数据模型**

`TelegramChatListRow` 必须包含：

- `chatId`
- `title`
- `snippet`
- `timestampLabel`
- `unreadCount`
- `isPinned`
- `isMuted`
- `orderKey`

**排序**

- 按 `orderKey` 降序。
- `orderKey == 0` 的 chat 必须移出主列表。

**UI**

- loading：显示 `Loading Telegram chats...`
- empty：显示主列表暂无聊天。
- error：显示 `telegramChatListNotice` 或默认错误。
- populated：先展示 Saved Messages，再展示真实 chat rows。

### 5.9 Contacts 模块

**数据模型**

`TelegramContactRow` 必须包含：

- `userId`
- `displayName`
- `statusLabel`

**数据来源**

- `getContacts` 返回 user ids。
- 每个 user id 必须调用 `getUser`。
- `updateUser` 若 `is_contact` 为 true，必须 upsert。

**UI**

- 搜索框必须支持 name/status token prefix 搜索。
- Quick Actions 必须展示 Add Contact、People Nearby、Invite Friends。
- 真实联系人必须展示 initials、displayName、status。
- 空、加载、错误状态必须可见。

### 5.10 Settings 模块

**数据来源**

- `getMe` 返回当前用户。
- `createPrivateChat(selfUserId, force=true)` 获取 Saved Messages chat id。

**展示**

- 真实 displayName。
- 真实 phone。
- Session headline：`Signed in with Telegram`。
- Session body：`Real TDLib session is active on this device.`。
- Sign out 按钮必须调用 `destroyTelegramAuthSessionAndLocalState()`。
- Account / Preferences 分组必须存在，但行点击只显示未接线 notice。

### 5.11 Chat Detail 模块

**路由**

- seed conversation：`alex/design/ops` 等 smoke 参数。
- real conversation：`tdchat:<chatId>`。

**真实历史**

- 打开真实 chat 时必须调用 `getChatHistory`。
- `messageText` 映射为文本。
- 图片、视频、文档、贴纸、语音等仅映射为摘要文本，不实现媒体渲染。
- outgoing message 必须显示 Pending 或 Sent。

**UI**

- 顶部 back、头像、title、subtitle。
- 日期分隔。
- incoming 左气泡，outgoing 右气泡。
- composer 位于底部。

### 5.12 消息发送模块

**流程**

1. composer 非空。
2. 真实 chat 取 `preferredTelegramSendChatId(currentChatId)`。
3. `beginTelegramMessageSend` 生成 `send-message-N`。
4. 发送 TDLib `sendMessage`。
5. 收到 `message` response 或 `updateMessageSendSucceeded` 标记 sent。
6. 收到 error 标记 failed。
7. 超时显示未确认提示。

**禁止**

- 禁止真实发送只做本地 append。
- 禁止失败后清空错误提示。

### 5.13 三端构建与打包模块

**Android**

- `libtdjson.so` 必须进入 `apps/cjmp/android/app/libs/arm64-v8a/`。
- APK 必须包含 arm64-v8a TDLib。
- 真机路径必须能访问 app files dir。

**iOS**

- `libtdjson.dylib` 必须进入 `apps/cjmp/ios/frameworks/` 并被 Xcode embed。
- iOS device 与 iOS simulator 产物必须分开。

**HOS**

- `libtdjson.so` 必须在 `apps/cjmp/hos/entry/src/main/libs/arm64-v8a/` 或构建中复制到 native lib 输出。
- `CMakeLists.txt` 必须能通过 `TDLIB_PHASE0_ROOT` 定位 ohos 产物。
- HAP 必须包含 `libtdjson.so` 与 `libc++_shared.so`。

### 5.14 验收模块

**最小验收**

- `tdjson_phase0_probe` 通过。
- 登录页显示 API ID/API Hash/手机号输入。
- 提交手机号后到达 WaitCode / WaitPassword / Ready 的可识别状态。
- Ready 后 Home Shell 显示真实 session。
- Chats / Contacts / Settings 都触发数据请求。
- Chat detail 触发 history 请求。
- 发送文本触发 TDLib sendMessage。

**三端验收**

- Android：APK 安装启动、logcat 有 TDLib probe/auth/data/send 证据。
- iOS：simulator 或真机 UI smoke 通过，bundle 内有 `libtdjson.dylib`。
- HOS：HAP 打包含 `libtdjson.so`，hilog 有 proxy 和 TDLib connection state 证据。

## 6. 防退化清单

- 禁止删除 API ID/API Hash 输入。
- 禁止恢复 proxy host 默认 UI。
- 禁止把 real auth 改回 demo auth。
- 禁止把 chat list 改回固定三条 seed rows。
- 禁止让 Contacts/Settings 变成 placeholder。
- 禁止删除 TDLib phase0 probe。
- 禁止移除 HOS `INTERNET` / `GET_NETWORK_INFO` 权限。
- 禁止让 `receive` 多线程并发。
- 禁止把 TDLib db/files 目录放到不可写路径。
- 禁止在日志中输出 phone、api_hash、code、password、encryption_key。

## 7. 交付验收模板

后续模型完成复现后必须填写：

```text
复现范围：
- Android:
- iOS:
- HarmonyOS:

真实主链路证据：
- TDLib client create:
- setTdlibParameters:
- WaitPhoneNumber:
- WaitCode / WaitPassword:
- Ready:
- loadChats/getChats:
- getContacts/getUser:
- getMe/createPrivateChat:
- getChatHistory:
- sendMessage:

UI 证据：
- Login:
- Home Chats:
- Contacts:
- Settings:
- Chat Detail:
- Composer:

未完成项：
- 无 / 列出确切阻塞和日志。
```
