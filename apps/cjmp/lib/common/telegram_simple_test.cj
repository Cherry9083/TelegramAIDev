@NonProduct
features {}

package ohos_app_cangjie_entry

import std.time.*
import std.collection.*
import encoding.json.*

// 简单的TDLib连接测试
// 用于验证能否连接到Telegram后端并收到验证码

class TelegramSimpleTest {
    private var clientHandle: Int64 = 0
    private var isRunning: Bool = false

    // 测试配置 - 需要用户提供真实的值
    private let apiId: String = "YOUR_API_ID"  // 替换为真实的API ID
    private let apiHash: String = "YOUR_API_HASH"  // 替换为真实的API Hash
    private let phoneNumber: String = "YOUR_PHONE_NUMBER"  // 替换为真实的手机号，格式：+86xxxxxxxxxx

    public init() {}

    // 启动测试
    public func start(): Bool {
        AppLog.info("=== TelegramSimpleTest: 开始测试 ===")

        // 1. 设置日志级别
        if (!setTelegramTdLogVerbosity(2)) {
            AppLog.error("设置日志级别失败")
            return false
        }
        AppLog.info("日志级别设置成功")

        // 2. 创建客户端
        clientHandle = createTelegramTdClient()
        if (clientHandle == 0) {
            AppLog.error("创建TDLib客户端失败")
            return false
        }
        AppLog.info("TDLib客户端创建成功，handle=${clientHandle}")

        isRunning = true

        // 3. 开始处理更新
        processUpdates()

        return true
    }

    // 处理TDLib更新
    private func processUpdates() {
        var step = 0
        while (isRunning && step < 100) {  // 最多100次循环，防止无限循环
            step++

            // 轮询更新，超时1秒
            let updateJson = pollTelegramTdUpdate(clientHandle, 1000)

            if (updateJson.isEmpty()) {
                AppLog.info("步骤${step}: 没有更新")
                continue
            }

            AppLog.info("步骤${step}: 收到更新: ${updateJson}")

            // 解析JSON
            try {
                let jsonValue = JsonValue.fromStr(updateJson)
                if (jsonValue is JsonObject) {
                    let obj = jsonValue as JsonObject
                    let updateType = obj.get("@type")?.toString() ?? ""

                    AppLog.info("更新类型: ${updateType}")

                    // 根据不同的状态处理
                    match (updateType) {
                        case "updateAuthorizationState" => {
                            handleAuthorizationState(obj)
                        }
                        case "error" => {
                            let code = obj.get("code")?.toString() ?? "unknown"
                            let message = obj.get("message")?.toString() ?? "unknown"
                            AppLog.error("收到错误: code=${code}, message=${message}")
                            isRunning = false
                        }
                        case _ => {
                            AppLog.info("其他更新类型: ${updateType}")
                        }
                    }
                }
            } catch (e: Exception) {
                AppLog.error("解析JSON失败: ${e.message}")
            }
        }

        AppLog.info("=== 测试结束 ===")
        cleanup()
    }

    // 处理授权状态
    private func handleAuthorizationState(obj: JsonObject) {
        let authState = obj.get("authorization_state")
        if (authState is JsonObject) {
            let stateObj = authState as JsonObject
            let stateType = stateObj.get("@type")?.toString() ?? ""

            AppLog.info("授权状态: ${stateType}")

            match (stateType) {
                case "authorizationStateWaitTdlibParameters" => {
                    sendTdlibParameters()
                }
                case "authorizationStateWaitPhoneNumber" => {
                    sendPhoneNumber()
                }
                case "authorizationStateWaitCode" => {
                    AppLog.info("✅ 成功！等待验证码状态，请检查手机是否收到验证码")
                    let codeInfo = stateObj.get("code_info")
                    if (codeInfo != None) {
                        AppLog.info("验证码信息: ${codeInfo.toString()}")
                    }
                    isRunning = false  // 测试成功，停止
                }
                case "authorizationStateReady" => {
                    AppLog.info("✅ 已授权！")
                    isRunning = false
                }
                case "authorizationStateClosed" => {
                    AppLog.info("客户端已关闭")
                    isRunning = false
                }
                case _ => {
                    AppLog.info("其他授权状态: ${stateType}")
                }
            }
        }
    }

    // 发送TDLib参数
    private func sendTdlibParameters() {
        AppLog.info("发送TDLib参数...")

        let filesDir = getApplicationFilesDir()
        AppLog.info("应用文件目录: ${filesDir}")

        let request = """
        {
            "@type": "setTdlibParameters",
            "use_test_dc": false,
            "database_directory": "${filesDir}/tdlib",
            "files_directory": "${filesDir}/tdlib_files",
            "database_encryption_key": "",
            "use_file_database": true,
            "use_chat_info_database": true,
            "use_message_database": true,
            "use_secret_chats": false,
            "api_id": ${apiId},
            "api_hash": "${apiHash}",
            "system_language_code": "zh-CN",
            "device_model": "CJMP Test",
            "system_version": "1.0",
            "application_version": "1.0"
        }
        """

        if (sendTelegramTdRequest(clientHandle, request)) {
            AppLog.info("TDLib参数发送成功")
        } else {
            AppLog.error("TDLib参数发送失败")
            isRunning = false
        }
    }

    // 发送手机号
    private func sendPhoneNumber() {
        AppLog.info("发送手机号: ${phoneNumber}")

        let request = """
        {
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": "${phoneNumber}"
        }
        """

        if (sendTelegramTdRequest(clientHandle, request)) {
            AppLog.info("手机号发送成功，等待验证码...")
        } else {
            AppLog.error("手机号发送失败")
            isRunning = false
        }
    }

    // 清理资源
    private func cleanup() {
        if (clientHandle != 0) {
            AppLog.info("销毁TDLib客户端")
            destroyTelegramTdClient(clientHandle)
            clientHandle = 0
        }
    }
}

// 测试入口函数
public func runTelegramSimpleTest(): Bool {
    AppLog.info("开始运行Telegram简单连接测试")
    let test = TelegramSimpleTest()
    return test.start()
}
