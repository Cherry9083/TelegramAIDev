# CJMP TDLib 真实登录切片设计

## 目标

将“登录页面能够成功运行”作为独立小目标，先打通 `CJMP` 版本 Telegram-like Demo 的真实 TDLib 登录链路，而不同时推进 chats、contacts、settings 的真实数据接入。

这里的“成功运行”定义为：

- Android 真机或模拟器可以从当前登录页进入真实 TDLib 授权流程
- iOS 真机或模拟器可以从当前登录页进入真实 TDLib 授权流程
- 用户可在现有登录壳中完成手机号输入、验证码输入、必要时的二次密码输入
- 收到 `authorizationStateReady` 后可跳转到现有首页壳
- 重启后可恢复到已授权状态，至少不回退到 demo login

相关需求：

- `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md`

## 范围

### 本切片要做

- 把当前 demo login 改造成真实 TDLib auth login
- 把 `phase0` 探针升级为可长期运行的最小 TDLib bridge
- 在 `CJMP` 层新增仅服务登录的最小 auth state/facade/store
- 替换登录页提交行为和启动恢复逻辑
- 增加登录链路的 smoke / 手工验收能力

### 本切片不做

- 真实 chats 列表同步
- 真实 chat detail / 发消息
- 真实 contacts / settings 数据映射
- HOS 正式登录交付
- 登录页视觉重做

## 当前现状

当前仓库已经具备以下基础：

- 登录页壳层、启动 loading、手机号页、验证码页、inline 错误提示已经存在，代码在 `apps/cjmp/lib/index.cj`
- demo session 的本地持久化和恢复已经存在，代码在 `apps/cjmp/lib/demo_session_store.cj`
- Android / iOS 已完成 `phase0` 级别的 TDLib 原生探针，代码在 `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`、`apps/cjmp/ios/oc_bridge/cjmp_ffi.m`、`apps/cjmp/lib/tdjson_phase0_probe.cj`
- smoke 基础设施已经存在，代码在 `apps/cjmp/lib/ui_test_page.cj`、`apps/cjmp/lib/ui_test_smoke_case.cj`

当前缺口也很明确：

- 当前 `tdjson` 接入还只是“一次性 probe”，不是可长期运行的 client
- 当前登录状态机完全是 demo 逻辑，不消费真实 TDLib update
- 当前 session restore 只恢复 demo phone，不恢复 TDLib 授权态

## 设计原则

- 以最小实现先打通真实登录，复杂性能优化和高可靠性增强延后
- 保留现有登录 UI 壳和交互节奏，只替换行为和状态来源
- 优先服务登录，不提前建设 chats/message/contact/settings 的完整共享层
- `CJMP` 只依赖统一 C ABI，不直接依赖 Java / Objective-C 登录逻辑
- 按 TDLib 官方异步模型实现，`receive` 结果必须按顺序处理
- 先做 `poll/drain` 模式，不在本切片引入复杂 callback 反调
- 轮询循环必须是阻塞式 `poll(timeout)`，不做短间隔 busy loop
- 同一 TDLib client 的 `poll` 必须只有一个 owner；页面层不能直接调用 `poll`
- 真实登录态恢复依赖 TDLib database 和 database encryption key，不再依赖 demo phone 持久化

TDLib 相关依据：

- `td_json_client_create/send/receive/destroy` 构成异步 JSON client 主链路
- `authorizationStateWaitTdlibParameters` 时必须调用 `setTdlibParameters`
- `authorizationStateWaitPhoneNumber` 时调用 `setAuthenticationPhoneNumber`
- `authorizationStateWaitCode` 时调用 `checkAuthenticationCode`
- `authorizationStateWaitPassword` 时调用 `checkAuthenticationPassword`
- 收到 `authorizationStateReady` 才表示登录完成
- 收到 `authorizationStateClosed` 后需要重新创建 client 才能继续工作
- `connectionStateWaitingForNetwork` 表示等待网络恢复，不应通过空轮询自旋补偿
- `close()` 会正常关闭本地数据库，`destroy()` 会销毁本地数据且可在未授权前调用，`logOut()` 会在联网情况下退出登录并销毁本地数据

