package ohos_app_cangjie_entry

let TELEGRAM_SEND_STATE_IDLE = "idle"
let TELEGRAM_SEND_STATE_PENDING = "pending"
let TELEGRAM_SEND_STATE_SENT = "sent"
let TELEGRAM_SEND_STATE_ERROR = "error"
let TELEGRAM_SEND_DEFAULT_NOTICE = "Telegram did not accept the message yet."

var telegramMessageSendState: String = TELEGRAM_SEND_STATE_IDLE
var telegramMessageSendNoticeState: String = ""
var telegramMessageSendPendingExtraState: String = ""
var telegramMessageSendPendingTextState: String = ""
var telegramMessageSendPendingChatIdState: Int64 = 0
var telegramMessageSendSequenceState: Int64 = 0
var telegramMessageSendVersionState: Int64 = 0

func resetTelegramMessageSendState(): Unit {
    telegramMessageSendState = TELEGRAM_SEND_STATE_IDLE
    telegramMessageSendNoticeState = ""
    telegramMessageSendPendingExtraState = ""
    telegramMessageSendPendingTextState = ""
    telegramMessageSendPendingChatIdState = 0
    telegramMessageSendVersionState++
}

func telegramMessageSendVersion(): Int64 {
    return telegramMessageSendVersionState
}

func telegramMessageSendNotice(): String {
    return telegramMessageSendNoticeState
}

func telegramMessageSendPendingExtra(): String {
    return telegramMessageSendPendingExtraState
}

func beginTelegramMessageSend(chatId: Int64, text: String): String {
    telegramMessageSendSequenceState++
    let extra = "send-message-${telegramMessageSendSequenceState}"
    telegramMessageSendState = TELEGRAM_SEND_STATE_PENDING
    telegramMessageSendNoticeState = ""
    telegramMessageSendPendingExtraState = extra
    telegramMessageSendPendingTextState = text
    telegramMessageSendPendingChatIdState = chatId
    telegramMessageSendVersionState++
    return extra
}

func markTelegramMessageSendAccepted(extra: String): Bool {
    if (extra.isEmpty() || extra != telegramMessageSendPendingExtraState) {
        return false
    }
    telegramMessageSendState = TELEGRAM_SEND_STATE_SENT
    telegramMessageSendNoticeState = ""
    telegramMessageSendPendingExtraState = ""
    telegramMessageSendVersionState++
    return true
}

func markTelegramMessageSendFailed(extra: String, notice: String): Bool {
    if (extra.isEmpty() || extra != telegramMessageSendPendingExtraState) {
        return false
    }
    telegramMessageSendState = TELEGRAM_SEND_STATE_ERROR
    telegramMessageSendNoticeState = if (notice.isEmpty()) { TELEGRAM_SEND_DEFAULT_NOTICE } else { notice }
    telegramMessageSendPendingExtraState = ""
    telegramMessageSendVersionState++
    return true
}
