@NonProduct
features {}

package ohos_app_cangjie_entry

internal import ohos.base.AppLog
import std.collection.{ArrayList, HashMap}
internal import stdx.encoding.json.*
import std.convert.*
import std.unicode.*

let TELEGRAM_DEFAULT_DEVICE_MODEL = "CJMP Demo"
let TELEGRAM_DEFAULT_APPLICATION_VERSION = "1.0"
let TELEGRAM_DEFAULT_LANGUAGE_CODE = "en"
let TELEGRAM_TD_POLL_TIMEOUT_MS: Int64 = 0
let TELEGRAM_TD_IDLE_SLEEP_MS: Int64 = 250

var telegramAuthClientHandle: Int64 = 0
var telegramAuthPollingDisposed: Bool = true
var telegramAuthPollingStarted: Bool = false
var telegramAuthBootstrapSubmitted: Bool = false
var telegramAuthProxyEnabled: Bool = false
var telegramAuthPendingAuthorizationState: String = ""
var telegramAuthEncryptionKeySubmitted: Bool = false
var telegramAuthSubmitInFlight: Bool = false
var telegramAuthLastRawUpdate: String = ""
var telegramAuthEmptyPollCount: Int64 = 0

func resetTelegramAuthFacadeState(): Unit {
    telegramAuthBootstrapSubmitted = false
    telegramAuthProxyEnabled = false
    telegramAuthPendingAuthorizationState = ""
    telegramAuthEncryptionKeySubmitted = false
    telegramAuthSubmitInFlight = false
    telegramAuthLastRawUpdate = ""
    telegramAuthEmptyPollCount = 0
}

func isTelegramAuthBusy(): Bool {
    return (telegramAuthClientHandle != 0 && telegramAuthStepState == TELEGRAM_AUTH_STEP_BOOTING) ||
        telegramAuthSubmitInFlight
}

func isTelegramAuthClientStarted(): Bool {
    return telegramAuthClientHandle != 0
}

func buildTelegramTdRequestWithExtra(requestType: String, extra: String): JsonObject {
    let root = JsonObject()
    root.put("@type", JsonString(requestType))
    root.put("@extra", JsonString(extra))
    return root
}

func buildTelegramTdGetOptionRequest(name: String): String {
    let root = buildTelegramTdRequestWithExtra("getOption", "kickstart-${name}")
    root.put("name", JsonString(name))
    return root.toString()
}

func buildTelegramTdProxyType(proxyTypeName: String): JsonObject {
    let proxyType = JsonObject()
    if (proxyTypeName == TELEGRAM_PROXY_TYPE_HTTP) {
        proxyType.put("@type", JsonString("proxyTypeHttp"))
        proxyType.put("username", JsonString(""))
        proxyType.put("password", JsonString(""))
        proxyType.put("http_only", JsonBool(false))
        return proxyType
    }
    proxyType.put("@type", JsonString("proxyTypeSocks5"))
    proxyType.put("username", JsonString(""))
    proxyType.put("password", JsonString(""))
    return proxyType
}

func buildTelegramTdAddProxyRequest(host: String, port: String, proxyType: String): String {
    let proxyTypeObject = buildTelegramTdProxyType(proxyType)

    let proxy = JsonObject()
    proxy.put("@type", JsonString("proxy"))
    proxy.put("server", JsonString(normalizeTelegramProxyHost(host)))
    proxy.put("port", JsonInt(parseTelegramProxyPort(port)))
    proxy.put("type", proxyTypeObject)

    let root = buildTelegramTdRequestWithExtra("addProxy", "bootstrap-proxy")
    root.put("proxy", proxy)
    root.put("enable", JsonBool(true))
    let proxyComment = if (proxyType == TELEGRAM_PROXY_TYPE_HTTP) {
        "system http"
    } else {
        "local socks5"
    }
    root.put("comment", JsonString(proxyComment))
    return root.toString()
}

func buildTelegramTdAddSocks5ProxyRequest(host: String, port: String): String {
    return buildTelegramTdAddProxyRequest(host, port, TELEGRAM_PROXY_TYPE_SOCKS5)
}

func buildTelegramTdSetParametersRequest(apiId: String, apiHash: String): String {
    AppLog.info("buildTelegramTdSetParametersRequest: START")

    let normalizedApiId = normalizeTelegramApiId(apiId)
    let normalizedApiHash = normalizeTelegramApiHash(apiHash)
    AppLog.info("buildTelegramTdSetParametersRequest: normalized apiId length=${normalizedApiId.size}, apiHash length=${normalizedApiHash.size}")

    var parsedApiId: Int64 = 0
    try {
        parsedApiId = Int64.parse(normalizedApiId)
        AppLog.info("buildTelegramTdSetParametersRequest: parsed apiId=${parsedApiId}")
    } catch (e: Exception) {
        AppLog.error("buildTelegramTdSetParametersRequest: FAILED to parse apiId, exception=${e}")
        parsedApiId = 0
    }

    if (parsedApiId == 0) {
        AppLog.error("buildTelegramTdSetParametersRequest: ERROR - parsedApiId is 0!")
    }

    // Get absolute paths for TDLib directories using application files directory
    let filesDir = getApplicationFilesDir()
    let dbDir = "${filesDir}/telegram_tdlib_db"
    let filesPath = "${filesDir}/telegram_tdlib_files"
    AppLog.info("buildTelegramTdSetParametersRequest: dbDir=${dbDir}, filesPath=${filesPath}")

    let root = buildTelegramTdRequestWithExtra("setTdlibParameters", "bootstrap-parameters")
    root.put("use_test_dc", JsonBool(false))
    root.put("database_directory", JsonString(dbDir))
    root.put("files_directory", JsonString(filesPath))
    root.put("use_file_database", JsonBool(true))
    root.put("use_chat_info_database", JsonBool(true))
    root.put("use_message_database", JsonBool(true))
    root.put("use_secret_chats", JsonBool(false))
    root.put("api_id", JsonInt(parsedApiId))
    root.put("api_hash", JsonString(normalizedApiHash))
    root.put("system_language_code", JsonString(TELEGRAM_DEFAULT_LANGUAGE_CODE))
    root.put("device_model", JsonString(TELEGRAM_DEFAULT_DEVICE_MODEL))
    root.put("system_version", JsonString(""))
    root.put("application_version", JsonString(TELEGRAM_DEFAULT_APPLICATION_VERSION))

    let jsonRequest = root.toString()
    AppLog.info("buildTelegramTdSetParametersRequest: final JSON length=${jsonRequest.size}")
    return jsonRequest
}

func buildTelegramTdSetPhoneRequest(phoneNumber: String): String {
    let root = JsonObject()
    root.put("@type", JsonString("setAuthenticationPhoneNumber"))
    root.put("phone_number", JsonString(phoneNumber))
    return root.toString()
}

func buildTelegramTdCheckCodeRequest(code: String): String {
    let root = buildTelegramTdRequestWithExtra("checkAuthenticationCode", "submit-code")
    root.put("code", JsonString(code))
    return root.toString()
}

func buildTelegramTdCheckPasswordRequest(password: String): String {
    let root = buildTelegramTdRequestWithExtra("checkAuthenticationPassword", "submit-password")
    root.put("password", JsonString(password))
    return root.toString()
}