## 目标状态机

登录切片完成后，应用启动和登录页应遵循如下状态机：

1. app 启动，创建 TDLib client
2. bridge 开始持续 `poll` TDLib update / response
3. `CJMP` auth facade 处理 `updateAuthorizationState`
4. 根据授权状态驱动 UI：
5. `authorizationStateWaitTdlibParameters`：自动发送 `setTdlibParameters`
6. `authorizationStateWaitPhoneNumber`：显示手机号输入页
7. `authorizationStateWaitCode`：显示验证码输入页
8. `authorizationStateWaitPassword`：显示二次密码输入页
9. `authorizationStateReady`：进入首页壳
10. `connectionStateWaitingForNetwork`：保留当前输入内容，展示网络等待提示
11. `authorizationStateClosed`：进入失败态，提供“重新开始登录”入口，由用户显式重启授权流

补充约束：

- 登录切片默认 `poll timeout` 使用 `1000ms`
- `poll` 返回空结果时直接继续下一次阻塞式 `poll`，不额外 `sleep`
- 全流程使用同一个固定 `poll timeout`，不做动态调频
- `dispose()` 必须能停止轮询循环
- 用户从验证码页或密码页返回手机号页时，不直接调用 `logOut()`；应销毁当前未完成授权的 client，并重新创建新 client 回到 `waiting_phone_number`

## 建议新增的最小结构

本切片只引入支撑登录所必需的最小结构。

### CJMP 层

- `telegram_tdlib_bridge.cj`
- `telegram_tdlib_facade.cj`
- `telegram_auth_store.cj`
- `telegram_auth_models.cj`
- `telegram_runtime_config.cj`

建议职责：

- `telegram_tdlib_bridge.cj`
  - 声明跨平台 `foreign` C ABI
  - 封装 `create/send/poll/destroy/free-string`
- `telegram_tdlib_facade.cj`
  - 管理单个 TDLib client 生命周期
  - 启动后台轮询
  - 将 update / response 分发给 auth store
  - 保证同一时刻只有一个轮询循环持有该 client 的 `poll` ownership
  - 在 auth submit 未完成前拒绝重复提交
- `telegram_auth_store.cj`
  - 保存登录页需要的 view state
  - 暴露当前 auth step、loading、notice、canSubmit、isReady
- `telegram_auth_models.cj`
  - 定义最小 auth domain model 和 error model
- `telegram_runtime_config.cj`
  - 统一 `api_id` / `api_hash` / database path / files path / device info 注入
  - 统一 database encryption key 的生成、读取和删除策略

### Native 层

Android 和 iOS 统一暴露最小 ABI：

- `FfiTdBridgeCreateClient(config_json: CString): Int64`
- `FfiTdBridgeSend(handle: Int64, request_json: CString): Int64`
- `FfiTdBridgePoll(handle: Int64, timeout_ms: Int64): CString`
- `FfiTdBridgeDestroy(handle: Int64): Unit`
- `FfiTdBridgeSetLogVerbosity(level: Int64): Unit`
- `FfiTdBridgeFreeString(value: CString): Unit`

约束：

- `handle == 0` 视为创建失败
- `poll` 返回空字符串或约定空值表示 timeout，无 update
- 所有返回的 `CString` 都必须由 `CJMP` 侧调用 `FfiTdBridgeFreeString`
- 同一个 handle 的 `poll` 不允许并发调用
- `destroy` 与 `poll` 之间需要明确生命周期顺序，避免销毁旧 handle 时仍有旧轮询循环运行

## 最小 auth model

本切片不追求完整 TDLib typed model，只先定义登录所需字段。

### AuthorizationStep

- `booting`
- `waiting_tdlib_parameters`
- `waiting_phone_number`
- `waiting_code`
- `waiting_password`
- `ready`
- `closed`
- `failed`

### AuthViewState

- `step`
- `isBusy`
- `primaryNotice`
- `connectionNotice`
- `phoneNumber`
- `code`
- `password`
- `canSubmitPhone`
- `canSubmitCode`
- `canSubmitPassword`
- `isRestoringSession`
- `lastTdErrorCode`
- `lastTdErrorMessage`
- `isWaitingForNetwork`

