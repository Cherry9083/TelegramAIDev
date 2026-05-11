package ohos_app_cangjie_entry

import stdx.encoding.json.*
import std.convert.*
import std.unicode.*

let TELEGRAM_RUNTIME_CONFIG_EMPTY_NOTICE = "Enter Telegram API ID and API hash to continue."
let TELEGRAM_DEFAULT_PROXY_HOST = ""
let TELEGRAM_DEFAULT_PROXY_PORT = ""
let TELEGRAM_ANDROID_LOOPBACK_PROXY_HOST = "127.0.0.1"
let TELEGRAM_ANDROID_LOOPBACK_PROXY_PORT = "7897"
let TELEGRAM_EMULATOR_PROXY_HOST = "10.0.2.2"
let TELEGRAM_EMULATOR_PROXY_PORT = "7897"

var cachedTelegramRuntimeConfigJson: String = ""
var cachedTelegramSessionKey: String = ""

func isDigitsOnly(value: String): Bool {
    if (value.isEmpty()) {
        return false
    }
    for (digit in value.runes()) {
        if (digit < r'0' || digit > r'9') {
            return false
        }
    }
    return true
}

func generateTelegramSessionKeySeed(): String {
    return "cjmp-tdlib-key-static"
}

func normalizeTelegramApiId(value: String): String {
    return value.trim()
}

func normalizeTelegramApiHash(value: String): String {
    return value.trim()
}

func normalizeTelegramProxyHost(value: String): String {
    return value.trim()
}

func normalizeTelegramProxyPort(value: String): String {
    return value.trim()
}

func defaultTelegramProxyHost(): String {
    if (isAndroidEmulatorRuntime()) {
        return TELEGRAM_EMULATOR_PROXY_HOST
    }
    if (canReachAndroidLoopbackPort(parseTelegramProxyPort(TELEGRAM_ANDROID_LOOPBACK_PROXY_PORT))) {
        return TELEGRAM_ANDROID_LOOPBACK_PROXY_HOST
    }
    return TELEGRAM_DEFAULT_PROXY_HOST
}

func defaultTelegramProxyPort(): String {
    if (isAndroidEmulatorRuntime()) {
        return TELEGRAM_EMULATOR_PROXY_PORT
    }
    if (canReachAndroidLoopbackPort(parseTelegramProxyPort(TELEGRAM_ANDROID_LOOPBACK_PROXY_PORT))) {
        return TELEGRAM_ANDROID_LOOPBACK_PROXY_PORT
    }
    return TELEGRAM_DEFAULT_PROXY_PORT
}

func parseTelegramProxyPort(value: String): Int64 {
    try {
        return Int64.parse(normalizeTelegramProxyPort(value))
    } catch (_: Exception) {
        return 0
    }
}

func buildTelegramRuntimeConfigJson(
    apiId: String,
    apiHash: String,
    keepSignedIn: Bool
): String {
    let root = JsonObject()
    root.put("api_id", JsonString(normalizeTelegramApiId(apiId)))
    root.put("api_hash", JsonString(normalizeTelegramApiHash(apiHash)))
    root.put("keep_signed_in", JsonBool(keepSignedIn))
    return root.toString()
}

func readJsonStringField(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) =>
            if (value is JsonString) {
                return value.asString().getValue()
            }
        case None => return ""
    }
    return ""
}

func readJsonBoolField(object: JsonObject, key: String, fallback: Bool): Bool {
    match (object.get(key)) {
        case Some(value) =>
            if (value is JsonBool) {
                return value.asBool().getValue()
            }
        case None => return fallback
    }
    return fallback
}

func loadTelegramRuntimeConfigJson(): String {
    if (!cachedTelegramRuntimeConfigJson.isEmpty()) {
        return cachedTelegramRuntimeConfigJson
    }
    let value = readTelegramRuntimeConfigStorage()
    cachedTelegramRuntimeConfigJson = value
    return value
}

func saveTelegramRuntimeConfigJson(configJson: String): Bool {
    cachedTelegramRuntimeConfigJson = configJson
    return writeTelegramRuntimeConfigStorage(configJson)
}

func clearTelegramRuntimeConfigJson(): Unit {
    cachedTelegramRuntimeConfigJson = ""
    clearTelegramRuntimeConfigStorage()
}

func loadTelegramApiId(): String {
    let configJson = loadTelegramRuntimeConfigJson()
    if (configJson.isEmpty()) {
        return ""
    }
    try {
        let root = JsonValue.fromStr(configJson).asObject()
        return readJsonStringField(root, "api_id")
    } catch (_: Exception) {
        return ""
    }
}

func loadTelegramApiHash(): String {
    let configJson = loadTelegramRuntimeConfigJson()
    if (configJson.isEmpty()) {
        return ""
    }
    try {
        let root = JsonValue.fromStr(configJson).asObject()
        return readJsonStringField(root, "api_hash")
    } catch (_: Exception) {
        return ""
    }
}

func loadTelegramKeepSignedIn(): Bool {
    let configJson = loadTelegramRuntimeConfigJson()
    if (configJson.isEmpty()) {
        return true
    }
    try {
        let root = JsonValue.fromStr(configJson).asObject()
        return readJsonBoolField(root, "keep_signed_in", true)
    } catch (_: Exception) {
        return true
    }
}

func loadTelegramProxyHost(): String {
    return defaultTelegramProxyHost()
}

func loadTelegramProxyPort(): String {
    return defaultTelegramProxyPort()
}