func buildTelegramTdCheckDatabaseEncryptionKeyRequest(): String {
    let root = buildTelegramTdRequestWithExtra("checkDatabaseEncryptionKey", "database-encryption-key")
    root.put("encryption_key", JsonString(""))
    return root.toString()
}

func buildTelegramTdCloseRequest(): String {
    return buildTelegramTdRequestWithExtra("close", "close-client").toString()
}

func buildTelegramTdDestroyRequest(): String {
    return buildTelegramTdRequestWithExtra("destroy", "destroy-client").toString()
}

func buildTelegramTdLoadChatsRequest(limit: Int64): String {
    let root = buildTelegramTdRequestWithExtra("loadChats", "load-main-chats")
    root.put("chat_list", JsonNull())
    root.put("limit", JsonInt(limit))
    return root.toString()
}

func buildTelegramTdGetChatsRequest(limit: Int64): String {
    let root = buildTelegramTdRequestWithExtra("getChats", "snapshot-main-chats")
    root.put("chat_list", JsonNull())
    root.put("limit", JsonInt(limit))
    return root.toString()
}

func buildTelegramTdGetChatRequest(chatId: Int64): String {
    let root = buildTelegramTdRequestWithExtra("getChat", "snapshot-chat-${chatId}")
    root.put("chat_id", JsonInt(chatId))
    return root.toString()
}

func buildTelegramTdGetChatHistoryRequest(chatId: Int64): String {
    let root = buildTelegramTdRequestWithExtra("getChatHistory", "history-chat-${chatId}")
    root.put("chat_id", JsonInt(chatId))
    root.put("from_message_id", JsonInt(0))
    root.put("offset", JsonInt(0))
    root.put("limit", JsonInt(TELEGRAM_CHAT_MESSAGE_HISTORY_LIMIT))
    root.put("only_local", JsonBool(false))
    return root.toString()
}

func buildTelegramTdGetMeRequest(): String {
    return buildTelegramTdRequestWithExtra("getMe", "settings-me").toString()
}

func buildTelegramTdCreatePrivateChatRequest(userId: Int64): String {
    let root = buildTelegramTdRequestWithExtra("createPrivateChat", "settings-self-chat")
    root.put("user_id", JsonInt(userId))
    root.put("force", JsonBool(true))
    return root.toString()
}

func buildTelegramTdGetContactsRequest(): String {
    return buildTelegramTdRequestWithExtra("getContacts", "contacts-list").toString()
}

func buildTelegramTdGetUserRequest(userId: Int64, extraPrefix: String): String {
    let root = buildTelegramTdRequestWithExtra("getUser", "${extraPrefix}-${userId}")
    root.put("user_id", JsonInt(userId))
    return root.toString()
}

func buildTelegramTdSendTextMessageRequest(chatId: Int64, text: String, extra: String): String {
    let formattedText = JsonObject()
    formattedText.put("@type", JsonString("formattedText"))
    formattedText.put("text", JsonString(text))
    formattedText.put("entities", JsonArray())

    let inputContent = JsonObject()
    inputContent.put("@type", JsonString("inputMessageText"))
    inputContent.put("text", formattedText)
    inputContent.put("link_preview_options", JsonNull())
    inputContent.put("clear_draft", JsonBool(true))

    let root = buildTelegramTdRequestWithExtra("sendMessage", extra)
    root.put("chat_id", JsonInt(chatId))
    root.put("topic_id", JsonNull())
    root.put("reply_to", JsonNull())
    root.put("options", JsonNull())
    root.put("reply_markup", JsonNull())
    root.put("input_message_content", inputContent)
    return root.toString()
}

func telegramJsonContains(rawJson: String, needle: String): Bool {
    return rawJson.contains(needle)
}

func parseTelegramJsonObject(rawJson: String): ?JsonObject {
    if (rawJson.isEmpty()) {
        return None
    }
    try {
        return Some(JsonValue.fromStr(rawJson).asObject())
    } catch (_: Exception) {
        return None
    }
}

func readTelegramJsonStringField(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) =>
            if (value is JsonString) {
                return value.asString().getValue()
            }
        case None => return ""
    }
    return ""
}

func readTelegramJsonIntField(object: JsonObject, key: String, fallback: Int64): Int64 {
    match (object.get(key)) {
        case Some(value) =>
            if (value is JsonInt) {
                return value.asInt().getValue()
            }
            if (value is JsonString) {
                try {
                    return Int64.parse(value.asString().getValue())
                } catch (_: Exception) {
                    return fallback
                }
            }
        case None => return fallback
    }
    return fallback
}

func readTelegramJsonArrayInt(array: JsonArray, index: Int64): Int64 {
    match (array.get(index)) {
        case Some(value) =>
            if (value is JsonInt) {
                return value.asInt().getValue()
            }
            if (value is JsonString) {
                try {
                    return Int64.parse(value.asString().getValue())
                } catch (_: Exception) {
                    return 0
                }
            }
        case None => return 0
    }
    return 0
}

func readTelegramJsonBoolField(object: JsonObject, key: String, fallback: Bool): Bool {
    match (object.get(key)) {
        case Some(value) =>
            if (value is JsonBool) {
                return value.asBool().getValue()
            }
        case None => return fallback
    }
    return fallback
}

func readTelegramChatSnippetFromMessage(message: JsonObject): String {
    match (message.get("content")) {
        case Some(contentValue) =>
            let content = contentValue.asObject()
            let contentType = readTelegramJsonStringField(content, "@type")
            if (contentType == "messageText") {
                match (content.get("text")) {
                    case Some(textValue) =>
                        return readTelegramJsonStringField(textValue.asObject(), "text")
                    case None => return defaultTelegramChatSnippet()
                }
            }
            if (contentType == "messagePhoto") {
                return "Photo"
            }
            if (contentType == "messageVideo") {
                return "Video"
            }
            if (contentType == "messageDocument") {
                return "Document"
            }
            if (contentType == "messageSticker") {
                return "Sticker"
            }
            if (contentType == "messageVoiceNote") {
                return "Voice message"
            }
            if (contentType == "messageAnimation") {
                return "Animation"
            }
            if (contentType == "messageAudio") {
                return "Audio"
            }
            if (contentType == "messageCall") {
                return "Call"
            }
        case None => ()
    }
    return defaultTelegramChatSnippet()
}

func readTelegramChatTimestampLabel(message: JsonObject): String {
    let timestamp = readTelegramJsonIntField(message, "date", 0)
    if (timestamp <= 0) {
        return defaultTelegramChatTimestamp()
    }
    return "${timestamp}"
}

func createTelegramChatMessageRowFromMessage(message: JsonObject): ?TelegramChatMessageRow {
    let chatId = readTelegramJsonIntField(message, "chat_id", 0)
    let messageId = readTelegramJsonIntField(message, "id", 0)
    if (chatId == 0 || messageId == 0) {
        return None
    }
    let snippet = readTelegramChatSnippetFromMessage(message)
    if (snippet.isEmpty() || snippet == defaultTelegramChatSnippet()) {
        return None
    }
    let isOutgoing = readTelegramJsonBoolField(message, "is_outgoing", false)
    let deliveryLabel = if (isOutgoing) {
        match (message.get("sending_state")) {
            case Some(_) => CHAT_DETAIL_DELIVERY_PENDING
            case None => CHAT_DETAIL_DELIVERY_SENT
        }
    } else {
        ""
    }
    return Some(TelegramChatMessageRow(
        chatId,
        messageId,
        snippet,
        readTelegramChatTimestampLabel(message),
        isOutgoing,
        deliveryLabel
    ))
}

