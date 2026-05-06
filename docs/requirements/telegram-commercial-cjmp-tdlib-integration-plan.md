# CJMP Telegram TDLib 后端接入需求开发计划书

## 文档目的

本计划书面向 `CJMP` 版本 Telegram-like 商业 Demo，目标是在已经具备较完整 UI 的基础上，接入真实 Telegram 后端能力，使应用可以：

- 使用真实 Telegram 账号登录
- 展示真实聊天列表、聊天详情、联系人、settings MVP 信息
- 在应用内发送测试消息后，由真实 Telegram 账号收到消息
- 可安装到真实 Android / iOS / HOS 设备

本计划书同时明确当前 `CJMP` UI 的真实完成度，并给出可落地的后端适配路线。

## 背景与范围调整

现有共享 MVP 需求文档 `docs/requirements/telegram-commercial-mvp.md` 将“real backend integration”定义为 out of scope。当前计划书是 `CJMP lane` 的专项升级计划，用于把现有“本地 demo MVP”推进到“真实 Telegram 后端 MVP”。

这意味着：

- 共享产品形态不推翻，仍保持 Telegram-like MVP 范围
- 主要变化在数据源、鉴权链路、状态同步和多端原生桥接
- 不在本轮引入语音、媒体、频道、机器人、复杂设置页等超范围能力

## 当前 CJMP UI 已实现程度

以下结论基于当前仓库代码而非口头假设。

### 1. 登录与启动路由

当前登录页已经具备完整壳层和交互节奏：

- 有启动 loading、启动失败、登录页三态，见 `apps/cjmp/lib/index.cj`
- 有手机号输入、验证码页切换、inline 错误提示，见 `apps/cjmp/lib/index.cj`
- 当前手机号和验证码均是本地 demo 校验，不连接 Telegram 服务
- 登录成功后跳转首页，但并非真实账号登录，而是 demo session handoff

代码证据：

- 启动与登录状态机：`apps/cjmp/lib/index.cj:30-32`、`apps/cjmp/lib/index.cj:121-159`
- 手机号与验证码提交流程：`apps/cjmp/lib/index.cj:200-249`

### 2. Session Restore

当前已有“本地 demo session 恢复”能力：

- Android 通过本地文件路径保存 demo phone
- iOS / iOS-sim 通过现有 FFI bridge 保存 demo phone
- 这不是 Telegram 授权态恢复，只是 demo login 的本地持久化

代码证据：

- demo session 存储与恢复：`apps/cjmp/lib/demo_session_store.cj:66-184`
- Android 原生存储桥：`apps/cjmp/android/app/src/main/cpp/cjmp.cpp`
- iOS 原生存储桥：`apps/cjmp/ios/oc_bridge/cjmp_ffi.h`、`apps/cjmp/ios/oc_bridge/cjmp_ffi.m`

### 3. Chats 首页

当前首页壳子已经比较完整，能直接承接真实数据：

- 有 `Chats / Contacts / Settings` 三个 Tab
- `Chats` 已有 loading / empty / error / populated 四态
- 聊天行可点击进入详情
- 交互和滚动结构已成型

但当前聊天数据仍为硬编码 seed data，而不是后端数据。

代码证据：

- 首页状态与 tab 结构：`apps/cjmp/lib/home_shell_page.cj:10-20`、`apps/cjmp/lib/home_shell_page.cj:111-166`
- Chat list 四态：`apps/cjmp/lib/home_shell_page.cj:432-493`
- 三条会话 seed row：`apps/cjmp/lib/home_shell_page.cj:520-661`
- 对应 mock 数据定义：`apps/cjmp/assets/telegram-commercial-cjmp/shared-mock-data.json`

### 4. Contacts

当前 Contacts MVP 已不是空白占位，而是有可演示的一层真实交互壳：

- 有搜索框
- 有 quick actions
- 有分组联系人列表
- 搜索可以过滤本地 seed contact

但联系人仍是硬编码展示，不是 Telegram 联系人或搜索结果。

代码证据：

- Contacts 搜索与筛选函数：`apps/cjmp/lib/home_shell_page.cj:214-250`
- Contacts UI 结构：`apps/cjmp/lib/home_shell_page.cj:668-1024`

### 5. Settings

当前 Settings MVP 已具备一层稳定结构：

- 有 profile 卡片
- 有 Account / Preferences 分组
- 有 sign out 按钮
- 可以展示“当前 demo session”的文案

