package ohos_app_cangjie_entry

import std.time.*
import encoding.json.*
internal import ohos.base.AppLog

// 命令行风格的TDLib测试
// 直接在控制台输出，不依赖UI

public func runTelegramCliTest(apiId: String, apiHash: String, phoneNumber: String): Bool {
    AppLog.info("========================================")
    AppLog.info("Telegram TDLib 连接测试")
    AppLog.info("========================================")
    AppLog.info("API ID: ${apiId}")
    AppLog.info("API Hash: ${apiHash}")
    AppLog.info("手机号: ${phoneNumber}")
    AppLog.info("========================================")

    // 1. 设置日志级别
    AppLog.info("[步骤1] 设置TDLib日志级别...")
    if (!setTelegramTdLogVerbosity(2)) {
        AppLog.error("❌ 设置日志级别失败")
        return false
    }
    AppLog.info("✅ 日志级别设置成功")

    // 2. 创建客户端
    AppLog.info("[步骤2] 创建TDLib客户端...")
    let clientHandle = createTelegramTdClient()
    if (clientHandle == 0) {
        AppLog.error("❌ 创建TDLib客户端失败")
        return false
    }
    AppLog.info("✅ TDLib客户端创建成功，handle=${clientHandle}")

    // 3. 获取应用文件目录
    let filesDir = getApplicationFilesDir()
    AppLog.info("[步骤3] 应用文件目录: ${filesDir}")

    var currentState = "init"
    var maxSteps = 50
    var stepCount = 0

    // 4. 开始处理更新
    AppLog.info("[步骤4] 开始处理TDLib更新...")
    while (stepCount < maxSteps) {
        stepCount++

        // 轮询更新
        let updateJson = pollTelegramTdUpdate(clientHandle, 1000)

        if (updateJson.isEmpty()) {
            AppLog.info("[轮询${stepCount}] 无更新，继续等待...")
            continue
        }

        AppLog.info("[轮询${stepCount}] 收到更新")
        AppLog.info("JSON: ${updateJson}")

        // 解析更新
        try {
            let jsonValue = JsonValue.fromStr(updateJson)
            if (jsonValue is JsonObject) {
                let obj = jsonValue as JsonObject
                let updateType = obj.get("@type")?.toString() ?? ""

                if (updateType == "updateAuthorizationState") {
                    let authState = obj.get("authorization_state")
                    if (authState is JsonObject) {
                        let stateObj = authState as JsonObject
                        let stateType = stateObj.get("@type")?.toString() ?? ""

                        AppLog.info(">>> 授权状态: ${stateType}")

                        if (stateType == "authorizationStateWaitTdlibParameters") {
                            currentState = "waitParams"
                            AppLog.info("[动作] 发送TDLib参数...")

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
                                "device_model": "CJMP CLI Test",
                                "system_version": "1.0",
                                "application_version": "1.0"
                            }
                            """

                            if (sendTelegramTdRequest(clientHandle, request)) {
                                AppLog.info("✅ TDLib参数发送成功")
                            } else {
                                AppLog.error("❌ TDLib参数发送失败")
                                destroyTelegramTdClient(clientHandle)
                                return false
                            }
                        } else if (stateType == "authorizationStateWaitPhoneNumber") {
                            currentState = "waitPhone"
                            AppLog.info("[动作] 发送手机号...")

                            let request = """
                            {
                                "@type": "setAuthenticationPhoneNumber",
                                "phone_number": "${phoneNumber}"
                            }
                            """

                            if (sendTelegramTdRequest(clientHandle, request)) {
                                AppLog.info("✅ 手机号发送成功")
                            } else {
                                AppLog.error("❌ 手机号发送失败")
                                destroyTelegramTdClient(clientHandle)
                                return false
                            }
                        } else if (stateType == "authorizationStateWaitCode") {
                            currentState = "waitCode"
                            AppLog.info("========================================")
                            AppLog.info("✅✅✅ 成功！")
                            AppLog.info("========================================")
                            AppLog.info("已进入等待验证码状态")
                            AppLog.info("请检查手机是否收到验证码")

                            let codeInfo = stateObj.get("code_info")
                            if (codeInfo != None) {
                                AppLog.info("验证码信息: ${codeInfo.toString()}")
                            }
                            AppLog.info("========================================")

                            // 测试成功，清理并退出
                            destroyTelegramTdClient(clientHandle)
                            return true
                        } else if (stateType == "authorizationStateReady") {
                            AppLog.info("✅ 已授权（之前登录过）")
                            destroyTelegramTdClient(clientHandle)
                            return true
                        } else if (stateType == "authorizationStateClosed") {
                            AppLog.info("客户端已关闭")
                            destroyTelegramTdClient(clientHandle)
                            return false
                        } else {
                            AppLog.info("其他授权状态: ${stateType}")
                        }
                    }
                } else if (updateType == "error") {
                    let code = obj.get("code")?.toString() ?? "unknown"
                    let message = obj.get("message")?.toString() ?? "unknown"
                    AppLog.error("========================================")
                    AppLog.error("❌ 收到错误")
                    AppLog.error("错误码: ${code}")
                    AppLog.error("错误信息: ${message}")
                    AppLog.error("========================================")
                    destroyTelegramTdClient(clientHandle)
                    return false
                } else {
                    AppLog.info("其他更新类型: ${updateType}")
                }
            }
        } catch (e: Exception) {
            AppLog.error("解析JSON失败: ${e.message}")
        }
    }

    AppLog.info("达到最大步骤数，测试超时")
    destroyTelegramTdClient(clientHandle)
    return false
}

// 使用示例：
// runTelegramCliTest("12345678", "your_api_hash", "+8613800138000")