func readTelegramUserStatusType(user: JsonObject): String {
    match (user.get("status")) {
        case Some(statusValue) =>
            return readTelegramJsonStringField(statusValue.asObject(), "@type")
        case None => return ""
    }
}

func readTelegramUserDisplayName(user: JsonObject): String {
    let userId = readTelegramJsonIntField(user, "id", 0)
    return telegramContactDisplayName(
        readTelegramJsonStringField(user, "first_name"),
        readTelegramJsonStringField(user, "last_name"),
        userId
    )
}

func upsertTelegramContactFromUser(user: JsonObject): Unit {
    let userId = readTelegramJsonIntField(user, "id", 0)
    if (userId == 0) {
        return
    }
    upsertTelegramContactRow(
        TelegramContactRow(
            userId,
            readTelegramUserDisplayName(user),
            telegramContactStatusLabel(readTelegramUserStatusType(user))
        )
    )
}

func upsertTelegramSettingsFromUser(user: JsonObject): Unit {
    upsertTelegramSettingsProfile(
        readTelegramJsonIntField(user, "id", 0),
        readTelegramJsonStringField(user, "first_name"),
        readTelegramJsonStringField(user, "last_name"),
        readTelegramJsonStringField(user, "phone_number")
    )
}

func readTelegramMainChatPosition(chat: JsonObject): ?JsonObject {
    match (chat.get("positions")) {
        case Some(positionsValue) =>
            let positions = positionsValue.asArray()
            for (index in 0..positions.size()) {
                let position = positions[index].asObject()
                match (position.get("list")) {
                    case Some(listValue) =>
                        if (readTelegramJsonStringField(listValue.asObject(), "@type") == "chatListMain") {
                            return Some(position)
                        }
                    case None => ()
                }
            }
        case None => ()
    }
    return None
}

func readTelegramMainChatPositionFromUpdate(position: JsonObject): ?JsonObject {
    match (position.get("list")) {
        case Some(listValue) =>
            if (readTelegramJsonStringField(listValue.asObject(), "@type") == "chatListMain") {
                return Some(position)
            }
        case None => ()
    }
    return None
}

func upsertTelegramChatRowFromChat(chat: JsonObject): Unit {
    let chatId = readTelegramJsonIntField(chat, "id", 0)
    if (chatId == 0) {
        return
    }
    let mainPosition = readTelegramMainChatPosition(chat)
    match (mainPosition) {
        case Some(position) =>
            let orderKey = readTelegramJsonIntField(position, "order", 0)
            if (orderKey == 0) {
                removeTelegramChatRow(chatId)
                telegramChatListStateAfterMutation()
                return
            }

            let title = readTelegramJsonStringField(chat, "title")
            let unreadCount = readTelegramJsonIntField(chat, "unread_count", 0)
            let isPinned = readTelegramJsonBoolField(position, "is_pinned", false)
            let isMuted = readTelegramJsonBoolField(chat, "default_disable_notification", false)

            var snippet = defaultTelegramChatSnippet()
            var timestampLabel = defaultTelegramChatTimestamp()
            match (chat.get("last_message")) {
                case Some(lastMessageValue) =>
                    if (!(lastMessageValue is JsonNull)) {
                        let lastMessage = lastMessageValue.asObject()
                        snippet = readTelegramChatSnippetFromMessage(lastMessage)
                        timestampLabel = readTelegramChatTimestampLabel(lastMessage)
                    }
                case None => ()
            }

            upsertTelegramChatRow(
                createTelegramChatRow(
                    chatId,
                    title,
                    snippet,
                    timestampLabel,
                    unreadCount,
                    isPinned,
                    isMuted,
                    "${orderKey}"
                )
            )
        case None =>
            removeTelegramChatRow(chatId)
    }
    telegramChatListStateAfterMutation()
}

func updateTelegramChatRowPosition(chatId: Int64, position: JsonObject): Unit {
    let mainPosition = readTelegramMainChatPositionFromUpdate(position)
    match (mainPosition) {
        case Some(mainPos) =>
            let orderKey = readTelegramJsonIntField(mainPos, "order", 0)
            if (orderKey == 0) {
                removeTelegramChatRow(chatId)
                telegramChatListStateAfterMutation()
                return
            }
            match (telegramChatRowsByIdState.get(chatId)) {
                case Some(row) =>
                    row.orderKey = orderKey
                    row.isPinned = readTelegramJsonBoolField(mainPos, "is_pinned", false)
                    sortTelegramChatRows()
                    telegramChatListStateAfterMutation()
                    telegramChatListVersionState++
                case None =>
                    let _ = sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetChatRequest(chatId))
            }
        case None =>
            removeTelegramChatRow(chatId)
            telegramChatListStateAfterMutation()
    }
}

func updateTelegramChatRowUnread(chatId: Int64, unreadCount: Int64): Unit {
    match (telegramChatRowsByIdState.get(chatId)) {
        case Some(row) =>
            row.unreadCount = unreadCount
            telegramChatListVersionState++
        case None => ()
    }
    telegramChatListStateAfterMutation()
}

func updateTelegramChatRowTitle(chatId: Int64, title: String): Unit {
    match (telegramChatRowsByIdState.get(chatId)) {
        case Some(row) =>
            row.title = if (title.isEmpty()) { defaultTelegramChatTitle(chatId) } else { title }
            telegramChatListVersionState++
        case None => ()
    }
    telegramChatListStateAfterMutation()
}

func updateTelegramChatRowMute(chatId: Int64, isMuted: Bool): Unit {
    match (telegramChatRowsByIdState.get(chatId)) {
        case Some(row) =>
            row.isMuted = isMuted
            telegramChatListVersionState++
        case None => ()
    }
    telegramChatListStateAfterMutation()
}

func updateTelegramChatRowLastMessage(chatId: Int64, update: JsonObject): Unit {
    match (telegramChatRowsByIdState.get(chatId)) {
        case Some(row) =>
            match (update.get("last_message")) {
                case Some(lastMessageValue) =>
                    if (lastMessageValue is JsonNull) {
                        row.snippet = defaultTelegramChatSnippet()
                        row.timestampLabel = defaultTelegramChatTimestamp()
                    } else {
                        let lastMessage = lastMessageValue.asObject()
                        row.snippet = readTelegramChatSnippetFromMessage(lastMessage)
                        row.timestampLabel = readTelegramChatTimestampLabel(lastMessage)
                    }
                case None => ()
            }
            match (update.get("positions")) {
                case Some(positionsValue) =>
                    let positions = positionsValue.asArray()
                    var matchedMain: Bool = false
                    for (index in 0..positions.size()) {
                        let position = positions[index].asObject()
                        match (readTelegramMainChatPositionFromUpdate(position)) {
                            case Some(mainPos) =>
                                matchedMain = true
                                let orderKey = readTelegramJsonIntField(mainPos, "order", 0)
                                if (orderKey == 0) {
                                    removeTelegramChatRow(chatId)
                                    telegramChatListStateAfterMutation()
                                    return
                                }
                                row.orderKey = orderKey
                                row.isPinned = readTelegramJsonBoolField(mainPos, "is_pinned", false)
                            case None => ()
                        }
                    }
                    if (!matchedMain && row.orderKey != 0) {
                        sortTelegramChatRows()
                    }
                case None => ()
            }
            sortTelegramChatRows()
            telegramChatListVersionState++
        case None =>
            let _ = sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetChatRequest(chatId))
    }
    telegramChatListStateAfterMutation()
}

