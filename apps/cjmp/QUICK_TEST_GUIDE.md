# Telegram TDLib 快速测试指南

## 目标
用最简单的方式验证TDLib能否连接Telegram后端并收到验证码。

## 快速开始（3步）

### 1. 获取Telegram API凭证
访问 https://my.telegram.org/apps 登录后创建应用，获取：
- `api_id` (纯数字，例如：12345678)
- `api_hash` (32位字符串)

### 2. 配置测试参数
编辑 `lib/telegram_quick_test.cj`，修改这三行：

```cangjie
let TEST_API_ID = "12345678"  // 你的API ID
let TEST_API_HASH = "abcdef1234567890abcdef1234567890"  // 你的API Hash
let TEST_PHONE_NUMBER = "+8613800138000"  // 你的手机号（必须带国家码）
```

### 3. 运行测试

**方法A：在应用启动时自动运行**

编辑 `lib/index.cj`，在 `beginBootstrap()` 函数中添加：

```cangjie
func beginBootstrap(): Unit {
    // ... 现有代码 ...
    
    // 添加这一行来运行测试
    let _ = spawn { quickTestTelegramConnection() }
    
    // ... 其余代码 ...
}
```

**方法B：手动调用**

在任何地方调用：
```cangjie
quickTestTelegramConnection()
```

## 预期结果

### 成功的日志输出
```
========================================
Telegram TDLib 连接测试
========================================
API ID: 12345678
API Hash: abcdef...
手机号: +8613800138000
========================================
[步骤1] 设置TDLib日志级别...
✅ 日志级别设置成功
[步骤2] 创建TDLib客户端...
✅ TDLib客户端创建成功，handle=1
[步骤3] 应用文件目录: /data/...
[步骤4] 开始处理TDLib更新...
[轮询1] 收到更新
>>> 授权状态: authorizationStateWaitTdlibParameters
[动作] 发送TDLib参数...
✅ TDLib参数发送成功
[轮询2] 收到更新
>>> 授权状态: authorizationStateWaitPhoneNumber
[动作] 发送手机号...
✅ 手机号发送成功
[轮询3] 收到更新
>>> 授权状态: authorizationStateWaitCode
========================================
✅✅✅ 成功！
========================================
已进入等待验证码状态
请检查手机是否收到验证码
========================================
```

**此时检查你的手机，应该能收到Telegram验证码！**

## 常见问题

### Q: 显示"请先配置"
A: 你还没有修改 `telegram_quick_test.cj` 中的三个配置值。

### Q: 创建TDLib客户端失败
A: 检查libtdjson.so是否正确加载。可以先运行：
```cangjie
let probe = unsafe { FfiRunTdjsonPhase0Probe() }
AppLog.info("TDLib探测结果: ${probe.toString()}")
```

### Q: 收到error错误
A: 检查日志中的错误信息：
- `PHONE_NUMBER_INVALID`: 手机号格式错误（必须带+86等国家码）
- `API_ID_INVALID`: API ID错误
- `API_ID_PUBLISHED_FLOOD`: API凭证被滥用，等待一段时间

### Q: 没有收到验证码
A: 如果日志显示已进入 `authorizationStateWaitCode` 状态，说明连接成功。验证码可能：
- 通过短信发送（检查短信）
- 通过Telegram应用发送（如果你在其他设备登录过）
- 被运营商拦截（尝试其他手机号）

## 文件说明

- `telegram_quick_test.cj` - 配置文件和快速入口
- `telegram_cli_test.cj` - 核心测试逻辑
- `telegram_tdlib_bridge.cj` - TDLib FFI封装

## 下一步

测试成功后，你可以：
1. 实现验证码输入功能
2. 完成完整的登录流程
3. 集成到应用UI中

测试代码已经是最简化的版本，只验证连接性，不做其他操作。
