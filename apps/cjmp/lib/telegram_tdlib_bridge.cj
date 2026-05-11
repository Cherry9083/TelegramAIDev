package ohos_app_cangjie_entry

func createTelegramTdClient(): Int64 {
    return unsafe { FfiTdBridgeCreateClient() }
}

func sendTelegramTdRequest(handle: Int64, requestJson: String): Bool {
    AppLog.info("sendTelegramTdRequest: ENTER, handle=${handle}, jsonLength=${requestJson.size}")
    let requestCString = unsafe { LibC.mallocCString(requestJson) }
    AppLog.info("sendTelegramTdRequest: mallocCString completed, calling FfiTdBridgeSend")
    let result = unsafe { FfiTdBridgeSend(handle, requestCString) }
    AppLog.info("sendTelegramTdRequest: FfiTdBridgeSend returned ${result}")
    unsafe { LibC.free(requestCString) }
    AppLog.info("sendTelegramTdRequest: EXIT, result=${result == 1}")
    return result == 1
}

func pollTelegramTdUpdate(handle: Int64, timeoutMs: Int64): String {
    let response = unsafe { FfiTdBridgePoll(handle, timeoutMs) }
    let value = response.toString()
    unsafe { FfiFreeString(response) }
    return value
}

func destroyTelegramTdClient(handle: Int64): Bool {
    return unsafe { FfiTdBridgeDestroy(handle) } == 1
}

func setTelegramTdLogVerbosity(level: Int64): Bool {
    return unsafe { FfiTdBridgeSetLogVerbosity(level) } == 1
}

func getApplicationFilesDir(): String {
    let response = unsafe { FfiGetApplicationFilesDir() }
    let value = response.toString()
    unsafe { FfiFreeString(response) }
    return value
}

func clearTelegramTdLocalData(): Bool {
    return unsafe { FfiClearTelegramTdLocalData() } == 1
}

@When[target_platform == "android"]
func isAndroidEmulatorRuntime(): Bool {
    return unsafe { FfiIsAndroidEmulator() } == 1
}

@When[target_platform == "android"]
func canReachAndroidLoopbackPort(port: Int64): Bool {
    return unsafe { FfiCanReachAndroidLoopbackPort(port) } == 1
}

@When[target_platform != "android"]
func canReachAndroidLoopbackPort(port: Int64): Bool {
    let _ = port
    return false
}

@When[target_platform != "android"]
func isAndroidEmulatorRuntime(): Bool {
    return false
}

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiGetApplicationFilesDir(): CString

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiTdBridgeCreateClient(): Int64

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiTdBridgeSend(handle: Int64, requestJson: CString): Int64

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiTdBridgePoll(handle: Int64, timeoutMs: Int64): CString

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiTdBridgeDestroy(handle: Int64): Int64

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiTdBridgeSetLogVerbosity(level: Int64): Int64

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiClearTelegramTdLocalData(): Int64

@When[target_platform == "android"]
foreign func FfiIsAndroidEmulator(): Int64

@When[target_platform == "android"]
foreign func FfiCanReachAndroidLoopbackPort(port: Int64): Int64