func requestTelegramMainChatListIfNeeded(): Unit {
    if (!telegramAuthIsReadyState || telegramAuthClientHandle == 0 || isTelegramChatListLoadRequested()) {
        return
    }
    markTelegramChatListLoadRequested()
    if (!hasTelegramChatListLoaded()) {
        setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_LOADING)
    }
    AppLog.info("telegram data surface: requesting main chat list")
    let didLoad = sendTelegramTdRequest(
        telegramAuthClientHandle,
        buildTelegramTdLoadChatsRequest(TELEGRAM_CHAT_LIST_LIMIT)
    )
    if (!didLoad) {
        clearTelegramChatListLoadRequested()
        setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_ERROR, notice: "Failed to load Telegram chats.")
        return
    }
    let _ = sendTelegramTdRequest(
        telegramAuthClientHandle,
        buildTelegramTdGetChatsRequest(TELEGRAM_CHAT_LIST_LIMIT)
    )
}

func requestTelegramSettingsIfNeeded(): Unit {
    if (!telegramAuthIsReadyState || telegramAuthClientHandle == 0 || isTelegramSettingsRequested()) {
        return
    }
    markTelegramSettingsRequested()
    if (telegramSettingsKind() == TELEGRAM_SETTINGS_KIND_IDLE) {
        setTelegramSettingsKind(TELEGRAM_SETTINGS_KIND_LOADING)
    }
    AppLog.info("telegram data surface: requesting settings profile")
    if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetMeRequest())) {
        clearTelegramSettingsRequested()
        setTelegramSettingsKind(TELEGRAM_SETTINGS_KIND_ERROR, notice: "Failed to load Telegram account.")
    }
}

func requestTelegramContactsIfNeeded(): Unit {
    if (!telegramAuthIsReadyState || telegramAuthClientHandle == 0 || isTelegramContactsRequested()) {
        return
    }
    markTelegramContactsRequested()
    if (!hasTelegramContactsLoaded()) {
        setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_LOADING)
    }
    AppLog.info("telegram data surface: requesting contacts")
    if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetContactsRequest())) {
        clearTelegramContactsRequested()
        setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_ERROR, notice: "Failed to load Telegram contacts.")
    }
}

func requestTelegramDataSurfaceIfReady(): Bool {
    if (!telegramAuthIsReadyState || telegramAuthClientHandle == 0) {
        return false
    }
    requestTelegramMainChatListIfNeeded()
    requestTelegramSettingsIfNeeded()
    requestTelegramContactsIfNeeded()
    return true
}

func hasRestorableTelegramDataSurfaceConfig(): Bool {
    ensureTelegramAuthRuntimeConfigLoaded()
    return telegramAuthKeepSignedInState &&
        hasValidTelegramRuntimeConfig(telegramAuthCurrentApiIdState, telegramAuthCurrentApiHashState)
}

func ensureTelegramDataSurfaceSessionStarted(): Bool {
    if (requestTelegramDataSurfaceIfReady()) {
        return true
    }
    if (!hasRestorableTelegramDataSurfaceConfig()) {
        return false
    }
    if (telegramAuthClientHandle != 0) {
        if (telegramAuthStepState == TELEGRAM_AUTH_STEP_FAILED) {
            AppLog.info("telegram data surface: restarting failed persisted TDLib session")
            restartTelegramAuth()
            return telegramAuthClientHandle != 0
        }
        startTelegramAuthPollingIfNeeded()
        return true
    }
    AppLog.info("telegram data surface: starting persisted TDLib session restore")
    restartTelegramAuth()
    return telegramAuthClientHandle != 0
}

func requestTelegramChatHistoryIfNeeded(chatId: Int64): Unit {
    if (!telegramAuthIsReadyState || telegramAuthClientHandle == 0 || chatId == 0 ||
        isTelegramChatMessagesRequested(chatId)) {
        return
    }
    markTelegramChatMessagesRequested(chatId)
    if (telegramChatMessagesKind(chatId) == TELEGRAM_CHAT_MESSAGES_KIND_IDLE) {
        setTelegramChatMessagesKind(chatId, TELEGRAM_CHAT_MESSAGES_KIND_LOADING)
    }
    if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetChatHistoryRequest(chatId))) {
        clearTelegramChatMessagesRequested(chatId)
        setTelegramChatMessagesKind(chatId, TELEGRAM_CHAT_MESSAGES_KIND_ERROR, notice: "Failed to load Telegram messages.")
    }
}

func hydrateTelegramChatListFromSnapshot(snapshot: JsonObject): Unit {
    match (snapshot.get("chat_ids")) {
        case Some(chatIdsValue) =>
            let chatIds = chatIdsValue.asArray()
            for (index in 0..chatIds.size()) {
                let chatIdValue = chatIds[index]
                var chatId: Int64 = 0
                if (chatIdValue is JsonInt) {
                    chatId = chatIdValue.asInt().getValue()
                } else if (chatIdValue is JsonString) {
                    try {
                        chatId = Int64.parse(chatIdValue.asString().getValue())
                    } catch (_: Exception) {
                        chatId = 0
                    }
                }
                if (chatId != 0) {
                    let _ = sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdGetChatRequest(chatId))
                }
            }
        case None => ()
    }
    markTelegramChatListLoaded()
    clearTelegramChatListLoadRequested()
    telegramChatListStateAfterMutation()
}

func readTelegramChatMuted(chat: JsonObject): Bool {
    if (readTelegramJsonBoolField(chat, "default_disable_notification", false)) {
        return true
    }
    match (chat.get("notification_settings")) {
        case Some(settingsValue) =>
            let settings = settingsValue.asObject()
            return readTelegramJsonIntField(settings, "mute_for", 0) > 0
        case None => return false
    }
}

func updateTelegramChatListFromResponse(response: JsonObject): Bool {
    let responseType = readTelegramJsonStringField(response, "@type")
    if (responseType == "chats") {
        hydrateTelegramChatListFromSnapshot(response)
        return true
    }
    if (responseType == "chat") {
        upsertTelegramChatRowFromChat(response)
        if (readTelegramJsonStringField(response, "@extra") == "settings-self-chat") {
            setTelegramSettingsSelfChatId(readTelegramJsonIntField(response, "id", 0))
        }
        markTelegramChatListLoaded()
        clearTelegramChatListLoadRequested()
        telegramChatListStateAfterMutation()
        return true
    }
    return false
}

