@NonProduct
features {}

package ohos_app_cangjie_entry

internal import ohos.base.AppLog

// 快速测试入口
// 修改下面的三个值，然后在应用启动时调用 quickTestTelegramConnection()

// ⚠️ 请修改这三个值为你的真实信息
let TEST_API_ID = "YOUR_API_ID"
let TEST_API_HASH = "YOUR_API_HASH"
let TEST_PHONE_NUMBER = "YOUR_PHONE"

// 快速测试函数
public func quickTestTelegramConnection(): Bool {
    AppLog.info("===========================================")
    AppLog.info("快速测试 Telegram 连接")
    AppLog.info("===========================================")

    // 检查是否已配置
    if (TEST_API_ID == "YOUR_API_ID" ||
        TEST_API_HASH == "YOUR_API_HASH" ||
        TEST_PHONE_NUMBER == "YOUR_PHONE") {
        AppLog.error("❌ 请先在 telegram_quick_test.cj 中配置:")
        AppLog.error("   - TEST_API_ID")
        AppLog.error("   - TEST_API_HASH")
        AppLog.error("   - TEST_PHONE_NUMBER")
        AppLog.error("===========================================")
        return false
    }

    // 运行测试
    return runTelegramCliTest(TEST_API_ID, TEST_API_HASH, TEST_PHONE_NUMBER)
}

// 如果你想在应用启动时自动运行测试，可以在 index.cj 的 beginBootstrap() 中添加：
// let _ = spawn { quickTestTelegramConnection() }