但当前 settings 信息仍非 Telegram 账户真实资料，也没有真实会话管理。

代码证据：

- Settings 结构：`apps/cjmp/lib/home_shell_page.cj:1027-1268`

### 6. Chat Detail 与发送链路

当前聊天详情页已经具备较完整的消息页壳层：

- 有顶部栏、返回、标题、副标题
- 有消息列表、时间分隔、收发消息气泡
- 有 composer 输入框和发送按钮
- 有 pending -> sent 的本地演示状态变化
- 有本地失败模拟

但消息历史、发送结果和 delivery 状态都不是来自 Telegram。

代码证据：

- 详情页路由与会话标题：`apps/cjmp/lib/chat_detail_page.cj:48-83`
- 本地发送逻辑：`apps/cjmp/lib/chat_detail_page.cj:140-194`
- 固定消息历史与 composer：`apps/cjmp/lib/chat_detail_page.cj:234-420`

### 7. 测试与验收基础设施

当前已有较完整 smoke/real-device 验收基础：

- UI smoke tool page 已接通
- Android/iOS 已有原生桥接先例
- 适合在 TDLib 接入后继续扩展为真实后端验收

代码证据：

- smoke page 与自动运行：`apps/cjmp/lib/ui_test_page.cj:28-121`

## 当前实现结论

结论不是“UI 还没做完”，而是：

- 当前 `CJMP` UI 主链路已经足够支撑真实后端适配
- 最大缺口不在界面，而在“数据源全部是本地 demo/mock”
- 当前 app 更像“高完成度离线演示壳”，尚未进入“真实 Telegram client MVP”

因此，后续工作应避免重写 UI，而应优先做：

- TDLib 接入
- 真实授权态接入
- 真实聊天/联系人/消息状态映射
- 多端原生桥接和真实设备验收

## 推荐技术路线

## 方案结论

推荐使用 `TDLib` 的 `tdjson` C JSON 接口作为 `CJMP` 与 Telegram 后端之间的统一桥梁，而不是让 `CJMP` 直接吃平台各自的 Java / Objective-C 高层封装。

原因：

- `tdjson` 是 TDLib 官方提供的跨语言 C 接口，适合任何能调用 C 函数并处理 JSON 的语言
- 当前仓库已经存在 Android C++ / JNI 和 iOS Objective-C FFI 先例，适合延续这条路线
- 统一 JSON bridge 后，`CJMP` 层的数据模型和状态机可以最大限度共享
- Android / iOS 可共用一套“请求 JSON / 更新 JSON / 状态映射”逻辑

官方依据：

- TDLib 官方 `td_json_client.h` 文档说明其 JSON C 接口适合任何支持 C 调用并能处理 JSON 的语言
- TDLib 官方说明其主接口是异步的，更新和响应需要按收到顺序处理
- TDLib 官方 README 明确 `Td::TdJson` / `td_json_client` 是推荐给“other programming languages”的路径

参考：