func updateTelegramChatMessagesFromResponse(response: JsonObject): Bool {
    let responseType = readTelegramJsonStringField(response, "@type")
    if (responseType != "messages") {
        return false
    }
    let extra = readTelegramJsonStringField(response, "@extra")
    if (!extra.startsWith("history-chat-")) {
        return false
    }
    var chatId: Int64 = 0
    try {
        chatId = Int64.parse(extra.removePrefix("history-chat-"))
    } catch (_: Exception) {
        chatId = 0
    }
    if (chatId == 0) {
        return true
    }

    let rows = ArrayList<TelegramChatMessageRow>()
    match (response.get("messages")) {
        case Some(messagesValue) =>
            let messages = messagesValue.asArray()
            for (index in 0..messages.size()) {
                match (createTelegramChatMessageRowFromMessage(messages[index].asObject())) {
                    case Some(row) => rows.add(row)
                    case None => ()
                }
            }
        case None => ()
    }
    setTelegramChatMessageHistory(chatId, rows)
    return true
}

func upsertTelegramChatMessageFromMessage(message: JsonObject): Unit {
    match (createTelegramChatMessageRowFromMessage(message)) {
        case Some(row) => upsertTelegramChatMessageRow(row)
        case None => ()
    }
}

func replaceTelegramChatMessageFromSendSucceeded(update: JsonObject): Unit {
    let oldMessageId = readTelegramJsonIntField(update, "old_message_id", 0)
    match (update.get("message")) {
        case Some(messageValue) =>
            match (createTelegramChatMessageRowFromMessage(messageValue.asObject())) {
                case Some(row) => replaceTelegramChatMessageRow(oldMessageId, row)
                case None => ()
            }
        case None => ()
    }
}

func updateTelegramSettingsFromResponse(response: JsonObject): Bool {
    let responseType = readTelegramJsonStringField(response, "@type")
    if (responseType != "user") {
        return false
    }
    let extra = readTelegramJsonStringField(response, "@extra")
    if (extra == "settings-me") {
        upsertTelegramSettingsFromUser(response)
        clearTelegramSettingsRequested()
        if (telegramSettingsSelfUserId() != 0) {
            let _ = sendTelegramTdRequest(
                telegramAuthClientHandle,
                buildTelegramTdCreatePrivateChatRequest(telegramSettingsSelfUserId())
            )
        }
        return true
    }
    if (extra.startsWith("contacts-user-")) {
        upsertTelegramContactFromUser(response)
        return true
    }
    if (extra.startsWith("settings-user-")) {
        upsertTelegramSettingsFromUser(response)
        return true
    }
    return false
}

func updateTelegramContactsFromResponse(response: JsonObject): Bool {
    let responseType = readTelegramJsonStringField(response, "@type")
    if (responseType != "users") {
        return false
    }
    let extra = readTelegramJsonStringField(response, "@extra")
    if (extra != "contacts-list") {
        return false
    }
    match (response.get("user_ids")) {
        case Some(userIdsValue) =>
            let userIds = userIdsValue.asArray()
            for (index in 0..userIds.size()) {
                let userId = readTelegramJsonArrayInt(userIds, index)
                if (userId != 0) {
                    let _ = sendTelegramTdRequest(
                        telegramAuthClientHandle,
                        buildTelegramTdGetUserRequest(userId, "contacts-user")
                    )
                }
            }
        case None => ()
    }
    markTelegramContactsLoaded()
    return true
}

func handleTelegramChatListError(update: JsonObject): Bool {
    let extra = readTelegramJsonStringField(update, "@extra")
    if (!(extra.startsWith("load-main-chats") ||
        extra.startsWith("snapshot-main-chats") ||
        extra.startsWith("snapshot-chat-"))) {
        return false
    }

    let code = readTelegramJsonIntField(update, "code", 0)
    if (extra.startsWith("load-main-chats") && code == 404) {
        markTelegramChatListLoaded()
        clearTelegramChatListLoadRequested()
        telegramChatListStateAfterMutation()
        return true
    }

    clearTelegramChatListLoadRequested()
    setTelegramChatListKind(TELEGRAM_CHAT_LIST_KIND_ERROR, notice: "Failed to load Telegram chats.")
    return true
}

func handleTelegramFeatureError(update: JsonObject): Bool {
    let extra = readTelegramJsonStringField(update, "@extra")
    if (extra == "contacts-list" || extra.startsWith("contacts-user-")) {
        clearTelegramContactsRequested()
        setTelegramContactsKind(TELEGRAM_CONTACTS_KIND_ERROR, notice: "Failed to load Telegram contacts.")
        return true
    }
    if (extra == "settings-me" || extra == "settings-self-chat" || extra.startsWith("settings-user-")) {
        clearTelegramSettingsRequested()
        setTelegramSettingsKind(TELEGRAM_SETTINGS_KIND_ERROR, notice: "Failed to load Telegram account.")
        return true
    }
    if (extra.startsWith("send-message-")) {
        let message = readTelegramJsonStringField(update, "message")
        let _ = markTelegramMessageSendFailed(extra, message)
        return true
    }
    if (extra.startsWith("history-chat-")) {
        let chatId = parseTelegramChatIdFromHistoryExtra(extra)
        if (chatId != 0) {
            clearTelegramChatMessagesRequested(chatId)
            setTelegramChatMessagesKind(chatId, TELEGRAM_CHAT_MESSAGES_KIND_ERROR, notice: "Failed to load Telegram messages.")
        }
        return true
    }
    return false
}

func parseTelegramChatIdFromHistoryExtra(extra: String): Int64 {
    if (!extra.startsWith("history-chat-")) {
        return 0
    }
    try {
        return Int64.parse(extra.removePrefix("history-chat-"))
    } catch (_: Exception) {
        return 0
    }
}

func redactedTelegramRawJson(rawJson: String): String {
    if (rawJson.contains("\"phone_number\"") ||
        rawJson.contains("\"api_hash\"") ||
        rawJson.contains("\"code\":\"") ||
        rawJson.contains("\"password\"")) {
        return "<redacted sensitive TDLib payload>"
    }
    return rawJson
}

func isTelegramAuthProxyConfigured(): Bool {
    return telegramAuthCurrentProxyTypeState != TELEGRAM_PROXY_TYPE_NONE &&
        !normalizeTelegramProxyHost(telegramAuthCurrentProxyHostState).isEmpty()
}

func isTelegramAuthProxyReady(): Bool {
    return !isTelegramAuthProxyConfigured() || telegramAuthProxyEnabled
}

func submitTelegramBootstrapRequests(): Bool {
    ensureTelegramAuthRuntimeConfigLoaded()
    if (!hasValidTelegramRuntimeConfig(telegramAuthCurrentApiIdState, telegramAuthCurrentApiHashState)) {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = TELEGRAM_RUNTIME_CONFIG_EMPTY_NOTICE
        AppLog.error("telegram auth: invalid runtime config")
        return false
    }
    if (!hasValidTelegramProxyConfig(telegramAuthCurrentProxyHostState, telegramAuthCurrentProxyPortState)) {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = validateTelegramProxyConfig(
            telegramAuthCurrentProxyHostState,
            telegramAuthCurrentProxyPortState
        )
        AppLog.error("telegram auth: invalid proxy config")
        return false
    }
    if (isTelegramAuthProxyConfigured()) {
        let proxyRequest = buildTelegramTdAddProxyRequest(
            telegramAuthCurrentProxyHostState,
            telegramAuthCurrentProxyPortState,
            telegramAuthCurrentProxyTypeState
        )
        AppLog.info("telegram auth: sending addProxy type=${telegramAuthCurrentProxyTypeState} to ${telegramAuthCurrentProxyHostState}:${telegramAuthCurrentProxyPortState}")
        if (!sendTelegramTdRequest(telegramAuthClientHandle, proxyRequest)) {
            telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
            telegramAuthNoticeState = "Failed to prepare the Telegram connection."
            AppLog.error("telegram auth: failed to send addProxy")
            return false
        }
    } else {
        telegramAuthProxyEnabled = true
    }

    let parametersRequest = buildTelegramTdSetParametersRequest(telegramAuthCurrentApiIdState, telegramAuthCurrentApiHashState)
    AppLog.info("telegram auth: sending setTdlibParameters, length=${parametersRequest.size}")
    if (!sendTelegramTdRequest(telegramAuthClientHandle, parametersRequest)) {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = "Failed to submit TDLib parameters."
        AppLog.error("telegram auth: failed to send parameters")
        return false
    }
    telegramAuthBootstrapSubmitted = true
    return true
}

