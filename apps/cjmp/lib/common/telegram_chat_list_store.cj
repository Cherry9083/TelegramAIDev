@NonProduct
features {}

package ohos_app_cangjie_entry

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.sort.*

let TELEGRAM_CHAT_LIST_KIND_IDLE = "idle"
let TELEGRAM_CHAT_LIST_KIND_LOADING = "loading"
let TELEGRAM_CHAT_LIST_KIND_POPULATED = "populated"
let TELEGRAM_CHAT_LIST_KIND_EMPTY = "empty"
let TELEGRAM_CHAT_LIST_KIND_ERROR = "error"

let TELEGRAM_CHAT_LIST_LIMIT: Int64 = 20

public class TelegramChatListRow <: ToString & Hashable & Equatable<TelegramChatListRow> {
    public let chatId: Int64
    public var title: String
    public var snippet: String
    public var timestampLabel: String
    public var unreadCount: Int64
    public var isPinned: Bool
    public var isMuted: Bool
    public var orderKey: Int64

    public init(
        chatId: Int64,
        title: String,
        snippet: String,
        timestampLabel: String,
        unreadCount: Int64,
        isPinned: Bool,
        isMuted: Bool,
        orderKey: Int64
    ) {
        this.chatId = chatId
        this.title = title
        this.snippet = snippet
        this.timestampLabel = timestampLabel
        this.unreadCount = unreadCount
        this.isPinned = isPinned
        this.isMuted = isMuted
        this.orderKey = orderKey
    }

    public operator func ==(other: TelegramChatListRow): Bool {
        return this.chatId == other.chatId
    }

    public func hashCode(): Int64 {
        return this.chatId
    }

    public func toString(): String {
        return "TelegramChatListRow(${this.chatId}, ${this.title})"
    }
}

var telegramChatListRowsState: ArrayList<TelegramChatListRow> = ArrayList<TelegramChatListRow>()
var telegramChatRowsByIdState: HashMap<Int64, TelegramChatListRow> = HashMap<Int64, TelegramChatListRow>()
var telegramChatListKindState: String = TELEGRAM_CHAT_LIST_KIND_IDLE
var telegramChatListNoticeState: String = ""
var telegramChatListVersionState: Int64 = 0
var telegramChatListLoadedState: Bool = false
var telegramChatListLoadRequestedState: Bool = false

func resetTelegramChatListState(): Unit {
    telegramChatListRowsState = ArrayList<TelegramChatListRow>()
    telegramChatRowsByIdState = HashMap<Int64, TelegramChatListRow>()
    telegramChatListKindState = TELEGRAM_CHAT_LIST_KIND_IDLE
    telegramChatListNoticeState = ""
    telegramChatListLoadedState = false
    telegramChatListLoadRequestedState = false
    telegramChatListVersionState++
}

func telegramChatListVersion(): Int64 {
    return telegramChatListVersionState
}

func telegramChatListKind(): String {
    return telegramChatListKindState
}

func telegramChatListNotice(): String {
    return telegramChatListNoticeState
}

func telegramChatListRows(): ArrayList<TelegramChatListRow> {
    return telegramChatListRowsState
}

func telegramChatRowById(chatId: Int64): ?TelegramChatListRow {
    return telegramChatRowsByIdState.get(chatId)
}

func setTelegramChatListKind(kind: String, notice!: String = ""): Unit {
    telegramChatListKindState = kind
    telegramChatListNoticeState = notice
    telegramChatListVersionState++
}

func markTelegramChatListLoaded(): Unit {
    telegramChatListLoadedState = true
}

func hasTelegramChatListLoaded(): Bool {
    return telegramChatListLoadedState
}

func isTelegramChatListLoadRequested(): Bool {
    return telegramChatListLoadRequestedState
}

func markTelegramChatListLoadRequested(): Unit {
    telegramChatListLoadRequestedState = true
}

func clearTelegramChatListLoadRequested(): Unit {
    telegramChatListLoadRequestedState = false
}

func defaultTelegramChatSnippet(): String {
    return "No messages yet"
}

func defaultTelegramChatTimestamp(): String {
    return ""
}

func defaultTelegramChatTitle(chatId: Int64): String {
    return "Chat ${chatId}"
}

func parseTelegramChatOrder(orderValue: String): Int64 {
    if (orderValue.isEmpty() || orderValue == "0") {
        return 0
    }
    try {
        return Int64.parse(orderValue)
    } catch (_: Exception) {
        return 0
    }
}

func upsertTelegramChatRow(row: TelegramChatListRow): Unit {
    let previous = telegramChatRowsByIdState.add(row.chatId, row)
    match (previous) {
        case Some(existing) =>
            var replaced: Bool = false
            for (index in 0..=telegramChatListRowsState.size - 1 where telegramChatListRowsState.size > 0) {
                if (telegramChatListRowsState[index].chatId == existing.chatId) {
                    telegramChatListRowsState[index] = row
                    replaced = true
                    break
                }
            }
            if (!replaced) {
                telegramChatListRowsState.add(row)
            }
        case None =>
            telegramChatListRowsState.add(row)
    }
    sortTelegramChatRows()
    telegramChatListVersionState++
}

func removeTelegramChatRow(chatId: Int64): Unit {
    let removed = telegramChatRowsByIdState.remove(chatId)
    match (removed) {
        case Some(_) =>
            for (index in 0..=telegramChatListRowsState.size - 1 where telegramChatListRowsState.size > 0) {
                if (telegramChatListRowsState[index].chatId == chatId) {
                    let _ = telegramChatListRowsState.remove(at: index)
                    break
                }
            }
            telegramChatListVersionState++
        case None => ()
    }
}

func sortTelegramChatRows(): Unit {
    sort(telegramChatListRowsState, by: { left: TelegramChatListRow, right: TelegramChatListRow =>
        if (left.orderKey != right.orderKey) {
            return right.orderKey.compare(left.orderKey)
        }
        return right.chatId.compare(left.chatId)
    })
}

func telegramChatListStateAfterMutation(): Unit {
    if (!telegramAuthIsReadyState) {
        setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_IDLE)
        return
    }
    if (telegramChatListRowsState.isEmpty()) {
        if (hasTelegramChatListLoaded()) {
            setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_EMPTY)
        } else {
            setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_LOADING)
        }
        return
    }
    setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_POPULATED)
}

func createTelegramChatRow(
    chatId: Int64,
    title: String,
    snippet: String,
    timestampLabel: String,
    unreadCount: Int64,
    isPinned: Bool,
    isMuted: Bool,
    orderKey: String
): TelegramChatListRow {
    return TelegramChatListRow(
        chatId,
        if (title.isEmpty()) { defaultTelegramChatTitle(chatId) } else { title },
        if (snippet.isEmpty()) { defaultTelegramChatSnippet() } else { snippet },
        timestampLabel,
        unreadCount,
        isPinned,
        isMuted,
        parseTelegramChatOrder(orderKey)
    )
}