- [TDLib GitHub README](https://github.com/tdlib/td)
- [TDLib JSON C interface](https://core.telegram.org/tdlib/docs/td__json__client_8h.html)

## 推荐架构分层

### A. CJMP 共享层

建议新增一个共享的 Telegram 数据与状态层：

- `TelegramAuthStore`
- `TelegramChatListStore`
- `TelegramChatDetailStore`
- `TelegramContactsStore`
- `TelegramSettingsStore`
- `TelegramTdlibFacade`

职责：

- 向 UI 暴露稳定的 view state
- 维护鉴权状态机
- 将 TDLib update 映射成 UI 所需状态
- 统一 loading / error / empty / stale / reconnecting 展示

### B. Native Bridge 层

建议新增统一的最小 C ABI，而不是让每个页面直接碰原生平台：

- `TdBridgeCreateClient(config_json) -> handle`
- `TdBridgeSend(handle, request_json)`
- `TdBridgePoll(handle, timeout_ms) -> update_json`
- `TdBridgeDestroy(handle)`
- `TdBridgeSetLogLevel(...)`

建议优先使用“native queue + CJMP 定时 drain/poll”的模型，而不是一开始就做复杂 callback 反调：

- TDLib 本身就是异步 receive 模型
- 当前 `CJMP` 代码已经有 `spawn` 和轮询式 smoke 经验
- poll/drain 模式更容易先在 Android / iOS 跑通，再决定是否升级成 callback/event bus

### C. 平台实现层

Android：

- 在现有 `apps/cjmp/android/app/src/main/cpp/cjmp.cpp` 基础上扩展
- 链接 `tdjson`
- 由 Java/Application 注入 app files 目录、cache 目录、device info

iOS：

- 在现有 `apps/cjmp/ios/oc_bridge/cjmp_ffi.h` / `cjmp_ffi.m` 基础上扩展
- 链接 `tdjson` 静态或动态库
- 用 Objective-C 包一层简单桥，向 `CJMP` 暴露 C ABI

HOS：

- 当前仓库还没有与 Android/iOS 对等的 HOS 原生桥接层
- 需要单独的 feasibility spike
- 若 HOS 能直接链接 C/C++ 动态库，则沿用同一 `tdjson` 思路
- 若 HOS 的 native/FFI 能力不足，则必须先沉淀为 `CJMP` issue，再决定是否换接入形态

## TDLib 对当前页面的适配映射

### 1. 登录页适配

当前 UI 可以保留大部分视觉结构，只替换行为：

- 手机号页：从 demo 校验改为 `setAuthenticationPhoneNumber`
- 验证码页：从 demo code 改为 `checkAuthenticationCode`
- 如果返回二次密码态，新增 `Password` 步骤页，对应 `checkAuthenticationPassword`
- 登录成功条件从“本地 demo session 已写入”改为 `authorizationStateReady`

官方相关状态/方法：

- `setTdlibParameters`
- `authorizationStateWaitPhoneNumber`
- `checkAuthenticationCode`
- `authorizationStateReady`

参考：

- [setTdlibParameters](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_tdlib_parameters.html)
- [authorizationStateWaitPhoneNumber](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state_wait_phone_number.html)
- [checkAuthenticationCode](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_code.html)

### 2. Session Restore 适配

当前 demo session restore 需要升级为 TDLib 自身会话恢复：

- 本地不再只存手机号
- 主要依赖 TDLib 的本地 database 和 encryption key
- app 冷启动时先恢复 TDLib client
- 通过授权状态判断是否已可直接进入首页

改造原则：

- `demo_session_store.cj` 不应再承担真实登录态的唯一来源
- 它可以退化为“bridge boot config”和“本地运行标记”

### 3. Chats 首页适配

当前 chat list 的 UI 可复用，但数据层要整体替换：

- 初始化进入后调用 `loadChats`
- 使用 `updateNewChat`、`updateChatLastMessage`、`updateChatPosition`、`updateChatReadInbox` 等更新维护列表
- 不建议依赖 `getChats` 作为长期一致性来源；TDLib 文档更建议用 `loadChats + updates`

参考：

- [loadChats](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html)
- [getChats](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html)
- [updateNewMessage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_new_message.html)

### 4. Chat Detail 适配

当前 detail 页结构可复用，但消息数据要改成真实 history + 增量更新：

- 打开会话时调用 `getChatHistory`
- 发送消息时调用 `sendMessage`
- 用 `updateNewMessage`、`updateMessageSendSucceeded`、`updateMessageSendFailed` 等状态驱动 UI
- 当前本地 pending -> sent 动画可保留，但触发源从本地定时器改成真实发送状态

参考：

- [getChatHistory](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html)
- [sendMessage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1send_message.html)

### 5. Contacts 适配

当前 contacts 壳可以保留，但数据要改成 Telegram 联系人：

- 初始列表用 `getContacts`
- 搜索用 `searchContacts`
- 点击联系人进入私聊时，用 `createPrivateChat`

参考：

- [getContacts](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_contacts.html)
- [searchContacts](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1search_contacts.html)
- [createPrivateChat](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1create_private_chat.html)

### 6. Settings 适配

本轮 settings 不需要做深，但至少应从真实账号出发：

- 展示 `getMe` 相关基本资料
- 展示当前连接态 / 授权态 / 本地会话状态
- `Sign out` 需要从 demo clear 升级为真实 logout / close client / 清理本地数据库

## 分阶段开发计划

以下阶段按“先 Android 打通主链路，再 iOS 对齐，再 HOS 过可行性门”的策略制定。

## 阶段 0：技术预研与可行性门

目标：

- 明确 TDLib 在当前仓库中的构建、链接和运行方式
- 确认 Android / iOS 可跑通最小 client
- 对 HOS 做单独 feasibility 判断

交付物：

- `TDLib build spike` 记录
- 原生 bridge 设计说明
- HOS feasibility 结论

验收标准：

- Android 真机或模拟器能完成 `tdjson` 最小 create/send/receive
- iOS 真机或模拟器能完成 `tdjson` 最小 create/send/receive
- HOS 输出明确结论：`可继续` / `高风险需额外 issue`

说明：

- TDLib 官方平台列表未明确列出 HarmonyOS/OpenHarmony；因此“HOS 可直接支持”不是已证事实，而是需要专项验证的推断
- 这个结论来自官方平台列表未包含 HOS，同时官方又提到“其他 *nix 系统可能可工作”，因此 HOS 应被视为高风险探索项，而不是已确认支持项

参考：

- [TDLib platform overview](https://core.telegram.org/tdlib)

## 阶段 1：统一 Bridge 与公共状态层

目标：

- 在 `CJMP` 层建立与 UI 解耦的 Telegram 状态层
- 在 Android / iOS 形成统一 C ABI

任务：

- 定义 `TdBridge` C 接口
- 定义 auth/chat/message/contact/settings 的共享 domain model
- 增加 JSON request builder 与 update parser
- 增加统一 error model

验收标准：

- `CJMP` 可以不依赖 mock 数据启动 Telegram store
- bridge 层可返回真实 TDLib 更新 JSON

## 阶段 2：真实登录与授权态

目标：

- 用真实 Telegram 手机号登录替换 demo login

任务：

- 初始化 `setTdlibParameters`
- 接通手机号提交
- 接通验证码提交流程
- 接通二次密码态
- 接通 `authorizationStateReady` 后的首页跳转
- 处理登录失败、限流、网络失败提示

验收标准：

- Android 真机可用真实账号登录
- iOS 真机可用真实账号登录
- 重启后可恢复到已授权状态

## 阶段 3：真实 Chats 首页

目标：

- 用真实 chat list 替换当前三条硬编码会话

任务：

- `loadChats` 接入
- chat list store 排序与增量更新
- title/snippet/timestamp/unread/pinned/muted 映射
- loading / empty / error / reconnecting 状态适配

验收标准：

- 首页显示真实会话
- 新消息到达后，列表顺序和 unread 能变化
- 不破坏现有流畅滚动体验

## 阶段 4：真实 Chat Detail 与发消息

目标：

- 用真实消息历史与真实发送替换当前 local send

任务：

- `getChatHistory` 接入
- 消息内容映射为现有 bubble UI
- 发送按钮接 `sendMessage`
- pending / sent / failed 映射到真实状态
- 保留 composer 现有交互手感

验收标准：

- 从首页点进真实会话可加载历史
- 在 app 内发一条文本消息，对方真实账号可收到
- 本地发送状态不再依赖固定 `sleep` 模拟

## 阶段 5：真实 Contacts 与基础 Settings

目标：

- 让 Contacts 和 Settings 摆脱纯展示态

任务：

- `getContacts` / `searchContacts` 接入
- 联系人点击可建立私聊
- settings 展示真实账号基础资料
- sign out 改为真实退出

验收标准：

- Contacts 搜索结果来自真实 Telegram 联系人
- 点击联系人可进入对应私聊
- Settings 中手机号/资料来自真实账号

## 阶段 6：iOS 对齐与真实设备验收

目标：

- 将 Android 已打通主链路完整对齐到 iOS

任务：

- iOS bridge 完善
- iOS 真机登录、聊天列表、详情、发送消息验收
- 清理 iOS 特有线程、生命周期、前后台切换问题

验收标准：

- iPhone 真机安装后，登录、浏览、发送消息完整可用

## 阶段 7：HOS 可行性落地或问题归档

目标：

- 视阶段 0 结论推进 HOS

任务：

- 若可行，落地 HOS 原生桥和真机验收
- 若不可行，形成 `reports/cjmp-issues/` 问题文档与证据

验收标准：

- 路径 A：HOS 真机完成登录、聊天列表、详情、发送消息
- 路径 B：明确给出不可落地原因、技术证据、后续建议

## 推荐 issue 拆分

项目约束要求使用 GitHub issues 驱动交付，建议按以下 issue 切分：

1. `CJMP TDLib spike: Android/iOS/HOS feasibility`
2. `CJMP Telegram bridge: tdjson C ABI and shared state layer`
3. `CJMP Telegram auth: real phone/code/password login`
4. `CJMP Telegram chats: real chat list sync`
5. `CJMP Telegram detail: real history and sendMessage`
6. `CJMP Telegram contacts/settings: real data MVP`
7. `CJMP Telegram iOS real-device acceptance`
8. `CJMP Telegram HOS feasibility or delivery`

## 关键风险与应对

### 风险 1：HOS 官方支持不明确

风险：

- TDLib 官方平台说明没有明确列出 HOS / OpenHarmony
- 当前仓库也没有现成 HOS native bridge

应对：

- 把 HOS 放进阶段 0 可行性门
- 不在 Android / iOS 主链路未稳定时同步压上 HOS 复杂实现
- 若失败，沉淀成 `CJMP` friction artifact，而不是口头阻塞

### 风险 2：授权态复杂于现有 demo login

风险：

- 真实 Telegram 登录可能出现 code、2FA password、限流、异常态

应对：

- 保留当前两步式 UI 节奏
- 在现有登录壳基础上增加第三步 `password` 态
- 提前定义 auth state machine，而不是把状态散落在页面事件里

### 风险 3：TDLib 更新流比当前本地状态复杂很多

风险：

- 当前 UI 是页面内局部状态
- 真实 TDLib 是持续 update stream

应对：

- 先抽共享 store，再接真实后端
- 避免页面直接持有“后端真相”

### 风险 4：消息与列表一致性

风险：

- 不能只靠一次性 API 拉取
- 聊天列表排序、未读数、最后一条消息会持续变化

应对：

- chat list 以 updates 为主
- `getChats` 仅作辅助，不作长期真相源

### 风险 5：安全与配置

风险：

- 需要真实 `api_id` / `api_hash`
- 本地数据库目录、加密 key、日志级别需要规范

应对：

- 不把敏感配置硬编码进仓库
- 用本地环境配置注入
- 真实验收前明确数据清理策略

## 真实后端 MVP 验收标准

达到本计划书目标，至少应满足以下最小验收：

1. Android 真机安装包可登录真实 Telegram 账号。
2. iOS 真机安装包可登录真实 Telegram 账号。
3. 登录后可看到真实聊天列表，而非 seed/mock chats。
4. 可进入真实聊天详情，并看到真实历史消息。
5. 可从 app 内发送一条文本消息。
6. 被发送对象的真实 Telegram 账号可在官方 Telegram 客户端中收到该消息。
7. 重启 app 后会话可恢复，不回退到 demo login。
8. Contacts 可展示真实联系人或真实搜索结果。
9. Settings 至少展示真实账号基本信息和真实 sign out 行为。
10. HOS 给出真实可运行结果，或给出有证据的 blocked 结论。

## 建议的实施顺序

为了控制风险和避免多端同时爆炸，推荐顺序为：

1. Android 先打通 TDLib 最小链路
2. 抽象共享状态层，不让 Android 方案写死在 UI 中
3. iOS 对齐登录与 chat/send 主链路
4. 再推进 Contacts / Settings
5. 最后处理 HOS feasibility 和落地

不建议的顺序：

- 先改所有页面，再补后端
- 三端同时硬上 TDLib
- 在 HOS 可行性未确认时承诺同等周期交付

## 结论

当前 `CJMP` 版本并不是“UI 还没 ready”，而是“UI 已具备接入真实后端的形态，但整个数据和授权层仍停留在 demo/mock 阶段”。

因此，下一阶段最合理的策略不是重做界面，而是：

- 保留现有 UI 壳和交互节奏
- 用 `TDLib tdjson` 统一桥接 Android / iOS
- 把 `CJMP` 层升级为可持续消费 TDLib update 的共享状态架构
- 将 HOS 作为高风险专项预研，不在无证据情况下直接承诺等量交付

如果按本计划推进，当前仓库最有希望在较小 UI 返工下，升级为一个“可真实登录、可真实收发消息、可在真实设备演示”的 `CJMP Telegram MVP`。

## 参考资料

- [TDLib GitHub 仓库](https://github.com/tdlib/td)
- [TDLib 概览](https://core.telegram.org/tdlib)
- [TDLib JSON C 接口文档](https://core.telegram.org/tdlib/docs/td__json__client_8h.html)
- [setTdlibParameters](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_tdlib_parameters.html)
- [authorizationStateWaitPhoneNumber](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state_wait_phone_number.html)
- [checkAuthenticationCode](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_code.html)
- [loadChats](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html)
- [getChats](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html)
- [getChatHistory](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html)
- [sendMessage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1send_message.html)
- [getContacts](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_contacts.html)
- [searchContacts](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1search_contacts.html)
- [createPrivateChat](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1create_private_chat.html)