func applyTelegramPendingAuthorizationStateIfNeeded(): Unit {
    if (telegramAuthPendingAuthorizationState.isEmpty() || !isTelegramAuthProxyReady()) {
        return
    }
    let pendingState = telegramAuthPendingAuthorizationState
    telegramAuthPendingAuthorizationState = ""
    applyTelegramAuthorizationState(pendingState)
}

func applyTelegramAuthorizationState(authState: String): Unit {
    telegramAuthSubmitInFlight = false
    if (!isTelegramAuthProxyReady() &&
        authState != "authorizationStateWaitTdlibParameters" &&
        authState != "authorizationStateClosed") {
        telegramAuthPendingAuthorizationState = authState
        telegramAuthStepState = TELEGRAM_AUTH_STEP_BOOTING
        telegramAuthNoticeState = "Connecting to Telegram..."
        AppLog.info("telegram auth: deferred ${authState} until proxy is enabled")
        return
    }
    if (authState == "authorizationStateWaitTdlibParameters") {
        AppLog.info("telegram auth: received authorizationStateWaitTdlibParameters")
        if (!telegramAuthBootstrapSubmitted) {
            AppLog.info("telegram auth: bootstrap not yet submitted")
            if (!submitTelegramBootstrapRequests()) {
                return
            }
            AppLog.info("telegram auth: bootstrap requests submitted successfully")
        }
        telegramAuthStepState = TELEGRAM_AUTH_STEP_BOOTING
        telegramAuthNoticeState = if (isTelegramAuthProxyConfigured() && !telegramAuthProxyEnabled) {
            "Connecting to Telegram..."
        } else {
            "Initializing Telegram..."
        }
        return
    }
    if (authState == "authorizationStateWaitEncryptionKey") {
        if (!telegramAuthEncryptionKeySubmitted) {
            AppLog.info("telegram auth: sending checkDatabaseEncryptionKey")
            if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdCheckDatabaseEncryptionKeyRequest())) {
                telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
                telegramAuthNoticeState = "Failed to unlock the local Telegram database."
                return
            }
            telegramAuthEncryptionKeySubmitted = true
        }
        telegramAuthStepState = TELEGRAM_AUTH_STEP_BOOTING
        telegramAuthNoticeState = "Unlocking Telegram session..."
        return
    }
    if (authState == "authorizationStateWaitPhoneNumber") {
        AppLog.info("telegram auth: received authorizationStateWaitPhoneNumber - ready for phone input")
        telegramAuthStepState = TELEGRAM_AUTH_STEP_PHONE
        telegramAuthNoticeState = ""
        return
    }
    if (authState == "authorizationStateWaitCode") {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_CODE
        telegramAuthNoticeState = ""
        return
    }
    if (authState == "authorizationStateWaitPassword") {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_PASSWORD
        telegramAuthNoticeState = "Enter your Telegram password."
        return
    }
    if (authState == "authorizationStateReady") {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_READY
        telegramAuthNoticeState = ""
        telegramAuthConnectionNoticeState = ""
        telegramAuthIsReadyState = true
        telegramAuthRestorePendingState = true
        requestTelegramMainChatListIfNeeded()
        requestTelegramSettingsIfNeeded()
        requestTelegramContactsIfNeeded()
        if (telegramAuthKeepSignedInState) {
            let _ = persistDemoSession(telegramAuthLastPhoneNumberState, true)
        } else {
            clearDemoSession()
        }
        return
    }
    if (authState == "authorizationStateClosed") {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = "Telegram closed the local session. Restart login to continue."
        return
    }
}