### ConnectionState

- `unknown`
- `connecting`
- `ready`
- `updating`
- `waiting_for_network`
- `connecting_to_proxy`

### TdAuthUpdate

- `authorization_state_type`
- `code_info_summary`
- `password_hint`
- `is_ready`
- `is_closed`

### TdError

- `code`
- `message`
- `request_type`

## UI 设计调整

现有登录页视觉结构尽量不变，只增加必要状态。

### 保留

- 启动 loading 页面
- 手机号输入页
- 验证码输入页
- inline notice
- `Keep me signed in` 控件

### 新增

- `Password` 步骤页
- auth loading 文案
- TDLib 初始化失败文案
- 网络失败或限流错误提示
- 网络等待提示和“重新开始登录”入口

### 替换

- `submitPhoneEntry` 从本地校验后切验证码，改为发 `setAuthenticationPhoneNumber`
- `submitVerification` 从本地 code 校验后直接进首页，改为发 `checkAuthenticationCode`
- `enterHomeShell` 的触发条件改为 `authorizationStateReady`
- `beginBootstrap` 的 demo session restore 改为 TDLib session restore bootstrap
- 验证码页或密码页的“返回”行为改为重启 auth bootstrap，而不是只切本地 step

## 开发步骤

以下步骤按“先底层可持续运行，再接登录 UI，再做恢复与验收”的顺序执行。

### 步骤 1：把 phase0 探针升级为可复用 bridge

目标：

- 让 Android / iOS 不再只是 `getTextEntities` probe，而是能创建长期存活的 TDLib client

开发动作：

- 在 `apps/cjmp/android/app/src/main/cpp/cjmp.cpp` 中新增 handle 化 client registry
- 在 `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` 中新增对应的 client registry
- 把当前 `dlopen + dlsym` 逻辑沉淀成共享的符号解析和 client create/destroy/send/poll 能力
- 保留原有 `phase0` probe，作为回归用探针，不作为正式登录链路入口
- 在 native registry 中做最小 handle 生命周期保护，避免已销毁 handle 被继续调用

完成标准：

- `CJMP` 可调用 `create/send/poll/destroy`
- `poll` 可持续返回 TDLib JSON update / response
- Android / iOS 行为一致

验证方式：

- 新增一个仅 bridge 层 smoke，用 `create -> poll` 至少拿到一次 `updateAuthorizationState`

### 步骤 2：引入运行时配置注入

目标：

- 给 `setTdlibParameters` 提供完整配置，不把敏感值硬编码进仓库

开发动作：

- 设计 `telegram_runtime_config.cj`，统一读取运行时配置
- 明确 Android / iOS 如何提供：
  - `api_id`
  - `api_hash`
  - `database_directory`
  - `files_directory`
  - `database_encryption_key`
  - `system_language_code`
  - `device_model`
  - `application_version`
- 明确 `database_encryption_key` 的平台存储策略：
  - 本切片先使用应用私有存储保存 key
  - 首次允许“Keep me signed in”时生成随机 key
  - 后续 restore 时读取同一 key
  - 用户关闭“Keep me signed in”或显式退出时删除 key 和 TDLib 本地 database
  - 若后续需要更强安全性，再升级到平台安全存储
- 约定缺配置时的失败文案和失败状态

完成标准：

- 登录页启动时可构造合法的 `setTdlibParameters` request
- 缺失敏感配置时，用户能看到明确失败提示，而不是 silent fail

验证方式：

- 手工验证空配置和有效配置两条路径

### 步骤 3：增加 CJMP 侧最小 bridge 封装

目标：

- 在 `CJMP` 层拿到稳定的 bridge API，不让页面直接碰 `foreign func`

开发动作：

- 新增 `telegram_tdlib_bridge.cj`
- 封装：
  - `createTdClient(configJson)`
  - `sendTdRequest(handle, requestJson)`
  - `pollTdUpdate(handle, timeoutMs)`
  - `destroyTdClient(handle)`
