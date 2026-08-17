@NonProduct
features {}

package ohos_app_cangjie_entry

let TELEGRAM_SETTINGS_KIND_IDLE = "idle"
let TELEGRAM_SETTINGS_KIND_LOADING = "loading"
let TELEGRAM_SETTINGS_KIND_READY = "ready"
let TELEGRAM_SETTINGS_KIND_ERROR = "error"

var telegramSettingsKindState: String = TELEGRAM_SETTINGS_KIND_IDLE
var telegramSettingsNoticeState: String = ""
var telegramSettingsVersionState: Int64 = 0
var telegramSettingsRequestedState: Bool = false
var telegramSettingsSelfUserIdState: Int64 = 0
var telegramSettingsSelfChatIdState: Int64 = 0
var telegramSettingsDisplayNameState: String = HOME_SETTINGS_PROFILE_TITLE
var telegramSettingsPhoneState: String = HOME_SETTINGS_PROFILE_PHONE

func resetTelegramSettingsState(): Unit {
    telegramSettingsKindState = TELEGRAM_SETTINGS_KIND_IDLE
    telegramSettingsNoticeState = ""
    telegramSettingsRequestedState = false
    telegramSettingsSelfUserIdState = 0
    telegramSettingsSelfChatIdState = 0
    telegramSettingsDisplayNameState = HOME_SETTINGS_PROFILE_TITLE
    telegramSettingsPhoneState = HOME_SETTINGS_PROFILE_PHONE
    telegramSettingsVersionState++
}

func telegramSettingsVersion(): Int64 {
    return telegramSettingsVersionState
}

func telegramSettingsKind(): String {
    return telegramSettingsKindState
}

func telegramSettingsNotice(): String {
    return telegramSettingsNoticeState
}

func telegramSettingsDisplayName(): String {
    return telegramSettingsDisplayNameState
}

func telegramSettingsPhone(): String {
    return telegramSettingsPhoneState
}

func telegramSettingsSelfUserId(): Int64 {
    return telegramSettingsSelfUserIdState
}

func telegramSettingsSelfChatId(): Int64 {
    return telegramSettingsSelfChatIdState
}

func isTelegramSettingsRequested(): Bool {
    return telegramSettingsRequestedState
}

func markTelegramSettingsRequested(): Unit {
    telegramSettingsRequestedState = true
}

func clearTelegramSettingsRequested(): Unit {
    telegramSettingsRequestedState = false
}

func setTelegramSettingsKind(kind: String, notice!: String = ""): Unit {
    telegramSettingsKindState = kind
    telegramSettingsNoticeState = notice
    telegramSettingsVersionState++
}

func upsertTelegramSettingsProfile(userId: Int64, firstName: String, lastName: String, phone: String): Unit {
    if (userId != 0) {
        telegramSettingsSelfUserIdState = userId
    }
    let displayName = telegramContactDisplayName(firstName, lastName, userId)
    if (!displayName.isEmpty()) {
        telegramSettingsDisplayNameState = displayName
    }
    if (!phone.isEmpty()) {
        telegramSettingsPhoneState = "+${phone}"
    }
    telegramSettingsKindState = TELEGRAM_SETTINGS_KIND_READY
    telegramSettingsNoticeState = ""
    telegramSettingsVersionState++
}

func setTelegramSettingsSelfChatId(chatId: Int64): Unit {
    if (chatId == 0) {
        return
    }
    telegramSettingsSelfChatIdState = chatId
    telegramSettingsVersionState++
}

func preferredTelegramSendChatId(currentChatId: Int64): Int64 {
    if (currentChatId != 0) {
        return currentChatId
    }
    return telegramSettingsSelfChatIdState
}