func updateTelegramAuthStepFromRawJson(rawJson: String): Unit {
    telegramAuthLastRawUpdate = rawJson
    if (rawJson.isEmpty()) {
        return
    }
    AppLog.info("updateTelegramAuthStepFromRawJson: processing update, @type check starting")
    match (parseTelegramJsonObject(rawJson)) {
        case Some(update) =>
            if (updateTelegramSettingsFromResponse(update)) {
                return
            }
            if (updateTelegramContactsFromResponse(update)) {
                return
            }
            if (updateTelegramChatMessagesFromResponse(update)) {
                return
            }
            if (updateTelegramChatListFromResponse(update)) {
                let responseExtra = readTelegramJsonStringField(update, "@extra")
                if (responseExtra.startsWith("send-message-")) {
                    let _ = markTelegramMessageSendAccepted(responseExtra)
                    upsertTelegramChatMessageFromMessage(update)
                }
                return
            }
            let updateType = readTelegramJsonStringField(update, "@type")
            if (updateType == "message") {
                let responseExtra = readTelegramJsonStringField(update, "@extra")
                if (responseExtra.startsWith("send-message-")) {
                    let _ = markTelegramMessageSendAccepted(responseExtra)
                    upsertTelegramChatMessageFromMessage(update)
                    return
                }
            }
            if (updateType == "updateNewMessage") {
                match (update.get("message")) {
                    case Some(messageValue) => upsertTelegramChatMessageFromMessage(messageValue.asObject())
                    case None => ()
                }
                return
            }
            if (updateType == "updateMessageSendSucceeded") {
                replaceTelegramChatMessageFromSendSucceeded(update)
                return
            }
            if (updateType == "updateUser") {
                match (update.get("user")) {
                    case Some(userValue) =>
                        let user = userValue.asObject()
                        if (readTelegramJsonIntField(user, "id", 0) == telegramSettingsSelfUserId()) {
                            upsertTelegramSettingsFromUser(user)
                        }
                        if (readTelegramJsonBoolField(user, "is_contact", false)) {
                            upsertTelegramContactFromUser(user)
                        }
                    case None => ()
                }
                return
            }
            if (updateType == "updateNewChat") {
                match (update.get("chat")) {
                    case Some(chatValue) => upsertTelegramChatRowFromChat(chatValue.asObject())
                    case None => ()
                }
                markTelegramChatListLoaded()
                telegramChatListStateAfterMutation()
                return
            }
            if (updateType == "updateChatPosition") {
                let chatId = readTelegramJsonIntField(update, "chat_id", 0)
                match (update.get("position")) {
                    case Some(positionValue) => updateTelegramChatRowPosition(chatId, positionValue.asObject())
                    case None => ()
                }
                return
            }
            if (updateType == "updateChatLastMessage") {
                let chatId = readTelegramJsonIntField(update, "chat_id", 0)
                updateTelegramChatRowLastMessage(chatId, update)
                return
            }
            if (updateType == "updateChatReadInbox") {
                let chatId = readTelegramJsonIntField(update, "chat_id", 0)
                let unreadCount = readTelegramJsonIntField(update, "unread_count", 0)
                updateTelegramChatRowUnread(chatId, unreadCount)
                return
            }
            if (updateType == "updateChatTitle") {
                let chatId = readTelegramJsonIntField(update, "chat_id", 0)
                updateTelegramChatRowTitle(chatId, readTelegramJsonStringField(update, "title"))
                return
            }
            if (updateType == "updateChatNotificationSettings") {
                let chatId = readTelegramJsonIntField(update, "chat_id", 0)
                match (update.get("notification_settings")) {
                    case Some(settingsValue) =>
                        let isMuted = readTelegramJsonIntField(settingsValue.asObject(), "mute_for", 0) > 0
                        updateTelegramChatRowMute(chatId, isMuted)
                    case None => ()
                }
                return
            }
            if (updateType == "error" && handleTelegramFeatureError(update)) {
                return
            }
            if (updateType == "error" && handleTelegramChatListError(update)) {
                return
            }
            if (updateType == "addedProxy") {
                if (readTelegramJsonBoolField(update, "is_enabled", false)) {
                    telegramAuthProxyEnabled = true
                    telegramAuthConnectionNoticeState = ""
                    telegramAuthNoticeState = ""
                    AppLog.info("telegram auth: proxy enabled")
                    applyTelegramPendingAuthorizationStateIfNeeded()
                } else {
                    telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
                    telegramAuthNoticeState = "Telegram connection setup failed."
                    AppLog.error("telegram auth: proxy added but disabled")
                }
                return
            }
            if (updateType == "error" && isTelegramAuthProxyConfigured() && !telegramAuthProxyEnabled) {
                AppLog.error("telegram auth: proxy setup error: ${redactedTelegramRawJson(rawJson)}")
                telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
                telegramAuthNoticeState = "Telegram connection setup failed."
                telegramAuthSubmitInFlight = false
                return
            }
        case None => ()
    }

    if (telegramJsonContains(rawJson, "\"@type\":\"updateConnectionState\"")) {
        AppLog.info("telegram auth: connection state update: ${redactedTelegramRawJson(rawJson)}")
        if (telegramJsonContains(rawJson, "\"connection_state\":{\"@type\":\"connectionStateWaitingForNetwork\"")) {
            telegramAuthConnectionNoticeState = "Waiting for network..."
        } else if (telegramJsonContains(rawJson, "\"connection_state\":{\"@type\":\"connectionStateConnectingToProxy\"")) {
            telegramAuthConnectionNoticeState = "Connecting to Telegram..."
        } else if (telegramJsonContains(rawJson, "\"connection_state\":{\"@type\":\"connectionStateReady\"")) {
            telegramAuthConnectionNoticeState = ""
        }
        return
    }
    if (telegramJsonContains(rawJson, "\"@type\":\"addedProxy\"")) {
        if (telegramJsonContains(rawJson, "\"is_enabled\":true")) {
            telegramAuthProxyEnabled = true
            telegramAuthConnectionNoticeState = ""
            telegramAuthNoticeState = ""
            AppLog.info("telegram auth: proxy enabled")
            applyTelegramPendingAuthorizationStateIfNeeded()
        } else {
            telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
            telegramAuthNoticeState = "Telegram connection setup failed."
            AppLog.error("telegram auth: proxy added but disabled")
        }
        return
    }
    if (telegramJsonContains(rawJson, "\"@type\":\"error\"")) {
        AppLog.error("telegram auth: ERROR received: ${redactedTelegramRawJson(rawJson)}")
        telegramAuthSubmitInFlight = false
        telegramAuthNoticeState = redactedTelegramRawJson(rawJson)
        if (telegramJsonContains(rawJson, "\"code\":401")) {
            telegramAuthNoticeState = "Telegram rejected the local authorization data. Please restart login."
        } else if (telegramJsonContains(rawJson, "\"PHONE_CODE_INVALID\"")) {
            telegramAuthNoticeState = "The verification code is invalid."
        } else if (telegramJsonContains(rawJson, "\"PASSWORD_HASH_INVALID\"")) {
            telegramAuthNoticeState = "The password is incorrect."
        } else if (telegramJsonContains(rawJson, "\"FLOOD_WAIT\"")) {
            telegramAuthNoticeState = "Telegram asked you to wait before trying again."
        }
        if (telegramAuthStepState == TELEGRAM_AUTH_STEP_BOOTING) {
            telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        }
        return
    }
    if (!telegramJsonContains(rawJson, "\"@type\":\"updateAuthorizationState\"")) {
        AppLog.info("telegram auth: received non-auth update (ignoring)")
        return
    }
    AppLog.info("telegram auth: processing updateAuthorizationState")
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateWaitTdlibParameters\"")) {
        applyTelegramAuthorizationState("authorizationStateWaitTdlibParameters")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateWaitEncryptionKey\"")) {
        applyTelegramAuthorizationState("authorizationStateWaitEncryptionKey")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateWaitPhoneNumber\"")) {
        applyTelegramAuthorizationState("authorizationStateWaitPhoneNumber")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateWaitCode\"")) {
        applyTelegramAuthorizationState("authorizationStateWaitCode")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateWaitPassword\"")) {
        applyTelegramAuthorizationState("authorizationStateWaitPassword")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateReady\"")) {
        applyTelegramAuthorizationState("authorizationStateReady")
        return
    }
    if (telegramJsonContains(rawJson, "\"authorization_state\":{\"@type\":\"authorizationStateClosed\"")) {
        applyTelegramAuthorizationState("authorizationStateClosed")
        return
    }
}

func startTelegramAuthPollingIfNeeded(): Unit {
    if (telegramAuthPollingStarted || telegramAuthClientHandle == 0) {
        AppLog.info("startTelegramAuthPollingIfNeeded: SKIPPED, pollingStarted=${telegramAuthPollingStarted}, handle=${telegramAuthClientHandle}")
        return
    }
    AppLog.info("startTelegramAuthPollingIfNeeded: STARTING polling thread, handle=${telegramAuthClientHandle}")
    telegramAuthPollingStarted = true
    telegramAuthPollingDisposed = false
    let _ = spawn {
        AppLog.info("telegram auth poll thread: ENTERED, handle=${telegramAuthClientHandle}")
        while (!telegramAuthPollingDisposed && telegramAuthClientHandle != 0) {
            let rawJson = pollTelegramTdUpdate(telegramAuthClientHandle, TELEGRAM_TD_POLL_TIMEOUT_MS)
            if (!rawJson.isEmpty()) {
                telegramAuthEmptyPollCount = 0
                AppLog.info("telegram auth poll: RECEIVED UPDATE: ${redactedTelegramRawJson(rawJson)}")
                updateTelegramAuthStepFromRawJson(rawJson)
            } else {
                telegramAuthEmptyPollCount++
                if (telegramAuthEmptyPollCount % 40 == 0) {
                    AppLog.info("telegram auth poll: idle x${telegramAuthEmptyPollCount}, current step=${telegramAuthStepState}, submitInFlight=${telegramAuthSubmitInFlight}")
                }
                sleep(TELEGRAM_TD_IDLE_SLEEP_MS * Duration.millisecond)
            }
        }
        AppLog.info("telegram auth poll thread: EXITED, disposed=${telegramAuthPollingDisposed}, handle=${telegramAuthClientHandle}")
        telegramAuthPollingStarted = false
    }
}

