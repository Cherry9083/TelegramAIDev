package ohos_app_cangjie_entry

import std.collection.{ArrayList, HashMap}
import std.unicode.*

let TELEGRAM_CONTACTS_KIND_IDLE = "idle"
let TELEGRAM_CONTACTS_KIND_LOADING = "loading"
let TELEGRAM_CONTACTS_KIND_POPULATED = "populated"
let TELEGRAM_CONTACTS_KIND_EMPTY = "empty"
let TELEGRAM_CONTACTS_KIND_ERROR = "error"

public class TelegramContactRow <: ToString & Hashable & Equatable<TelegramContactRow> {
    public let userId: Int64
    public var displayName: String
    public var statusLabel: String

    public init(userId: Int64, displayName: String, statusLabel: String) {
        this.userId = userId
        this.displayName = displayName
        this.statusLabel = statusLabel
    }

    public operator func ==(other: TelegramContactRow): Bool {
        return this.userId == other.userId
    }

    public func hashCode(): Int64 {
        return this.userId
    }

    public func toString(): String {
        return "TelegramContactRow(${this.userId}, ${this.displayName})"
    }
}

var telegramContactRowsState: ArrayList<TelegramContactRow> = ArrayList<TelegramContactRow>()
var telegramContactsByUserIdState: HashMap<Int64, TelegramContactRow> = HashMap<Int64, TelegramContactRow>()
var telegramContactsKindState: String = TELEGRAM_CONTACTS_KIND_IDLE
var telegramContactsNoticeState: String = ""
var telegramContactsVersionState: Int64 = 0
var telegramContactsLoadedState: Bool = false
var telegramContactsRequestedState: Bool = false

func resetTelegramContactsState(): Unit {
    telegramContactRowsState = ArrayList<TelegramContactRow>()
    telegramContactsByUserIdState = HashMap<Int64, TelegramContactRow>()
    telegramContactsKindState = TELEGRAM_CONTACTS_KIND_IDLE
    telegramContactsNoticeState = ""
    telegramContactsLoadedState = false
    telegramContactsRequestedState = false
    telegramContactsVersionState++
}

func telegramContactsRows(): ArrayList<TelegramContactRow> {
    return telegramContactRowsState
}

func telegramContactsKind(): String {
    return telegramContactsKindState
}

func telegramContactsNotice(): String {
    return telegramContactsNoticeState
}

func telegramContactsVersion(): Int64 {
    return telegramContactsVersionState
}

func hasTelegramContactsLoaded(): Bool {
    return telegramContactsLoadedState
}

func isTelegramContactsRequested(): Bool {
    return telegramContactsRequestedState
}

func markTelegramContactsRequested(): Unit {
    telegramContactsRequestedState = true
}

func clearTelegramContactsRequested(): Unit {
    telegramContactsRequestedState = false
}

func setTelegramContactsKind(kind: String, notice!: String = ""): Unit {
    telegramContactsKindState = kind
    telegramContactsNoticeState = notice
    telegramContactsVersionState++
}

func telegramContactDisplayName(firstName: String, lastName: String, fallbackUserId: Int64): String {
    let name = "${firstName} ${lastName}".trim()
    if (!name.isEmpty()) {
        return name
    }
    return "Telegram user ${fallbackUserId}"
}

func telegramContactStatusLabel(statusType: String): String {
    if (statusType == "userStatusOnline") {
        return HOME_CONTACT_STATUS_ONLINE
    }
    if (statusType == "userStatusRecently") {
        return HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY
    }
    if (statusType == "userStatusOffline") {
        return "last seen recently"
    }
    return HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY
}

func telegramContactsStateAfterMutation(): Unit {
    if (!telegramAuthIsReadyState) {
        setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_IDLE)
        return
    }
    if (telegramContactRowsState.isEmpty()) {
        if (hasTelegramContactsLoaded()) {
            setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_EMPTY)
        } else {
            setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_LOADING)
        }
        return
    }
    setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_POPULATED)
}

func upsertTelegramContactRow(row: TelegramContactRow): Unit {
    let previous = telegramContactsByUserIdState.add(row.userId, row)
    match (previous) {
        case Some(existing) =>
            var replaced: Bool = false
            for (index in 0..=telegramContactRowsState.size - 1 where telegramContactRowsState.size > 0) {
                if (telegramContactRowsState[index].userId == existing.userId) {
                    telegramContactRowsState[index] = row
                    replaced = true
                    break
                }
            }
            if (!replaced) {
                telegramContactRowsState.add(row)
            }
        case None =>
            telegramContactRowsState.add(row)
    }
    telegramContactsVersionState++
    telegramContactsStateAfterMutation()
}

func markTelegramContactsLoaded(): Unit {
    telegramContactsLoadedState = true
    clearTelegramContactsRequested()
    telegramContactsStateAfterMutation()
}