- 补齐字符串释放逻辑和返回值判空逻辑

完成标准：

- 页面和 store 层不再直接依赖原生 `foreign func`

验证方式：

- 单独构造 bridge 层最小 smoke，确认 `create` 成功且 `poll` 可返回结果

### 步骤 4：实现最小 auth facade

目标：

- 把 TDLib 的 update stream 转成登录页能消费的状态

开发动作：

- 新增 `telegram_tdlib_facade.cj`
- facade 内部持有单一 TDLib client handle
- 在后台 `spawn` 一个轮询循环，持续 `poll`
- 轮询循环固定使用 `1000ms` timeout
- `poll` 只允许由 facade 私有循环调用，不暴露给页面层
- facade 内部维护 `isDisposed`
- 识别并处理：
  - `updateAuthorizationState`
  - `updateConnectionState`
  - 请求响应中的 `error`
  - timeout / empty response
- 在 `authorizationStateWaitTdlibParameters` 时自动发送 `setTdlibParameters`
- 在 `connectionStateWaitingForNetwork` 时更新 store 网络提示，但不通过 busy retry 自旋
- 在 `authorizationStateClosed` 时进入失败态，并暴露“重新开始登录”动作
- 提供 `dispose()` 停止轮询循环并回收 handle
- facade 内部只允许一个 auth submit in-flight，重复点击直接忽略

完成标准：

- 启动后无需用户交互即可自动推进到 `waiting_phone_number` 或恢复到 `ready`

验证方式：

- 日志和 smoke 中能观测到 `booting -> waiting_tdlib_parameters -> waiting_phone_number` 的状态迁移

### 步骤 5：实现最小 auth store

目标：

- 让登录 UI 只依赖 view state，不直接解释 TDLib JSON

开发动作：

- 新增 `telegram_auth_models.cj`
- 新增 `telegram_auth_store.cj`
- store 对外提供：
  - 当前 step
  - notice / error
  - connection state
  - submit loading
  - `submitPhoneNumber`
  - `submitCode`
  - `submitPassword`
  - `restartAuthorization`
  - `bootstrap`
  - `dispose`
- store 内部把 facade 事件翻译成页面状态
- store 需要对快速重复点击做幂等保护：
  - 同一步骤 submit 未返回前，按钮 disabled
  - 收到响应或错误前忽略重复点击

完成标准：

- 登录页只消费 auth store，不再消费 demo login 本地状态机

验证方式：

- 用假 update 或真实 update 驱动 store，确认 step 和 notice 转换正确

### 步骤 6：替换当前登录页行为

目标：

- 保留现有视觉壳，但把行为切换到真实 TDLib auth

开发动作：

- 修改 `apps/cjmp/lib/index.cj`
- 删除或旁路以下 demo 登录关键路径：
  - `submitPhoneEntry` 里的本地延时切步骤
  - `submitVerification` 里的本地持久化后跳首页
  - `beginBootstrap` 里的 `resolveDemoSessionRestoreState`
- 新增 `Password` 页面状态和输入框
- 新增网络等待和“重新开始登录”入口
- 启动时调用 auth store `bootstrap`
- 根据 auth store step 渲染：
  - phone
  - code
  - password
  - loading
  - failure
- 仅在 `ready` 时执行 `Router.push(url: ROUTE_HOME_SHELL)`

完成标准：

- 登录页可以完整经历 phone/code/password/ready 中的任一必要路径

验证方式：

- 手工验证手机号提交后能停在验证码页
- 输入正确验证码后能进入首页
- 开启 2FA 的账号能停在密码页并完成登录

### 步骤 7：替换 session restore 方案

目标：

- 从 demo session 恢复迁移到 TDLib 自身授权恢复

开发动作：

- 收缩 `demo_session_store.cj` 的职责，避免其继续作为真实登录态来源
- `Keep me signed in` 改成控制是否保留 TDLib database / encryption key
- 启动时优先创建 TDLib client 并观察授权状态，而不是先读 demo phone
- sign out 路径暂只要求支持“关闭 client 并清理本地登录数据”的最小版本
- 未授权状态下用户取消当前登录流程时，优先走 `destroy()` + 新建 client 的 restart auth 路径
- 已授权状态下用户显式退出时，后续切片再完善 `logOut()` 细节，本切片不扩展 settings 退出交互