func bootstrapTelegramAuth(): Unit {
    AppLog.info("bootstrapTelegramAuth: starting")
    disposeTelegramAuth()
    resetTelegramAuthState()
    resetTelegramAuthFacadeState()
    ensureTelegramAuthRuntimeConfigLoaded()

    // Ensure TDLib directories exist
    let filesDir = getApplicationFilesDir()
    AppLog.info("bootstrapTelegramAuth: application files dir = ${filesDir}")
    let dbDir = "${filesDir}/telegram_tdlib_db"
    let filesPath = "${filesDir}/telegram_tdlib_files"
    AppLog.info("bootstrapTelegramAuth: will use dbDir=${dbDir}, filesPath=${filesPath}")

    let _ = setTelegramTdLogVerbosity(0)
    AppLog.info("bootstrapTelegramAuth: creating TDLib client")
    telegramAuthClientHandle = createTelegramTdClient()
    AppLog.info("bootstrapTelegramAuth: client handle = ${telegramAuthClientHandle}")
    if (telegramAuthClientHandle == 0) {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = "Failed to create a TDLib client."
        AppLog.info("bootstrapTelegramAuth: FAILED to create client")
        return
    }
    let kickstartRequest = buildTelegramTdGetOptionRequest("version")
    if (!sendTelegramTdRequest(telegramAuthClientHandle, kickstartRequest)) {
        telegramAuthStepState = TELEGRAM_AUTH_STEP_FAILED
        telegramAuthNoticeState = "Failed to start the TDLib authorization flow."
        AppLog.info("bootstrapTelegramAuth: failed to send kickstart request")
        return
    }
    AppLog.info("bootstrapTelegramAuth: starting async polling")
    startTelegramAuthPollingIfNeeded()
}

func disposeTelegramAuth(): Unit {
    telegramAuthPollingDisposed = true
    telegramAuthPollingStarted = false
    telegramAuthBootstrapSubmitted = false
    telegramAuthProxyEnabled = false
    telegramAuthPendingAuthorizationState = ""
    telegramAuthEncryptionKeySubmitted = false
    telegramAuthSubmitInFlight = false
    telegramAuthIsReadyState = false
    if (telegramAuthClientHandle != 0) {
        let _ = destroyTelegramTdClient(telegramAuthClientHandle)
        telegramAuthClientHandle = 0
    }
}

func restartTelegramAuth(): Unit {
    bootstrapTelegramAuth()
}

func submitTelegramPhoneNumber(phoneNumber: String): Bool {
    AppLog.info("submitTelegramPhoneNumber: starting, phone length=${phoneNumber.size}, handle=${telegramAuthClientHandle}")
    AppLog.info("submitTelegramPhoneNumber: current auth step=${telegramAuthStepState}")
    AppLog.info("submitTelegramPhoneNumber: submitInFlight=${telegramAuthSubmitInFlight}")
    telegramAuthNoticeState = ""
    if (telegramAuthSubmitInFlight || telegramAuthClientHandle == 0) {
        AppLog.info("submitTelegramPhoneNumber: rejected, submitInFlight=${telegramAuthSubmitInFlight}, handle=${telegramAuthClientHandle}")
        return false
    }
    if (telegramAuthStepState == TELEGRAM_AUTH_STEP_CODE) {
        AppLog.info("submitTelegramPhoneNumber: code already requested, skipping duplicate phone submit")
        return true
    }
    if (telegramAuthStepState != TELEGRAM_AUTH_STEP_PHONE) {
        AppLog.info("submitTelegramPhoneNumber: rejected, current step=${telegramAuthStepState}")
        telegramAuthNoticeState = "Telegram is not ready for the phone number yet."
        return false
    }
    telegramAuthLastPhoneNumberState = phoneNumber
    telegramAuthSubmitInFlight = true
    let request = buildTelegramTdSetPhoneRequest(phoneNumber)
    AppLog.info("submitTelegramPhoneNumber: request length=${request.size}")
    if (!sendTelegramTdRequest(telegramAuthClientHandle, request)) {
        telegramAuthSubmitInFlight = false
        telegramAuthNoticeState = "Failed to submit the phone number to Telegram."
        AppLog.info("submitTelegramPhoneNumber: sendTelegramTdRequest failed")
        return false
    }
    AppLog.info("submitTelegramPhoneNumber: request sent successfully, waiting for TDLib response")
    AppLog.info("submitTelegramPhoneNumber: polling should pick up authorizationStateWaitCode next")
    return true
}

func markTelegramPhoneSubmitTimedOut(notice: String): Unit {
    telegramAuthSubmitInFlight = false
    telegramAuthNoticeState = notice
    telegramAuthConnectionNoticeState = ""
    AppLog.info("submitTelegramPhoneNumber: timed out waiting for TDLib response; submit state reset")
}

func submitTelegramVerificationCode(code: String): Bool {
    telegramAuthNoticeState = ""
    if (telegramAuthSubmitInFlight || telegramAuthClientHandle == 0) {
        return false
    }
    telegramAuthSubmitInFlight = true
    if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdCheckCodeRequest(code))) {
        telegramAuthSubmitInFlight = false
        telegramAuthNoticeState = "Failed to submit the verification code."
        return false
    }
    return true
}

func submitTelegramPassword(password: String): Bool {
    telegramAuthNoticeState = ""
    if (telegramAuthSubmitInFlight || telegramAuthClientHandle == 0) {
        return false
    }
    telegramAuthSubmitInFlight = true
    if (!sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdCheckPasswordRequest(password))) {
        telegramAuthSubmitInFlight = false
        telegramAuthNoticeState = "Failed to submit the password."
        return false
    }
    return true
}

func sendTelegramTextMessage(chatId: Int64, text: String): Bool {
    let normalizedText = text.trim()
    if (telegramAuthClientHandle == 0 || !telegramAuthIsReadyState || chatId == 0 || normalizedText.isEmpty()) {
        let failedExtra = beginTelegramMessageSend(chatId, normalizedText)
        let _ = markTelegramMessageSendFailed(failedExtra, "Telegram is not ready to send this message.")
        return false
    }
    let extra = beginTelegramMessageSend(chatId, normalizedText)
    let request = buildTelegramTdSendTextMessageRequest(chatId, normalizedText, extra)
    if (!sendTelegramTdRequest(telegramAuthClientHandle, request)) {
        let _ = markTelegramMessageSendFailed(extra, "Failed to submit the Telegram message.")
        return false
    }
    return true
}

func closeTelegramAuthSession(): Unit {
    if (telegramAuthClientHandle != 0) {
        let _ = sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdCloseRequest())
    }
    disposeTelegramAuth()
}

func destroyTelegramAuthSessionAndLocalState(): Unit {
    if (telegramAuthClientHandle != 0) {
        let _ = sendTelegramTdRequest(telegramAuthClientHandle, buildTelegramTdDestroyRequest())
    }
    disposeTelegramAuth()
    let _ = clearTelegramTdLocalData()
    clearTelegramSessionKey()
    clearDemoSessionStorage()
    clearCurrentDemoSessionPresentation()
}