func persistTelegramRuntimeConfig(
    apiId: String,
    apiHash: String,
    keepSignedIn: Bool
): Bool {
    return saveTelegramRuntimeConfigJson(
        buildTelegramRuntimeConfigJson(apiId, apiHash, keepSignedIn)
    )
}

func hasValidTelegramRuntimeConfig(apiId: String, apiHash: String): Bool {
    return isDigitsOnly(normalizeTelegramApiId(apiId)) && !normalizeTelegramApiHash(apiHash).isEmpty()
}

func hasValidTelegramProxyConfig(proxyHost: String, proxyPort: String): Bool {
    if (normalizeTelegramProxyHost(proxyHost).isEmpty()) {
        return true
    }
    if (!isDigitsOnly(normalizeTelegramProxyPort(proxyPort))) {
        return false
    }
    let parsedPort = parseTelegramProxyPort(proxyPort)
    return parsedPort > 0 && parsedPort <= 65535
}

func validateTelegramRuntimeConfig(apiId: String, apiHash: String): String {
    if (!isDigitsOnly(normalizeTelegramApiId(apiId))) {
        return "Telegram API ID must be digits only."
    }
    if (normalizeTelegramApiHash(apiHash).isEmpty()) {
        return "Telegram API hash is required."
    }
    return ""
}

func validateTelegramProxyConfig(proxyHost: String, proxyPort: String): String {
    if (!hasValidTelegramProxyConfig(proxyHost, proxyPort)) {
        return "Telegram connection setup failed."
    }
    return ""
}

func loadTelegramSessionKey(): String {
    if (!cachedTelegramSessionKey.isEmpty()) {
        return cachedTelegramSessionKey
    }
    let value = readTelegramSessionKeyStorage()
    cachedTelegramSessionKey = value
    return value
}

func persistTelegramSessionKey(key: String): Bool {
    cachedTelegramSessionKey = key
    return writeTelegramSessionKeyStorage(key)
}

func clearTelegramSessionKey(): Unit {
    cachedTelegramSessionKey = ""
    clearTelegramSessionKeyStorage()
}

func ensureTelegramSessionKey(keepSignedIn: Bool): String {
    if (!keepSignedIn) {
        cachedTelegramSessionKey = generateTelegramSessionKeySeed()
        return cachedTelegramSessionKey
    }
    let existing = loadTelegramSessionKey()
    if (!existing.isEmpty()) {
        return existing
    }
    let generated = generateTelegramSessionKeySeed()
    let _ = persistTelegramSessionKey(generated)
    return generated
}

@When[target_platform == "ios" || target_platform == "ios-sim"]
func writeTelegramRuntimeConfigStorage(configJson: String): Bool {
    let configCString = unsafe { LibC.mallocCString(configJson) }
    let didPersist = unsafe { FfiSaveTelegramRuntimeConfig(configCString) }
    unsafe { LibC.free(configCString) }
    return didPersist == 1
}

@When[target_platform == "android"]
func writeTelegramRuntimeConfigStorage(configJson: String): Bool {
    let configCString = unsafe { LibC.mallocCString(configJson) }
    let didPersist = unsafe { FfiSaveTelegramRuntimeConfig(configCString) }
    unsafe { LibC.free(configCString) }
    return didPersist == 1
}

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
func readTelegramRuntimeConfigStorage(): String {
    let storedConfig = unsafe { FfiLoadTelegramRuntimeConfig() }
    let result = storedConfig.toString()
    unsafe { FfiFreeString(storedConfig) }
    return result
}

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
func clearTelegramRuntimeConfigStorage(): Unit {
    unsafe { FfiClearTelegramRuntimeConfig() }
}

@When[target_platform == "ios" || target_platform == "ios-sim"]
func writeTelegramSessionKeyStorage(sessionKey: String): Bool {
    let sessionCString = unsafe { LibC.mallocCString(sessionKey) }
    let didPersist = unsafe { FfiSaveTelegramSessionKey(sessionCString) }
    unsafe { LibC.free(sessionCString) }
    return didPersist == 1
}

@When[target_platform == "android"]
func writeTelegramSessionKeyStorage(sessionKey: String): Bool {
    let sessionCString = unsafe { LibC.mallocCString(sessionKey) }
    let didPersist = unsafe { FfiSaveTelegramSessionKey(sessionCString) }
    unsafe { LibC.free(sessionCString) }
    return didPersist == 1
}

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
func readTelegramSessionKeyStorage(): String {
    let storedKey = unsafe { FfiLoadTelegramSessionKey() }
    let result = storedKey.toString()
    unsafe { FfiFreeString(storedKey) }
    return result
}

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
func clearTelegramSessionKeyStorage(): Unit {
    unsafe { FfiClearTelegramSessionKey() }
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func writeTelegramRuntimeConfigStorage(configJson: String): Bool {
    return !configJson.isEmpty()
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func readTelegramRuntimeConfigStorage(): String {
    return ""
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func clearTelegramRuntimeConfigStorage(): Unit {
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func writeTelegramSessionKeyStorage(sessionKey: String): Bool {
    return !sessionKey.isEmpty()
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func readTelegramSessionKeyStorage(): String {
    return ""
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func clearTelegramSessionKeyStorage(): Unit {
}

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiSaveTelegramRuntimeConfig(configJson: CString): Int64

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiLoadTelegramRuntimeConfig(): CString

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiClearTelegramRuntimeConfig(): Unit

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiSaveTelegramSessionKey(sessionKey: CString): Int64

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiLoadTelegramSessionKey(): CString

@When[target_platform == "ios" || target_platform == "ios-sim" || target_platform == "android"]
foreign func FfiClearTelegramSessionKey(): Unit