完成标准：

- 已授权用户重启 app 后，不需要重新输入手机号验证码

验证方式：

- 真机或模拟器完成一次登录后重启 app，确认可回到已授权路径

### 步骤 8：补齐错误态和可观测性

目标：

- 让登录失败可诊断、可展示、可复现

开发动作：

- 为常见错误建立统一文案映射：
  - 配置缺失
  - 网络失败
  - 验证码错误
  - 二次密码错误
  - 限流或稍后重试
  - client closed
- 明确恢复路径：
  - `waiting_for_network`：保留输入，展示等待网络提示；网络恢复后由用户重新提交
  - `authorizationStateClosed`：进入失败态，由用户点击“重新开始登录”
  - 用户从 code/password 返回 phone：销毁当前未授权 client，重新 bootstrap
- 在 facade/store 中增加关键日志点
- 在 smoke trace 中输出 auth step 迁移

完成标准：

- 登录失败时，页面能给出用户可理解提示
- 开发调试时，日志能定位失败发生在哪个状态
- 常见失败场景都有明确恢复动作，而不只是错误展示

验证方式：

- 手工构造错误手机号、错误验证码、错误密码等路径

### 步骤 9：扩展 smoke 与人工验收

目标：

- 让“登录页成功运行”成为可重复验证的小目标

开发动作：

- 在 `apps/cjmp/lib/ui_test_smoke_case.cj` 增加 auth-first smoke
- smoke 至少覆盖：
  - bridge create 成功
  - 能拿到授权状态更新
  - 连接状态可映射到 UI 提示
  - 登录页能根据 store 状态切换 phone/code/password
- 对真实账号登录保留人工验收，不把真实凭证写入自动化

完成标准：

- 自动化至少覆盖“桥接 + 状态机 + UI 切换”
- 真机人工验收覆盖“真实手机号登录成功”

验证方式：

- Android 手工验收
- iOS 手工验收
- smoke 回归

## 推荐代码改动顺序

建议按以下顺序提交，减少大改冲突：

1. 原生 bridge handle 化
2. `CJMP` bridge 封装
3. runtime config 注入
4. auth models + facade + store
5. 登录页接 auth store
6. session restore 替换
7. smoke 与验收补齐

## 关键风险

### 风险 1：把登录直接写进页面状态机

后果：

- 页面会直接理解 TDLib 状态和错误，后续 chats 接入时难以复用

控制：

- 登录页只消费 auth store，不解析原始 JSON

### 风险 2：把完整 phase1 一次做完

后果：

- 为 chats/messages/contacts 提前设计过多抽象，拖慢登录目标

控制：

- 本切片只做 auth-first 最小共享层

### 风险 3：错误地保留 demo session 为真实登录真相源

后果：

- 页面可能出现“demo restore 成功但 TDLib 未授权”的假成功状态

控制：

- 真实登录态只以 TDLib 授权状态为准

### 风险 4：忽略 database key 和本地目录约束

后果：

- 登录一次成功，但重启后无法恢复

控制：

- 把 database path、files path、encryption key 作为设计内显式项，不延后

## 完成定义

满足以下条件即可认为本切片完成：

1. Android 能从当前登录页走通真实手机号登录。
2. iOS 能从当前登录页走通真实手机号登录。
3. 登录页能根据 TDLib 授权状态切换 phone/code/password/ready。
4. 登录成功跳首页的条件是 `authorizationStateReady`，不是 demo session 写入成功。
5. 重启后能恢复到已授权状态。
6. 仓库内有最小 smoke 或可重复验证步骤覆盖 bridge 和登录状态机。

## 后续衔接

本切片完成后，下一步再进入“真实 chats 首页”切片会更稳，因为届时已经具备：

- 可长期运行的 TDLib client
- 可复用的请求发送与 update drain 能力
- 真实授权恢复能力
- 不再依赖 demo login 的 app 启动入口
