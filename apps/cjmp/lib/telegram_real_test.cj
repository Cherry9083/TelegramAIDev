// 实际测试运行 - 使用真实凭证
package ohos_app_cangjie_entry

// 使用真实凭证进行测试
public func runRealTelegramTest(): Bool {
    AppLog.info("=== 开始真实Telegram连接测试 ===")

    let apiId = ""
    let apiHash = ""
    let phoneNumber = "+"

    AppLog.info("API ID: ${apiId}")
    AppLog.info("手机号: ${phoneNumber}")

    let test = QuickTelegramTest(apiId, apiHash, phoneNumber)
    return test.run()
}

class QuickTelegramTest {
    private var clientHandle: Int64 = 0
    private var isRunning: Bool = false
    private let apiId: String
    private let apiHash: String
    private let phoneNumber: String

    public init(apiId: String, apiHash: String, phoneNumber: String) {
        this.apiId = apiId
        this.apiHash = apiHash
        this.phoneNumber = phoneNumber
    }

    public func run(): Bool {
        AppLog.info("=== 快速Telegram测试 ===")
        AppLog.info("API ID: ${apiId}")
        AppLog.info("手机号: ${phoneNumber}")

        // 设置日志
        if (!setTelegramTdLogVerbosity(2)) {
            AppLog.error("设置日志失败")
            return false
        }

        // 创建客户端
        clientHandle = createTelegramTdClient()
        if (clientHandle == 0) {
            AppLog.error("创建客户端失败")
            return false
        }
        AppLog.info("✓ 客户端创建成功 (handle=${clientHandle})")

        isRunning = true
        processLoop()
        return true
    }

    private func processLoop() {
        var step = 0
        while (isRunning && step < 50) {
            step++
            let update = pollTelegramTdUpdate(clientHandle, 1000)

            if (update.isEmpty()) {
                continue
            }

            AppLog.info("[${step}] ${update}")

            // 简单状态处理
            if (update.contains("authorizationStateWaitTdlibParameters")) {
                sendParams()
            } else if (update.contains("authorizationStateWaitPhoneNumber")) {
                sendPhone()
            } else if (update.contains("authorizationStateWaitCode")) {
                AppLog.info("✅ 成功！等待验证码 - 请检查手机 ${phoneNumber}")
                isRunning = false
            } else if (update.contains("authorizationStateReady")) {
                AppLog.info("✅ 已登录")
                isRunning = false
            } else if (update.contains("\"@type\":\"error\"")) {
                AppLog.error("错误: ${update}")
                isRunning = false
            }
        }

        if (clientHandle != 0) {
            destroyTelegramTdClient(clientHandle)
        }
    }

    private func sendParams() {
        let dir = getApplicationFilesDir()
        let req = """
        {
            "@type": "setTdlibParameters",
            "use_test_dc": false,
            "database_directory": "${dir}/tdlib",
            "files_directory": "${dir}/tdlib_files",
            "database_encryption_key": "",
            "use_file_database": true,
            "use_chat_info_database": true,
            "use_message_database": true,
            "use_secret_chats": false,
            "api_id": ${apiId},
            "api_hash": "${apiHash}",
            "system_language_code": "zh-CN",
            "device_model": "CJMP Real Test",
            "system_version": "1.0",
            "application_version": "1.0"
        }
        """
        sendTelegramTdRequest(clientHandle, req)
        AppLog.info("✓ 参数已发送")
    }

    private func sendPhone() {
        let req = """
        {
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": "${phoneNumber}"
        }
        """
        sendTelegramTdRequest(clientHandle, req)
        AppLog.info("✓ 手机号已发送: ${phoneNumber}")
    }
}
