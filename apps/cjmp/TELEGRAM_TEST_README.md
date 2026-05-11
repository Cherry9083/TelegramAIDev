# Telegram TDLib 简单连接测试

## 目的
验证TDLib能否正常连接到Telegram后端，并能收到验证码。

## 使用步骤

### 1. 获取Telegram API凭证

访问 https://my.telegram.org/apps 获取：
- `api_id` (数字)
- `api_hash` (字符串)

### 2. 修改测试配置

编辑 `lib/telegram_simple_test.cj`，修改以下三个值：

```cangjie
private let apiId: String = "YOUR_API_ID"  // 替换为你的API ID，例如："12345678"
private let apiHash: String = "YOUR_API_HASH"  // 替换为你的API Hash
private let phoneNumber: String = "YOUR_PHONE_NUMBER"  // 替换为你的手机号，格式：+86xxxxxxxxxx
```

### 3. 运行测试

在应用中调用：
```cangjie
runTelegramSimpleTest()
```

### 4. 查看结果

测试会自动执行以下步骤：
1. 创建TDLib客户端
2. 发送TDLib参数（包含api_id和api_hash）
3. 发送手机号
4. 等待验证码状态

**成功标志**：日志中出现 `✅ 成功！等待验证码状态，请检查手机是否收到验证码`

此时检查你的手机（或Telegram应用），应该能收到验证码短信或应用内通知。

### 5. 日志输出示例

成功的日志应该类似：
```
=== TelegramSimpleTest: 开始测试 ===
日志级别设置成功
TDLib客户端创建成功，handle=1
步骤1: 收到更新: {"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitTdlibParameters"}}
授权状态: authorizationStateWaitTdlibParameters
发送TDLib参数...
TDLib参数发送成功
步骤2: 收到更新: {"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPhoneNumber"}}
授权状态: authorizationStateWaitPhoneNumber
发送手机号: +86xxxxxxxxxx
手机号发送成功，等待验证码...
步骤3: 收到更新: {"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitCode",...}}
授权状态: authorizationStateWaitCode
✅ 成功！等待验证码状态，请检查手机是否收到验证码
=== 测试结束 ===
```

## 故障排查

### 错误：创建TDLib客户端失败
- 检查libtdjson.so是否正确加载
- 运行 `FfiRunTdjsonPhase0Probe()` 验证TDLib库

### 错误：收到error类型的更新
- 检查api_id和api_hash是否正确
- 检查手机号格式（必须包含国家码，如+86）
- 查看错误消息中的具体原因

### 没有收到验证码
- 确认日志显示已进入authorizationStateWaitCode状态
- 检查手机号是否正确
- 检查手机是否能正常接收短信
- 如果之前登录过，可能会通过Telegram应用发送验证码而不是短信

## 下一步

测试成功后，可以继续实现：
1. 输入验证码的功能
2. 完整的登录流程
3. 集成到应用UI中
