package ohos_app_cangjie_entry

internal import ohos.base.AppLog
import std.collection.{ArrayList, HashMap}
import std.sort.*

let TELEGRAM_CHAT_MESSAGES_KIND_IDLE = "idle"
let TELEGRAM_CHAT_MESSAGES_KIND_LOADING = "loading"
let TELEGRAM_CHAT_MESSAGES_KIND_POPULATED = "populated"
let TELEGRAM_CHAT_MESSAGES_KIND_EMPTY = "empty"
let TELEGRAM_CHAT_MESSAGES_KIND_ERROR = "error"
let TELEGRAM_CHAT_MESSAGE_HISTORY_LIMIT: Int64 = 30

public class TelegramChatMessageRow <: ToString & Hashable & Equatable<TelegramChatMessageRow> {
    public let chatId: Int64
    public let messageId: Int64
    public var text: String
    public var timeLabel: String
    public var isOutgoing: Bool
    public var deliveryLabel: String

    public init(
        chatId: Int64,
        messageId: Int64,
        text: String,
        timeLabel: String,
        isOutgoing: Bool,
        deliveryLabel: String
    ) {
        this.chatId = chatId
        this.messageId = messageId
        this.text = text
        this.timeLabel = timeLabel
        this.isOutgoing = isOutgoing
        this.deliveryLabel = deliveryLabel
    }

    public operator func ==(other: TelegramChatMessageRow): Bool {
        return this.chatId == other.chatId && this.messageId == other.messageId
    }

    public func hashCode(): Int64 {
        return this.chatId + this.messageId
    }

    public func toString(): String {
        return "TelegramChatMessageRow(${this.chatId}, ${this.messageId})"
    }
}

var telegramChatMessagesByChatIdState: HashMap<Int64, ArrayList<TelegramChatMessageRow>> =
    HashMap<Int64, ArrayList<TelegramChatMessageRow>>()
var telegramChatMessagesRequestedState: HashMap<Int64, Bool> = HashMap<Int64, Bool>()
var telegramChatMessagesKindState: HashMap<Int64, String> = HashMap<Int64, String>()
var telegramChatMessagesNoticeState: HashMap<Int64, String> = HashMap<Int64, String>()
var telegramChatMessagesVersionState: Int64 = 0

func resetTelegramChatMessagesState(): Unit {
    telegramChatMessagesByChatIdState = HashMap<Int64, ArrayList<TelegramChatMessageRow>>()
    telegramChatMessagesRequestedState = HashMap<Int64, Bool>()
    telegramChatMessagesKindState = HashMap<Int64, String>()
    telegramChatMessagesNoticeState = HashMap<Int64, String>()
    telegramChatMessagesVersionState++
}

func telegramChatMessagesVersion(): Int64 {
    return telegramChatMessagesVersionState
}

func telegramChatMessagesKind(chatId: Int64): String {
    match (telegramChatMessagesKindState.get(chatId)) {
        case Some(kind) => return kind
        case None => return TELEGRAM_CHAT_MESSAGES_KIND_IDLE
    }
}

func telegramChatMessagesNotice(chatId: Int64): String {
    match (telegramChatMessagesNoticeState.get(chatId)) {
        case Some(notice) => return notice
        case None => return ""
    }
}

func telegramChatMessagesRows(chatId: Int64): ArrayList<TelegramChatMessageRow> {
    match (telegramChatMessagesByChatIdState.get(chatId)) {
        case Some(rows) => return rows
        case None => return ArrayList<TelegramChatMessageRow>()
    }
}

func isTelegramChatMessagesRequested(chatId: Int64): Bool {
    match (telegramChatMessagesRequestedState.get(chatId)) {
        case Some(requested) => return requested
        case None => return false
    }
}

func markTelegramChatMessagesRequested(chatId: Int64): Unit {
    let _ = telegramChatMessagesRequestedState.remove(chatId)
    let _ = telegramChatMessagesRequestedState.add(chatId, true)
}

func clearTelegramChatMessagesRequested(chatId: Int64): Unit {
    let _ = telegramChatMessagesRequestedState.remove(chatId)
}

func setTelegramChatMessagesKind(chatId: Int64, kind: String, notice!: String = ""): Unit {
    let _ = telegramChatMessagesKindState.remove(chatId)
    let _ = telegramChatMessagesNoticeState.remove(chatId)
    let _ = telegramChatMessagesKindState.add(chatId, kind)
    let _ = telegramChatMessagesNoticeState.add(chatId, notice)
    telegramChatMessagesVersionState++
    AppLog.info("telegram chat messages: chat=${chatId}, kind=${kind}, version=${telegramChatMessagesVersionState}")
}

func upsertTelegramChatMessageRow(row: TelegramChatMessageRow): Unit {
    var rows: ArrayList<TelegramChatMessageRow>
    match (telegramChatMessagesByChatIdState.get(row.chatId)) {
        case Some(existingRows) => rows = existingRows
        case None =>
            rows = ArrayList<TelegramChatMessageRow>()
            let _ = telegramChatMessagesByChatIdState.add(row.chatId, rows)
    }

    var replaced: Bool = false
    for (index in 0..=rows.size - 1 where rows.size > 0) {
        if (rows[index].messageId == row.messageId) {
            rows[index] = row
            replaced = true
            break
        }
    }
    if (!replaced) {
        rows.add(row)
    }
    sortTelegramChatMessages(rows)
    setTelegramChatMessagesKind(row.chatId, TELEGRAM_CHAT_MESSAGES_KIND_POPULATED)
}

func replaceTelegramChatMessageRow(oldMessageId: Int64, row: TelegramChatMessageRow): Unit {
    if (oldMessageId == 0) {
        upsertTelegramChatMessageRow(row)
        return
    }

    var rows: ArrayList<TelegramChatMessageRow>
    match (telegramChatMessagesByChatIdState.get(row.chatId)) {
        case Some(existingRows) => rows = existingRows
        case None =>
            upsertTelegramChatMessageRow(row)
            return
    }

    var replaced: Bool = false
    for (index in 0..=rows.size - 1 where rows.size > 0) {
        if (rows[index].messageId == oldMessageId || rows[index].messageId == row.messageId) {
            rows[index] = row
            replaced = true
            break
        }
    }
    if (!replaced) {
        rows.add(row)
    }
    sortTelegramChatMessages(rows)
    setTelegramChatMessagesKind(row.chatId, TELEGRAM_CHAT_MESSAGES_KIND_POPULATED)
}

func setTelegramChatMessageHistory(chatId: Int64, rows: ArrayList<TelegramChatMessageRow>): Unit {
    sortTelegramChatMessages(rows)
    let _ = telegramChatMessagesByChatIdState.remove(chatId)
    let _ = telegramChatMessagesByChatIdState.add(chatId, rows)
    AppLog.info("telegram chat messages: history chat=${chatId}, rows=${rows.size}")
    clearTelegramChatMessagesRequested(chatId)
    if (rows.isEmpty()) {
        setTelegramChatMessagesKind(chatId, TELEGRAM_CHAT_MESSAGES_KIND_EMPTY)
    } else {
        setTelegramChatMessagesKind(chatId, TELEGRAM_CHAT_MESSAGES_KIND_POPULATED)
    }
}

func sortTelegramChatMessages(rows: ArrayList<TelegramChatMessageRow>): Unit {
    sort(rows, by: { left: TelegramChatMessageRow, right: TelegramChatMessageRow =>
        return left.messageId.compare(right.messageId)
    })
}
