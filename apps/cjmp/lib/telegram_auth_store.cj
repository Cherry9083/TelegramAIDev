package ohos_app_cangjie_entry

var telegramAuthKeepSignedInState: Bool = true
var telegramAuthStepState: String = TELEGRAM_AUTH_STEP_BOOTING
var telegramAuthNoticeState: String = ""
var telegramAuthConnectionNoticeState: String = ""
var telegramAuthIsReadyState: Bool = false
var telegramAuthRestorePendingState: Bool = false
var telegramAuthLastPhoneNumberState: String = ""
var telegramAuthCurrentApiIdState: String = ""
var telegramAuthCurrentApiHashState: String = ""
var telegramAuthCurrentProxyHostState: String = TELEGRAM_DEFAULT_PROXY_HOST
var telegramAuthCurrentProxyPortState: String = TELEGRAM_DEFAULT_PROXY_PORT

func resetTelegramAuthState(): Unit {
    telegramAuthStepState = TELEGRAM_AUTH_STEP_BOOTING
    telegramAuthNoticeState = ""
    telegramAuthConnectionNoticeState = ""
    telegramAuthIsReadyState = false
    telegramAuthRestorePendingState = false
}

func telegramAuthStep(): String {
    return telegramAuthStepState
}

func telegramAuthNotice(): String {
    return telegramAuthNoticeState
}

func telegramAuthConnectionNotice(): String {
    return telegramAuthConnectionNoticeState
}

func isTelegramAuthReady(): Bool {
    return telegramAuthIsReadyState
}

func telegramAuthStoredPhoneNumber(): String {
    return telegramAuthLastPhoneNumberState
}

func telegramAuthApiId(): String {
    return telegramAuthCurrentApiIdState
}

func telegramAuthApiHash(): String {
    return telegramAuthCurrentApiHashState
}

func telegramAuthKeepSignedIn(): Bool {
    return telegramAuthKeepSignedInState
}

func telegramAuthProxyHost(): String {
    return telegramAuthCurrentProxyHostState
}

func telegramAuthProxyPort(): String {
    return telegramAuthCurrentProxyPortState
}

func setTelegramAuthKeepSignedIn(isOn: Bool): Unit {
    telegramAuthKeepSignedInState = isOn
}

func setTelegramAuthRuntimeConfig(
    apiId: String,
    apiHash: String,
    keepSignedIn: Bool
): Bool {
    let normalizedApiId = normalizeTelegramApiId(apiId)
    let normalizedApiHash = normalizeTelegramApiHash(apiHash)
    let validationNotice = validateTelegramRuntimeConfig(normalizedApiId, normalizedApiHash)
    if (!validationNotice.isEmpty()) {
        telegramAuthNoticeState = validationNotice
        return false
    }
    if (!persistTelegramRuntimeConfig(
        normalizedApiId,
        normalizedApiHash,
        keepSignedIn
    )) {
        telegramAuthNoticeState = "Failed to save Telegram API configuration on this device."
        return false
    }
    telegramAuthCurrentApiIdState = normalizedApiId
    telegramAuthCurrentApiHashState = normalizedApiHash
    telegramAuthKeepSignedInState = keepSignedIn
    telegramAuthCurrentProxyHostState = defaultTelegramProxyHost()
    telegramAuthCurrentProxyPortState = defaultTelegramProxyPort()
    return true
}

func ensureTelegramAuthRuntimeConfigLoaded(): Unit {
    telegramAuthCurrentApiIdState = loadTelegramApiId()
    telegramAuthCurrentApiHashState = loadTelegramApiHash()
    telegramAuthKeepSignedInState = loadTelegramKeepSignedIn()
    telegramAuthCurrentProxyHostState = loadTelegramProxyHost()
    telegramAuthCurrentProxyPortState = loadTelegramProxyPort()
}

func consumeTelegramAuthRestoreReady(): Bool {
    if (!telegramAuthRestorePendingState) {
        return false
    }
    telegramAuthRestorePendingState = false
    return true
}
