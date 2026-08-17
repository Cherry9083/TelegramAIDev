@NonProduct
features {}

package ohos_app_cangjie_entry

internal import ohos.component.*
import ohos.router.Router
import ohos.state_macro_manage.Entry
import ohos.state_macro_manage.Component
import ohos.state_macro_manage.State
import std.time.*
import std.unicode.*

let HOME_TAB_CHATS = "chats"
let HOME_TAB_CONTACTS = "contacts"
let HOME_TAB_SETTINGS = "settings"
let HOME_TAB_CHATS_LABEL = "Chats"
let HOME_TAB_CONTACTS_LABEL = "Contacts"
let HOME_TAB_SETTINGS_LABEL = "Settings"

let CHAT_LIST_STATE_POPULATED = "populated"
let CHAT_LIST_STATE_LOADING = "loading"
let CHAT_LIST_STATE_EMPTY = "empty"
let CHAT_LIST_STATE_ERROR = "error"

let HOME_TITLE_CHATS = "Telegram"
let HOME_TITLE_CONTACTS = "Contacts"
let HOME_TITLE_SETTINGS = "Settings"
let HOME_SUBTITLE_CHATS = "Shared seed conversations with pinned, muted, and unread cues."
let HOME_SUBTITLE_CONTACTS = "People, invites, and synced contacts."
let HOME_SUBTITLE_SETTINGS = "Account and app preferences."
let HOME_SMOKE_BACK_LABEL = "Back to smoke"
let HOME_OPEN_SMOKE_LABEL = "Smoke"
let HOME_EDIT_LABEL = "Edit"
let HOME_FIND_LABEL = "Find"
let HOME_CONTACTS_ADD_LABEL = "Add"
let HOME_LOADING_COPY = "Loading conversations..."
let HOME_EMPTY_TITLE = "No chats yet"
let HOME_EMPTY_BODY = "Shared seed conversations have not been loaded."
let HOME_ERROR_TITLE = "Couldn't load chats"
let HOME_ERROR_BODY = "Check shared mock data and retry."
let HOME_RETRY_LABEL = "Reload shared chats"
let HOME_STATE_POPULATED_LABEL = "Loaded"
let HOME_STATE_LOADING_LABEL = "Loading"
let HOME_STATE_EMPTY_LABEL = "Empty"
let HOME_STATE_ERROR_LABEL = "Error"
let HOME_CONTACTS_SEARCH_PLACEHOLDER = "Search"
let HOME_CONTACTS_SEARCH_EMPTY_TITLE = "No contacts found"
let HOME_CONTACTS_SEARCH_EMPTY_BODY = "Try searching by name or status."
let HOME_CONTACTS_EMPTY_TITLE = "No synced contacts"
let HOME_CONTACTS_EMPTY_BODY = "Telegram did not return any contacts for this account yet."
let HOME_ACTION_NOTICE_SUFFIX = "is not wired yet in this demo."
let HOME_REAL_CHATS_BADGE_PINNED = "Pinned"
let HOME_REAL_CHATS_BADGE_MUTED = "Muted"
let HOME_CONTACTS_QUICK_ACTIONS_TITLE = "Quick Actions"
let HOME_CONTACTS_QUICK_ACTION_ADD = "Add Contact"
let HOME_CONTACTS_QUICK_ACTION_NEARBY = "People Nearby"
let HOME_CONTACTS_QUICK_ACTION_INVITE = "Invite Friends"
let HOME_CONTACT_STATUS_ONLINE = "online"
let HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY = "last seen recently"
let HOME_CONTACT_STATUS_LAST_SEEN_2_HOURS = "last seen 2 hours ago"
let HOME_SETTINGS_PROFILE_TITLE = "Telegram Demo"
let HOME_SETTINGS_PROFILE_PHONE = "+86 138 0013 8000"
let HOME_SETTINGS_SECTION_ACCOUNT = "Account"
let HOME_SETTINGS_SECTION_PREFERENCES = "Preferences"
let HOME_SETTINGS_SECTION_SESSION = "Session"
let HOME_SETTINGS_ITEM_DEVICES = "Devices"
let HOME_SETTINGS_ITEM_PRIVACY = "Privacy and Security"
let HOME_SETTINGS_ITEM_NOTIFICATIONS = "Notifications and Sounds"
let HOME_SETTINGS_ITEM_APPEARANCE = "Appearance"
let HOME_SETTINGS_ITEM_LANGUAGE = "Language"
let HOME_SETTINGS_ITEM_FOLDERS = "Chat Folders"
let HOME_SETTINGS_DISCLOSURE = ">"
let HOME_SETTINGS_EMPTY_HEADLINE = "No local demo session is active."
let HOME_SETTINGS_EMPTY_BODY = "Return to login to seed a local demo session for later slices."
let HOME_SIGN_OUT_LABEL = "Sign out"
let HOME_AVATAR_TINT_BLUE = 0xFFD9ECFA
let HOME_AVATAR_TINT_GREEN = 0xFFDDF3E4
let HOME_AVATAR_TINT_ORANGE = 0xFFFCE8D6
let HOME_AVATAR_TINT_PURPLE = 0xFFE9E0FB
let HOME_STATUS_SUCCESS_COLOR = 0xFF34C759

func homeAvatarTintColor(tint: String): Int64 {
    if (tint == "green") {
        return HOME_AVATAR_TINT_GREEN
    } else if (tint == "orange") {
        return HOME_AVATAR_TINT_ORANGE
    } else if (tint == "purple") {
        return HOME_AVATAR_TINT_PURPLE
    }
    return HOME_AVATAR_TINT_BLUE
}

func homeContactStatusColor(status: String): Int64 {
    if (status == HOME_CONTACT_STATUS_ONLINE) {
        return HOME_STATUS_SUCCESS_COLOR
    }
    return COLOR_TEXT_SECONDARY
}

func isHomeSmokePreviewEntryMode(mode: String): Bool {
    return mode == ENTRY_MODE_HOME_SMOKE_DEFAULT ||
        mode == ENTRY_MODE_HOME_SMOKE_LOADING ||
        mode == ENTRY_MODE_HOME_SMOKE_EMPTY ||
        mode == ENTRY_MODE_HOME_SMOKE_ERROR
}

func resolveChatListStateForEntryMode(mode: String): String {
    if (mode == ENTRY_MODE_HOME_SMOKE_LOADING) {
        return CHAT_LIST_STATE_LOADING
    } else if (mode == ENTRY_MODE_HOME_SMOKE_EMPTY) {
        return CHAT_LIST_STATE_EMPTY
    } else if (mode == ENTRY_MODE_HOME_SMOKE_ERROR) {
        return CHAT_LIST_STATE_ERROR
    }
    return CHAT_LIST_STATE_POPULATED
}

@Entry
@Component
class HomeShellPage {
    @State
    var activeTab: String = HOME_TAB_CHATS
    @State
    var chatListState: String = CHAT_LIST_STATE_POPULATED
    @State
    var contactsSearchQuery: String = ""
    @State
    var homeActionNotice: String = ""
    @State
    var realChatListVersion: Int64 = 0
    @State
    var realContactsVersion: Int64 = 0
    @State
    var realSettingsVersion: Int64 = 0

    var chatListScroller: PlatformListScroller = PlatformListScroller()
    var contactsScroller: PlatformListScroller = PlatformListScroller()
    var settingsScroller: PlatformListScroller = PlatformListScroller()
    private var entryMode: String = ENTRY_MODE_HOME_DEFAULT
    private var didResolveEntryMode: Bool = false
    private var didStartRealSurfaceSync: Bool = false
    private var didStartRealSurfaceSession: Bool = false

    protected override func aboutToAppear(): Unit {
        if (this.didResolveEntryMode) {
            return
        }
        this.didResolveEntryMode = true
        this.entryMode = this.resolveEntryMode()
        this.activeTab = HOME_TAB_CHATS
        this.chatListState = resolveChatListStateForEntryMode(this.entryMode)
        this.realChatListVersion = telegramChatListVersion()
        if (!this.isSmokePreview()) {
            this.ensureRealSurfaceSessionStarted()
            requestTelegramDataSurfaceIfReady()
            this.syncRealChatListState()
            this.realContactsVersion = telegramContactsVersion()
            this.realSettingsVersion = telegramSettingsVersion()
            this.startRealSurfaceSyncIfNeeded()
        }
    }

    func resolveEntryMode(): String {
        match (Router.getParams()) {
            case Some(mode) => return mode
            case None => return ENTRY_MODE_HOME_DEFAULT
        }
    }

    func showTab(tabId: String): Unit {
        this.activeTab = tabId
        this.homeActionNotice = ""
        if (!this.isSmokePreview()) {
            this.ensureRealSurfaceSessionStarted()
        }
        if (!this.isSmokePreview() && tabId == HOME_TAB_CHATS) {
            requestTelegramDataSurfaceIfReady()
            this.syncRealChatListState()
        }
        if (!this.isSmokePreview() && tabId == HOME_TAB_CONTACTS) {
            requestTelegramDataSurfaceIfReady()
            this.realContactsVersion = telegramContactsVersion()
        }
        if (!this.isSmokePreview() && tabId == HOME_TAB_SETTINGS) {
            requestTelegramDataSurfaceIfReady()
            this.realSettingsVersion = telegramSettingsVersion()
        }
    }

    func isSmokePreview(): Bool {
        return isHomeSmokePreviewEntryMode(this.entryMode)
    }

    func restoreSeedChats(): Unit {
        if (this.isSmokePreview()) {
            this.chatListState = CHAT_LIST_STATE_POPULATED
            return
        }
        resetTelegramChatListState()
        this.ensureRealSurfaceSessionStarted()
        requestTelegramDataSurfaceIfReady()
        this.syncRealChatListState()
    }

    func showChatListState(chatListState: String): Unit {
        this.chatListState = chatListState
    }

    func openChatDetail(conversationId: String): Unit {
        Router.push(url: ROUTE_CHAT_DETAIL, params: conversationId)
    }

    func openRealChatDetail(chatId: Int64): Unit {
        Router.push(url: ROUTE_CHAT_DETAIL, params: "tdchat:${chatId}")
    }

    func signOutDemoSession(): Unit {
        destroyTelegramAuthSessionAndLocalState()
        Router.back()
    }

    func currentTitle(): String {
        if (this.activeTab == HOME_TAB_CONTACTS) {
            return HOME_TITLE_CONTACTS
        } else if (this.activeTab == HOME_TAB_SETTINGS) {
            return HOME_TITLE_SETTINGS
        }
        return HOME_TITLE_CHATS
    }

    func currentSubtitle(): String {
        if (this.activeTab == HOME_TAB_CONTACTS) {
            return HOME_SUBTITLE_CONTACTS
        } else if (this.activeTab == HOME_TAB_SETTINGS) {
            return HOME_SUBTITLE_SETTINGS
        }
        return this.currentChatsSubtitle()
    }

    func currentSessionHeadline(): String {
        if (!this.isSmokePreview() && telegramSettingsKind() == TELEGRAM_SETTINGS_KIND_READY) {
            return "Signed in with Telegram"
        }
        if (getCurrentDemoSessionPhoneNumber().isEmpty()) {
            return HOME_SETTINGS_EMPTY_HEADLINE
        }
        return getCurrentDemoSessionModeCopy()
    }

    func currentSessionBody(): String {
        if (!this.isSmokePreview() && telegramSettingsKind() == TELEGRAM_SETTINGS_KIND_READY) {
            return "Real TDLib session is active on this device."
        }
        if (getCurrentDemoSessionPhoneNumber().isEmpty()) {
            return HOME_SETTINGS_EMPTY_BODY
        }
        return getCurrentDemoSessionDetailCopy()
    }

    func currentSettingsTitle(): String {
        if (!this.isSmokePreview() && telegramSettingsKind() == TELEGRAM_SETTINGS_KIND_READY) {
            return telegramSettingsDisplayName()
        }
        return HOME_SETTINGS_PROFILE_TITLE
    }

    func currentSettingsPhone(): String {
        if (!this.isSmokePreview() && telegramSettingsKind() == TELEGRAM_SETTINGS_KIND_READY) {
            return telegramSettingsPhone()
        }
        if (getCurrentDemoSessionPhoneNumber().isEmpty()) {
            return HOME_SETTINGS_PROFILE_PHONE
        }
        if (getCurrentDemoSessionPhoneNumber() == "+8613800138000") {
            return HOME_SETTINGS_PROFILE_PHONE
        }
        return getCurrentDemoSessionPhoneNumber()
    }

    func updateContactsSearchQuery(value: String): Unit {
        this.contactsSearchQuery = value
        this.homeActionNotice = ""
    }

    func showHomeActionNotice(actionLabel: String): Unit {
        this.homeActionNotice = "${actionLabel} ${HOME_ACTION_NOTICE_SUFFIX}"
    }

    func syncRealChatListState(): Unit {
        this.realChatListVersion = telegramChatListVersion()
        let realKind = telegramChatListKind()
        if (telegramSettingsSelfChatId() != 0) {
            this.chatListState = CHAT_LIST_STATE_POPULATED
            return
        }
        if (realKind == TELEGRAM_CHAT_LIST_KIND_LOADING || realKind == TELEGRAM_CHAT_LIST_KIND_IDLE) {
            this.chatListState = CHAT_LIST_STATE_LOADING
            return
        }
        if (realKind == TELEGRAM_CHAT_LIST_KIND_EMPTY) {
            this.chatListState = CHAT_LIST_STATE_EMPTY
            return
        }
        if (realKind == TELEGRAM_CHAT_LIST_KIND_ERROR) {
            this.chatListState = CHAT_LIST_STATE_ERROR
            return
        }
        this.chatListState = CHAT_LIST_STATE_POPULATED
    }

    func startRealSurfaceSyncIfNeeded(): Unit {
        if (this.didStartRealSurfaceSync) {
            return
        }
        this.didStartRealSurfaceSync = true
        let _ = spawn {
            while (!this.isSmokePreview()) {
                sleep(500 * Duration.millisecond)
                requestTelegramDataSurfaceIfReady()
                if (this.realChatListVersion != telegramChatListVersion()) {
                    this.syncRealChatListState()
                }
                if (this.realContactsVersion != telegramContactsVersion()) {
                    this.realContactsVersion = telegramContactsVersion()
                }
                if (this.realSettingsVersion != telegramSettingsVersion()) {
                    this.realSettingsVersion = telegramSettingsVersion()
                    this.syncRealChatListState()
                }
            }
        }
    }

    func ensureRealSurfaceSessionStarted(): Unit {
        if (this.didStartRealSurfaceSession) {
            return
        }
        this.didStartRealSurfaceSession = true
        let _ = spawn {
            let _ = ensureTelegramDataSurfaceSessionStarted()
        }
    }

    func currentChatsSubtitle(): String {
        if (this.isSmokePreview()) {
            return HOME_SUBTITLE_CHATS
        }
        let realKind = telegramChatListKind()
        if (realKind == TELEGRAM_CHAT_LIST_KIND_POPULATED) {
            return "Real Telegram chats from TDLib."
        }
        if (realKind == TELEGRAM_CHAT_LIST_KIND_ERROR) {
            return "Real Telegram chats could not be loaded yet."
        }
        return "Syncing your Telegram conversations."
    }

    func unreadBadgeCopy(unreadCount: Int64): String {
        if (unreadCount <= 0) {
            return ""
        }
        return "${unreadCount}"
    }

    func chatInitial(title: String): String {
        if (title.isEmpty()) {
            return "T"
        }
        for (rune in title.runes()) {
            return String([rune])
        }
        return "T"
    }

    func contactInitials(name: String): String {
        if (name.isEmpty()) {
            return "TG"
        }
        var result = ""
        let parts = name.split(" ", removeEmpty: true)
        for (index in 0..parts.size) {
            for (rune in parts[index].runes()) {
                result += String([rune])
                break
            }
            if (result.size >= 2) {
                return result
            }
        }
        if (result.isEmpty()) {
            return "TG"
        }
        return result
    }

    func firstContactSection(name: String): String {
        if (name.isEmpty()) {
            return "T"
        }
        for (rune in name.runes()) {
            return String([rune]).toUpper()
        }
        return "T"
    }

    func normalizedContactsSearchQuery(): String {
        return this.contactsSearchQuery.trim().toLower()
    }

    func isContactsSearchActive(): Bool {
        return !this.normalizedContactsSearchQuery().isEmpty()
    }

    func matchesContactsTokenPrefix(source: String, query: String): Bool {
        let normalizedSource = source.toLower()
        return normalizedSource.startsWith(query) || normalizedSource.contains(" ${query}")
    }

    func matchesContactsSearch(name: String, status: String): Bool {
        let query = this.normalizedContactsSearchQuery()
        if (query.isEmpty()) {
            return true
        }
        return this.matchesContactsTokenPrefix(name, query) ||
            this.matchesContactsTokenPrefix(status, query)
    }

    func hasVisibleContacts(): Bool {
        if (!this.isSmokePreview()) {
            if (telegramContactsKind() != TELEGRAM_CONTACTS_KIND_POPULATED) {
                return false
            }
            for (row in telegramContactsRows()) {
                if (this.matchesContactsSearch(row.displayName, row.statusLabel)) {
                    return true
                }
            }
            return false
        }
        return this.matchesContactsSearch("Alex Mason", HOME_CONTACT_STATUS_ONLINE) ||
            this.matchesContactsSearch("Jun Liu", HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY) ||
            this.matchesContactsSearch("Mina Park", HOME_CONTACT_STATUS_ONLINE) ||
            this.matchesContactsSearch("Ravi Tan", HOME_CONTACT_STATUS_LAST_SEEN_2_HOURS) ||
            this.matchesContactsSearch("Sara Kim", HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY)
    }

    func build() {
        Column(0) {
            Row(12) {
                Column(4) {
                    Text(this.currentTitle())
                        .id(ID_HOME_TITLE)
                        .fontSize(24)
                        .fontColor(COLOR_TEXT_PRIMARY)
                        .fontWeight(FontWeight.Bold)

                    Text(this.currentSubtitle())
                        .id(ID_HOME_SUBTITLE)
                        .fontSize(13)
                        .fontColor(COLOR_TEXT_SECONDARY)
                        .maxLines(2)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (this.isSmokePreview()) {
                    Button(HOME_SMOKE_BACK_LABEL)
                        .id(ID_HOME_SMOKE_BACK)
                        .height(40)
                        .backgroundColor(COLOR_BRAND_SOFT)
                        .fontColor(COLOR_BRAND)
                        .borderRadius(20)
                        .padding(left: 14, right: 14)
                        .onClick({ =>
                            Router.back()
                        })
                } else {
                    Row(8) {
                        if (this.activeTab == HOME_TAB_CHATS) {
                            Text(HOME_EDIT_LABEL)
                                .fontSize(13)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .padding(left: 12, right: 12, top: 10, bottom: 10)
                                .backgroundColor(COLOR_SURFACE_SUBTLE)
                                .borderRadius(18)

                            Text(HOME_FIND_LABEL)
                                .fontSize(13)
                                .fontColor(COLOR_BRAND)
                                .padding(left: 12, right: 12, top: 10, bottom: 10)
                                .backgroundColor(COLOR_BRAND_SOFT)
                                .borderRadius(18)
                        } else if (this.activeTab == HOME_TAB_CONTACTS) {
                            Button(HOME_CONTACTS_ADD_LABEL)
                                .id(ID_HOME_CONTACTS_ADD_ACTION)
                                .height(40)
                                .backgroundColor(COLOR_SURFACE_SUBTLE)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .borderRadius(20)
                                .padding(left: 14, right: 14)
                                .onClick({ =>
                                    this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_ADD)
                                })
                        }

                        // Button(HOME_OPEN_SMOKE_LABEL)
                        //     .id(ID_HOME_OPEN_SMOKE)
                        //     .height(40)
                        //     .backgroundColor(COLOR_BRAND_SOFT)
                        //     .fontColor(COLOR_BRAND)
                        //     .borderRadius(20)
                        //     .padding(left: 14, right: 14)
                        //     .onClick({ =>
                        //         Router.push(url: ROUTE_UI_TEST_PAGE)
                        //     })
                    }
                }
            }
            .id(ID_HOME_APP_BAR)
            .width(100.percent)
            .padding(left: 18, right: 18, top: 20, bottom: 18)
            .backgroundColor(COLOR_SURFACE)

            if (!this.homeActionNotice.isEmpty()) {
                Row(0) {
                    Text(this.homeActionNotice)
                        .id(ID_HOME_ACTION_NOTICE)
                        .fontSize(13)
                        .fontColor(COLOR_BRAND)
                        .maxLines(2)
                        .layoutWeight(1)
                }
                .width(100.percent)
                .padding(left: 18, right: 18, top: 12, bottom: 12)
                .backgroundColor(COLOR_BRAND_SOFT)
                .borderRadius(18)
            }

            if (this.isSmokePreview() && this.activeTab == HOME_TAB_CHATS) {
                Row(8) {
                    Button(HOME_STATE_POPULATED_LABEL)
                        .id(ID_HOME_SMOKE_SHOW_POPULATED)
                        .height(36)
                        .backgroundColor(if (this.chatListState == CHAT_LIST_STATE_POPULATED) {
                            COLOR_BRAND_SOFT
                        } else {
                            COLOR_SURFACE
                        })
                        .fontColor(if (this.chatListState == CHAT_LIST_STATE_POPULATED) {
                            COLOR_BRAND
                        } else {
                            COLOR_TEXT_SECONDARY
                        })
                        .borderRadius(18)
                        .padding(left: 10, right: 10)
                        .onClick({ =>
                            this.showChatListState(CHAT_LIST_STATE_POPULATED)
                        })

                    Button(HOME_STATE_LOADING_LABEL)
                        .id(ID_HOME_SMOKE_SHOW_LOADING)
                        .height(36)
                        .backgroundColor(if (this.chatListState == CHAT_LIST_STATE_LOADING) {
                            COLOR_BRAND_SOFT
                        } else {
                            COLOR_SURFACE
                        })
                        .fontColor(if (this.chatListState == CHAT_LIST_STATE_LOADING) {
                            COLOR_BRAND
                        } else {
                            COLOR_TEXT_SECONDARY
                        })
                        .borderRadius(18)
                        .padding(left: 10, right: 10)
                        .onClick({ =>
                            this.showChatListState(CHAT_LIST_STATE_LOADING)
                        })

                    Button(HOME_STATE_EMPTY_LABEL)
                        .id(ID_HOME_SMOKE_SHOW_EMPTY)
                        .height(36)
                        .backgroundColor(if (this.chatListState == CHAT_LIST_STATE_EMPTY) {
                            COLOR_BRAND_SOFT
                        } else {
                            COLOR_SURFACE
                        })
                        .fontColor(if (this.chatListState == CHAT_LIST_STATE_EMPTY) {
                            COLOR_BRAND
                        } else {
                            COLOR_TEXT_SECONDARY
                        })
                        .borderRadius(18)
                        .padding(left: 10, right: 10)
                        .onClick({ =>
                            this.showChatListState(CHAT_LIST_STATE_EMPTY)
                        })

                    Button(HOME_STATE_ERROR_LABEL)
                        .id(ID_HOME_SMOKE_SHOW_ERROR)
                        .height(36)
                        .backgroundColor(if (this.chatListState == CHAT_LIST_STATE_ERROR) {
                            COLOR_BRAND_SOFT
                        } else {
                            COLOR_SURFACE
                        })
                        .fontColor(if (this.chatListState == CHAT_LIST_STATE_ERROR) {
                            COLOR_BRAND
                        } else {
                            COLOR_TEXT_SECONDARY
                        })
                        .borderRadius(18)
                        .padding(left: 10, right: 10)
                        .onClick({ =>
                            this.showChatListState(CHAT_LIST_STATE_ERROR)
                        })
                }
                .width(100.percent)
                .padding(left: 18, right: 18, top: 0, bottom: 8)
            }

            Column() {
                if (this.activeTab == HOME_TAB_CHATS) {
                    if (this.chatListState == CHAT_LIST_STATE_LOADING) {
                        Column(16) {
                            LoadingProgress()
                                .id(ID_HOME_CHAT_LIST_LOADING)
                                .color(COLOR_BRAND)
                                .foregroundColor(COLOR_BRAND)
                                .enableLoading(true)
                                .width(40)
                                .height(40)

                            Text(if (this.isSmokePreview()) {
                                HOME_LOADING_COPY
                            } else {
                                "Loading Telegram chats..."
                            })
                                .fontSize(15)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .fontWeight(FontWeight.Medium)
                        }
                        .width(100.percent)
                        .height(100.percent)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                    } else if (this.chatListState == CHAT_LIST_STATE_EMPTY) {
                        Column(12) {
                            Text(HOME_EMPTY_TITLE)
                                .fontSize(20)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .fontWeight(FontWeight.Bold)

                            Text(if (this.isSmokePreview()) {
                                HOME_EMPTY_BODY
                            } else {
                                "No Telegram chats are available in the main list yet."
                            })
                                .fontSize(14)
                                .fontColor(COLOR_TEXT_SECONDARY)
                                .textAlign(TextAlign.Center)
                                .width(100.percent)
                        }
                        .id(ID_HOME_CHAT_LIST_EMPTY)
                        .width(100.percent)
                        .height(100.percent)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                        .padding(left: 24, right: 24, top: 24, bottom: 24)
                        .backgroundColor(COLOR_SURFACE)
                        .borderRadius(24)
                    } else if (this.chatListState == CHAT_LIST_STATE_ERROR) {
                        Column(14) {
                            Text(HOME_ERROR_TITLE)
                                .fontSize(20)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .fontWeight(FontWeight.Bold)

                            Text(if (this.isSmokePreview()) {
                                HOME_ERROR_BODY
                            } else if (!telegramChatListNotice().isEmpty()) {
                                telegramChatListNotice()
                            } else {
                                "Check the Telegram session and try again."
                            })
                                .fontSize(14)
                                .fontColor(COLOR_TEXT_SECONDARY)
                                .textAlign(TextAlign.Center)
                                .width(100.percent)

                            Button(HOME_RETRY_LABEL)
                                .id(ID_HOME_CHAT_LIST_RETRY)
                                .width(100.percent)
                                .height(46)
                                .backgroundColor(COLOR_BRAND)
                                .fontColor(COLOR_SURFACE)
                                .borderRadius(23)
                                .onClick({ =>
                                    this.restoreSeedChats()
                                })
                        }
                        .id(ID_HOME_CHAT_LIST_ERROR)
                        .width(100.percent)
                        .height(100.percent)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                        .padding(left: 24, right: 24, top: 24, bottom: 24)
                        .backgroundColor(COLOR_SURFACE)
                        .borderRadius(24)
                    } else if (this.isSmokePreview()) {
                        List(space: 12, initialIndex: 0, scroller: this.chatListScroller) {
                            ListItem() {
                                Row(14) {
                                    Image("resources/base/media/avatar-placeholder.svg")
                                        .width(52)
                                        .height(52)

                                    Column(8) {
                                        Row(8) {
                                            Text("Alex Mason")
                                                .fontSize(16)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                                .layoutWeight(1)

                                            Text("Pinned")
                                                .fontSize(11)
                                                .fontColor(COLOR_BRAND)
                                                .padding(left: 8, right: 8, top: 4, bottom: 4)
                                                .backgroundColor(COLOR_BRAND_SOFT)
                                                .borderRadius(999)
                                        }
                                        .width(100.percent)

                                        Text("Let's keep the startup slice tight for all three frameworks.")
                                            .fontSize(14)
                                            .fontColor(COLOR_TEXT_SECONDARY)
                                            .maxLines(2)
                                            .width(100.percent)
                                    }
                                    .alignItems(HorizontalAlign.Start)
                                    .layoutWeight(1)

                                    Column(10) {
                                        Text("09:41")
                                            .fontSize(12)
                                            .fontColor(COLOR_TEXT_MUTED)

                                        Text("2")
                                            .id(ID_CHAT_ROW_ALEX_UNREAD)
                                            .fontSize(12)
                                            .fontColor(COLOR_SURFACE)
                                            .fontWeight(FontWeight.Bold)
                                            .padding(left: 9, right: 9, top: 6, bottom: 6)
                                            .backgroundColor(COLOR_BRAND)
                                            .borderRadius(999)
                                    }
                                    .alignItems(HorizontalAlign.End)
                                }
                                .id(ID_CHAT_ROW_ALEX)
                                .width(100.percent)
                                .padding(left: 16, right: 16, top: 16, bottom: 16)
                                .backgroundColor(COLOR_SURFACE)
                                .borderRadius(22)
                                .onClick({ _ =>
                                    this.openChatDetail(CHAT_DETAIL_CONVERSATION_ALEX)
                                })
                            }

                            ListItem() {
                                Row(14) {
                                    Image("resources/base/media/avatar-placeholder.svg")
                                        .width(52)
                                        .height(52)

                                    Column(8) {
                                        Row(8) {
                                            Text("Design Sync")
                                                .fontSize(16)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                                .layoutWeight(1)

                                            Text("Muted")
                                                .fontSize(11)
                                                .fontColor(COLOR_TEXT_SECONDARY)
                                                .padding(left: 8, right: 8, top: 4, bottom: 4)
                                                .backgroundColor(COLOR_SURFACE_SUBTLE)
                                                .borderRadius(999)
                                        }
                                        .width(100.percent)

                                        Text("Shared assets should prevent each framework from inventing its own look.")
                                            .fontSize(14)
                                            .fontColor(COLOR_TEXT_SECONDARY)
                                            .maxLines(2)
                                            .width(100.percent)
                                    }
                                    .alignItems(HorizontalAlign.Start)
                                    .layoutWeight(1)

                                    Column(10) {
                                        Text("Yesterday")
                                            .fontSize(12)
                                            .fontColor(COLOR_TEXT_MUTED)
                                    }
                                    .alignItems(HorizontalAlign.End)
                                }
                                .id(ID_CHAT_ROW_DESIGN)
                                .width(100.percent)
                                .padding(left: 16, right: 16, top: 16, bottom: 16)
                                .backgroundColor(COLOR_SURFACE)
                                .borderRadius(22)
                                .onClick({ _ =>
                                    this.openChatDetail(CHAT_DETAIL_CONVERSATION_DESIGN)
                                })
                            }

                            ListItem() {
                                Row(14) {
                                    Image("resources/base/media/avatar-placeholder.svg")
                                        .width(52)
                                        .height(52)

                                    Column(8) {
                                        Row(8) {
                                            Text("Ops Bot")
                                                .fontSize(16)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                                .layoutWeight(1)
                                        }
                                        .width(100.percent)

                                        Text("Build is green. Token and time metrics were recorded.")
                                            .fontSize(14)
                                            .fontColor(COLOR_TEXT_SECONDARY)
                                            .maxLines(2)
                                            .width(100.percent)
                                    }
                                    .alignItems(HorizontalAlign.Start)
                                    .layoutWeight(1)

                                    Column(10) {
                                        Text("Thu")
                                            .fontSize(12)
                                            .fontColor(COLOR_TEXT_MUTED)

                                        Text("1")
                                            .id(ID_CHAT_ROW_OPS_UNREAD)
                                            .fontSize(12)
                                            .fontColor(COLOR_SURFACE)
                                            .fontWeight(FontWeight.Bold)
                                            .padding(left: 9, right: 9, top: 6, bottom: 6)
                                            .backgroundColor(COLOR_BRAND)
                                            .borderRadius(999)
                                    }
                                    .alignItems(HorizontalAlign.End)
                                }
                                .id(ID_CHAT_ROW_OPS)
                                .width(100.percent)
                                .padding(left: 16, right: 16, top: 16, bottom: 16)
                                .backgroundColor(COLOR_SURFACE)
                                .borderRadius(22)
                                .onClick({ _ =>
                                    this.openChatDetail(CHAT_DETAIL_CONVERSATION_OPS)
                                })
                            }
                        }
                        .id(ID_HOME_CHAT_LIST)
                        .listDirection(Axis.Vertical)
                        .edgeEffect(EdgeEffect.Spring)
                        .width(100.percent)
                        .height(100.percent)
                        .scrollBar(BarState.Off)
                    } else {
                        List(space: 12, initialIndex: 0, scroller: this.chatListScroller) {
                            if (telegramSettingsSelfChatId() != 0) {
                                ListItem() {
                                    Row(14) {
                                        Row() {
                                            Text("SM")
                                                .fontSize(18)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                        }
                                        .width(52)
                                        .height(52)
                                        .justifyContent(FlexAlign.Center)
                                        .backgroundColor(homeAvatarTintColor("green"))
                                        .borderRadius(26)

                                        Column(8) {
                                            Text("Saved Messages")
                                                .fontSize(16)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                                .width(100.percent)

                                            Text("Send a real Telegram message to your own account.")
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_SECONDARY)
                                                .maxLines(2)
                                                .width(100.percent)
                                        }
                                        .alignItems(HorizontalAlign.Start)
                                        .layoutWeight(1)
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 16, bottom: 16)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(22)
                                    .onClick({ _ =>
                                        this.openRealChatDetail(telegramSettingsSelfChatId())
                                    })
                                }
                            }

                            ForEach(
                                telegramChatListRows(),
                                itemGeneratorFunc: { row: TelegramChatListRow, _: Int64 =>
                                    ListItem() {
                                        Row(14) {
                                            Row() {
                                                Text(this.chatInitial(row.title))
                                                    .fontSize(18)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(52)
                                            .height(52)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("blue"))
                                            .borderRadius(26)

                                            Column(8) {
                                                Row(8) {
                                                    Text(row.title)
                                                        .fontSize(16)
                                                        .fontColor(COLOR_TEXT_PRIMARY)
                                                        .fontWeight(FontWeight.Bold)
                                                        .layoutWeight(1)

                                                    if (row.isPinned) {
                                                        Text(HOME_REAL_CHATS_BADGE_PINNED)
                                                            .fontSize(11)
                                                            .fontColor(COLOR_BRAND)
                                                            .padding(left: 8, right: 8, top: 4, bottom: 4)
                                                            .backgroundColor(COLOR_BRAND_SOFT)
                                                            .borderRadius(999)
                                                    } else if (row.isMuted) {
                                                        Text(HOME_REAL_CHATS_BADGE_MUTED)
                                                            .fontSize(11)
                                                            .fontColor(COLOR_TEXT_SECONDARY)
                                                            .padding(left: 8, right: 8, top: 4, bottom: 4)
                                                            .backgroundColor(COLOR_SURFACE_SUBTLE)
                                                            .borderRadius(999)
                                                    }
                                                }
                                                .width(100.percent)

                                                Text(row.snippet)
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_SECONDARY)
                                                    .maxLines(2)
                                                    .width(100.percent)
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)

                                            Column(10) {
                                                Text(row.timestampLabel)
                                                    .fontSize(12)
                                                    .fontColor(COLOR_TEXT_MUTED)

                                                if (row.unreadCount > 0) {
                                                    Text(this.unreadBadgeCopy(row.unreadCount))
                                                        .fontSize(12)
                                                        .fontColor(COLOR_SURFACE)
                                                        .fontWeight(FontWeight.Bold)
                                                        .padding(left: 9, right: 9, top: 6, bottom: 6)
                                                        .backgroundColor(COLOR_BRAND)
                                                        .borderRadius(999)
                                                }
                                            }
                                            .alignItems(HorizontalAlign.End)
                                        }
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 16, bottom: 16)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                        .onClick({ _ =>
                                            this.openRealChatDetail(row.chatId)
                                        })
                                    }
                                },
                                keyGeneratorFunc: { row: TelegramChatListRow, _: Int64 => row.chatId.toString() }
                            )
                        }
                        .id(ID_HOME_CHAT_LIST)
                        .listDirection(Axis.Vertical)
                        .edgeEffect(EdgeEffect.Spring)
                        .width(100.percent)
                        .height(100.percent)
                        .scrollBar(BarState.Off)
                    }
                } else if (this.activeTab == HOME_TAB_CONTACTS) {
                    Column(0) {
                        List(space: 14, initialIndex: 0, scroller: this.contactsScroller) {
                            ListItem() {
                                TextInput(text: this.contactsSearchQuery, placeholder: HOME_CONTACTS_SEARCH_PLACEHOLDER)
                                    .id(ID_HOME_CONTACTS_SEARCH)
                                    .width(100.percent)
                                    .height(46)
                                    .backgroundColor(COLOR_SURFACE_SUBTLE)
                                    .fontSize(15)
                                    .fontColor(COLOR_TEXT_PRIMARY)
                                    .textAlign(TextAlign.Start)
                                    .padding(left: 16, right: 16, top: 0, bottom: 0)
                                    .borderRadius(23)
                                    .onChange({ value: String =>
                                        this.updateContactsSearchQuery(value)
                                    })
                            }

                            if (!this.isContactsSearchActive()) {
                                ListItem() {
                                    Column(14) {
                                        Text(HOME_CONTACTS_QUICK_ACTIONS_TITLE)
                                            .id(ID_HOME_CONTACTS_QUICK_ACTIONS_TITLE)
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Column(2) {
                                            Row(0) {
                                                Text(HOME_CONTACTS_QUICK_ACTION_ADD)
                                                    .id(ID_HOME_CONTACTS_QUICK_ACTION_ADD)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)
                                                    .layoutWeight(1)
                                                    .onClick({ _ =>
                                                        this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_ADD)
                                                    })
                                            }
                                            .id(ID_HOME_CONTACTS_QUICK_ACTION_ADD_ROW)
                                            .width(100.percent)
                                            .padding(left: 4, right: 4, top: 8, bottom: 8)
                                            .borderRadius(16)
                                            .onClick({ _ =>
                                                this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_ADD)
                                            })

                                            Row(0) {
                                                Text(HOME_CONTACTS_QUICK_ACTION_NEARBY)
                                                    .id(ID_HOME_CONTACTS_QUICK_ACTION_NEARBY)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)
                                                    .layoutWeight(1)
                                                    .onClick({ _ =>
                                                        this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_NEARBY)
                                                    })
                                            }
                                            .id(ID_HOME_CONTACTS_QUICK_ACTION_NEARBY_ROW)
                                            .width(100.percent)
                                            .padding(left: 4, right: 4, top: 8, bottom: 8)
                                            .borderRadius(16)
                                            .onClick({ _ =>
                                                this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_NEARBY)
                                            })

                                            Row(0) {
                                                Text(HOME_CONTACTS_QUICK_ACTION_INVITE)
                                                    .id(ID_HOME_CONTACTS_QUICK_ACTION_INVITE)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)
                                                    .layoutWeight(1)
                                                    .onClick({ _ =>
                                                        this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_INVITE)
                                                    })
                                            }
                                            .id(ID_HOME_CONTACTS_QUICK_ACTION_INVITE_ROW)
                                            .width(100.percent)
                                            .padding(left: 4, right: 4, top: 8, bottom: 8)
                                            .borderRadius(16)
                                            .onClick({ _ =>
                                                this.showHomeActionNotice(HOME_CONTACTS_QUICK_ACTION_INVITE)
                                            })
                                        }
                                        .alignItems(HorizontalAlign.Start)
                                        .width(100.percent)
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 16, bottom: 16)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(24)
                                }
                            }

                            if (!this.isSmokePreview() && telegramContactsKind() == TELEGRAM_CONTACTS_KIND_LOADING) {
                                ListItem() {
                                    Column(12) {
                                        LoadingProgress()
                                            .color(COLOR_BRAND)
                                            .foregroundColor(COLOR_BRAND)
                                            .enableLoading(true)
                                            .width(34)
                                            .height(34)

                                        Text("Loading Telegram contacts...")
                                            .fontSize(14)
                                            .fontColor(COLOR_TEXT_PRIMARY)
                                            .fontWeight(FontWeight.Medium)
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 18, bottom: 18)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(22)
                                    .alignItems(HorizontalAlign.Center)
                                }
                            }

                            if (!this.isSmokePreview() && telegramContactsKind() == TELEGRAM_CONTACTS_KIND_ERROR) {
                                ListItem() {
                                    Column(10) {
                                        Text("Couldn't load contacts")
                                            .fontSize(16)
                                            .fontColor(COLOR_TEXT_PRIMARY)
                                            .fontWeight(FontWeight.Bold)

                                        Text(if (telegramContactsNotice().isEmpty()) {
                                            "Check the Telegram session and try again."
                                        } else {
                                            telegramContactsNotice()
                                        })
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_SECONDARY)
                                            .width(100.percent)
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 18, bottom: 18)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(22)
                                }
                            }

                            if (!this.isSmokePreview() && telegramContactsKind() == TELEGRAM_CONTACTS_KIND_POPULATED) {
                                ForEach(
                                    telegramContactsRows(),
                                    itemGeneratorFunc: { row: TelegramContactRow, _: Int64 =>
                                        if (this.matchesContactsSearch(row.displayName, row.statusLabel)) {
                                            ListItem() {
                                                Column(10) {
                                                    Text(this.firstContactSection(row.displayName))
                                                        .fontSize(13)
                                                        .fontColor(COLOR_TEXT_MUTED)
                                                        .fontWeight(FontWeight.Medium)

                                                    Row(14) {
                                                        Row() {
                                                            Text(this.contactInitials(row.displayName))
                                                                .fontSize(14)
                                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                                .fontWeight(FontWeight.Bold)
                                                        }
                                                        .width(40)
                                                        .height(40)
                                                        .justifyContent(FlexAlign.Center)
                                                        .backgroundColor(homeAvatarTintColor("green"))
                                                        .borderRadius(20)

                                                        Column(4) {
                                                            Text(row.displayName)
                                                                .fontSize(15)
                                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                                .fontWeight(FontWeight.Medium)

                                                            Text(row.statusLabel)
                                                                .fontSize(13)
                                                                .fontColor(homeContactStatusColor(row.statusLabel))
                                                        }
                                                        .alignItems(HorizontalAlign.Start)
                                                        .layoutWeight(1)
                                                    }
                                                    .width(100.percent)
                                                    .padding(left: 16, right: 16, top: 14, bottom: 14)
                                                    .backgroundColor(COLOR_SURFACE)
                                                    .borderRadius(22)
                                                }
                                                .width(100.percent)
                                            }
                                        }
                                    },
                                    keyGeneratorFunc: { row: TelegramContactRow, _: Int64 => row.userId.toString() }
                                )
                            }

                            if (this.isSmokePreview() &&
                                this.matchesContactsSearch("Alex Mason", HOME_CONTACT_STATUS_ONLINE)) {
                                ListItem() {
                                    Column(10) {
                                        Text("A")
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Row(14) {
                                            Row() {
                                                Text("AM")
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(40)
                                            .height(40)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("blue"))
                                            .borderRadius(20)

                                            Column(4) {
                                                Text("Alex Mason")
                                                    .id(ID_HOME_CONTACTS_NAME_ALEX)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)

                                                Text(HOME_CONTACT_STATUS_ONLINE)
                                                    .id(ID_HOME_CONTACTS_STATUS_ALEX)
                                                    .fontSize(13)
                                                    .fontColor(homeContactStatusColor(HOME_CONTACT_STATUS_ONLINE))
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)
                                        }
                                        .id(ID_HOME_CONTACTS_SECTION_A)
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                    }
                                    .width(100.percent)
                                }
                            }

                            if (this.isSmokePreview() &&
                                this.matchesContactsSearch("Jun Liu", HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY)) {
                                ListItem() {
                                    Column(10) {
                                        Text("J")
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Row(14) {
                                            Row() {
                                                Text("JL")
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(40)
                                            .height(40)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("green"))
                                            .borderRadius(20)

                                            Column(4) {
                                                Text("Jun Liu")
                                                    .id(ID_HOME_CONTACTS_NAME_JUN)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)

                                                Text(HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY)
                                                    .id(ID_HOME_CONTACTS_STATUS_JUN)
                                                    .fontSize(13)
                                                    .fontColor(homeContactStatusColor(HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY))
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)
                                        }
                                        .id(ID_HOME_CONTACTS_SECTION_J)
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                    }
                                    .width(100.percent)
                                }
                            }

                            if (this.isSmokePreview() &&
                                this.matchesContactsSearch("Mina Park", HOME_CONTACT_STATUS_ONLINE)) {
                                ListItem() {
                                    Column(10) {
                                        Text("M")
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Row(14) {
                                            Row() {
                                                Text("MP")
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(40)
                                            .height(40)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("purple"))
                                            .borderRadius(20)

                                            Column(4) {
                                                Text("Mina Park")
                                                    .id(ID_HOME_CONTACTS_NAME_MINA)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)

                                                Text(HOME_CONTACT_STATUS_ONLINE)
                                                    .id(ID_HOME_CONTACTS_STATUS_MINA)
                                                    .fontSize(13)
                                                    .fontColor(homeContactStatusColor(HOME_CONTACT_STATUS_ONLINE))
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)
                                        }
                                        .id(ID_HOME_CONTACTS_SECTION_M)
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                    }
                                    .width(100.percent)
                                }
                            }

                            if (this.isSmokePreview() &&
                                this.matchesContactsSearch("Ravi Tan", HOME_CONTACT_STATUS_LAST_SEEN_2_HOURS)) {
                                ListItem() {
                                    Column(10) {
                                        Text("R")
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Row(14) {
                                            Row() {
                                                Text("RT")
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(40)
                                            .height(40)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("blue"))
                                            .borderRadius(20)

                                            Column(4) {
                                                Text("Ravi Tan")
                                                    .id(ID_HOME_CONTACTS_NAME_RAVI)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)

                                                Text(HOME_CONTACT_STATUS_LAST_SEEN_2_HOURS)
                                                    .id(ID_HOME_CONTACTS_STATUS_RAVI)
                                                    .fontSize(13)
                                                    .fontColor(homeContactStatusColor(HOME_CONTACT_STATUS_LAST_SEEN_2_HOURS))
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)
                                        }
                                        .id(ID_HOME_CONTACTS_SECTION_R)
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                    }
                                    .width(100.percent)
                                }
                            }

                            if (this.isSmokePreview() &&
                                this.matchesContactsSearch("Sara Kim", HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY)) {
                                ListItem() {
                                    Column(10) {
                                        Text("S")
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_MUTED)
                                            .fontWeight(FontWeight.Medium)

                                        Row(14) {
                                            Row() {
                                                Text("SK")
                                                    .fontSize(14)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Bold)
                                            }
                                            .width(40)
                                            .height(40)
                                            .justifyContent(FlexAlign.Center)
                                            .backgroundColor(homeAvatarTintColor("orange"))
                                            .borderRadius(20)

                                            Column(4) {
                                                Text("Sara Kim")
                                                    .id(ID_HOME_CONTACTS_NAME_SARA)
                                                    .fontSize(15)
                                                    .fontColor(COLOR_TEXT_PRIMARY)
                                                    .fontWeight(FontWeight.Medium)

                                                Text(HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY)
                                                    .id(ID_HOME_CONTACTS_STATUS_SARA)
                                                    .fontSize(13)
                                                    .fontColor(homeContactStatusColor(HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY))
                                            }
                                            .alignItems(HorizontalAlign.Start)
                                            .layoutWeight(1)
                                        }
                                        .id(ID_HOME_CONTACTS_SECTION_S)
                                        .width(100.percent)
                                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                                        .backgroundColor(COLOR_SURFACE)
                                        .borderRadius(22)
                                    }
                                    .width(100.percent)
                                }
                            }

                            if (!this.hasVisibleContacts()) {
                                ListItem() {
                                    Column(10) {
                                        Text(if (!this.isSmokePreview() &&
                                            !this.isContactsSearchActive() &&
                                            telegramContactsKind() == TELEGRAM_CONTACTS_KIND_EMPTY) {
                                            HOME_CONTACTS_EMPTY_TITLE
                                        } else {
                                            HOME_CONTACTS_SEARCH_EMPTY_TITLE
                                        })
                                            .fontSize(16)
                                            .fontColor(COLOR_TEXT_PRIMARY)
                                            .fontWeight(FontWeight.Bold)

                                        Text(if (!this.isSmokePreview() &&
                                            !this.isContactsSearchActive() &&
                                            telegramContactsKind() == TELEGRAM_CONTACTS_KIND_EMPTY) {
                                            HOME_CONTACTS_EMPTY_BODY
                                        } else {
                                            HOME_CONTACTS_SEARCH_EMPTY_BODY
                                        })
                                            .fontSize(13)
                                            .fontColor(COLOR_TEXT_SECONDARY)
                                            .width(100.percent)
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 18, bottom: 18)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(22)
                                }
                            }
                        }
                        .id(ID_HOME_CONTACTS_LIST)
                        .listDirection(Axis.Vertical)
                        .edgeEffect(EdgeEffect.Spring)
                        .width(100.percent)
                        .height(100.percent)
                        .scrollBar(BarState.Off)
                    }
                    .id(ID_HOME_CONTACTS_PLACEHOLDER)
                    .width(100.percent)
                    .height(100.percent)
                    .backgroundColor(COLOR_APP_BACKGROUND)
                } else {
                    Column(0) {
                        List(space: 14, initialIndex: 0, scroller: this.settingsScroller) {
                            ListItem() {
                                Column(12) {
                                    Row(14) {
                                        Row() {
                                            Text(this.contactInitials(this.currentSettingsTitle()))
                                                .fontSize(16)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)
                                        }
                                        .width(48)
                                        .height(48)
                                        .justifyContent(FlexAlign.Center)
                                        .backgroundColor(homeAvatarTintColor("blue"))
                                        .borderRadius(24)

                                        Column(4) {
                                            Text(this.currentSettingsTitle())
                                                .id(ID_HOME_SETTINGS_PROFILE_TITLE)
                                                .fontSize(18)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .fontWeight(FontWeight.Bold)

                                            Text(this.currentSettingsPhone())
                                                .id(ID_HOME_SETTINGS_PROFILE_PHONE)
                                                .fontSize(13)
                                                .fontColor(COLOR_TEXT_SECONDARY)
                                        }
                                        .alignItems(HorizontalAlign.Start)
                                        .layoutWeight(1)
                                    }
                                    .width(100.percent)

                                    Text(this.currentSessionHeadline())
                                        .id(ID_HOME_SETTINGS_SESSION_HEADLINE)
                                        .fontSize(14)
                                        .fontColor(COLOR_TEXT_PRIMARY)
                                        .fontWeight(FontWeight.Medium)
                                        .width(100.percent)

                                    Text(this.currentSessionBody())
                                        .id(ID_HOME_SETTINGS_SESSION_BODY)
                                        .fontSize(13)
                                        .fontColor(COLOR_TEXT_SECONDARY)
                                        .width(100.percent)

                                    Button(HOME_SIGN_OUT_LABEL)
                                        .id(ID_HOME_SETTINGS_SIGN_OUT)
                                        .width(100.percent)
                                        .height(44)
                                        .backgroundColor(COLOR_SURFACE_SUBTLE)
                                        .fontColor(COLOR_STATUS_ERROR)
                                        .borderRadius(22)
                                        .fontWeight(FontWeight.Bold)
                                        .onClick({ =>
                                            this.signOutDemoSession()
                                        })
                                }
                                .id(ID_HOME_SETTINGS_PROFILE_CARD)
                                .width(100.percent)
                                .padding(left: 16, right: 16, top: 18, bottom: 18)
                                .backgroundColor(COLOR_SURFACE)
                                .borderRadius(24)
                            }

                            ListItem() {
                                Column(14) {
                                    Text(HOME_SETTINGS_SECTION_ACCOUNT)
                                        .fontSize(13)
                                        .fontColor(COLOR_TEXT_MUTED)
                                        .fontWeight(FontWeight.Medium)

                                    Column(12) {
                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_DEVICES)
                                                .id(ID_HOME_SETTINGS_ITEM_DEVICES)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_DEVICES)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_DEVICES_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_DEVICES)
                                        })

                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_PRIVACY)
                                                .id(ID_HOME_SETTINGS_ITEM_PRIVACY)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_PRIVACY)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_PRIVACY_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_PRIVACY)
                                        })

                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_NOTIFICATIONS)
                                                .id(ID_HOME_SETTINGS_ITEM_NOTIFICATIONS)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_NOTIFICATIONS)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_NOTIFICATIONS_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_NOTIFICATIONS)
                                        })
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 16, bottom: 16)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(24)
                                }
                                .id(ID_HOME_SETTINGS_SECTION_ACCOUNT)
                                .width(100.percent)
                            }

                            ListItem() {
                                Column(14) {
                                    Text(HOME_SETTINGS_SECTION_PREFERENCES)
                                        .fontSize(13)
                                        .fontColor(COLOR_TEXT_MUTED)
                                        .fontWeight(FontWeight.Medium)

                                    Column(12) {
                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_APPEARANCE)
                                                .id(ID_HOME_SETTINGS_ITEM_APPEARANCE)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_APPEARANCE)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_APPEARANCE_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_APPEARANCE)
                                        })

                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_LANGUAGE)
                                                .id(ID_HOME_SETTINGS_ITEM_LANGUAGE)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_LANGUAGE)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_LANGUAGE_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_LANGUAGE)
                                        })

                                        Row(0) {
                                            Text(HOME_SETTINGS_ITEM_FOLDERS)
                                                .id(ID_HOME_SETTINGS_ITEM_FOLDERS)
                                                .fontSize(15)
                                                .fontColor(COLOR_TEXT_PRIMARY)
                                                .layoutWeight(1)
                                                .onClick({ _ =>
                                                    this.showHomeActionNotice(HOME_SETTINGS_ITEM_FOLDERS)
                                                })

                                            Text(HOME_SETTINGS_DISCLOSURE)
                                                .fontSize(14)
                                                .fontColor(COLOR_TEXT_MUTED)
                                        }
                                        .id(ID_HOME_SETTINGS_ITEM_FOLDERS_ROW)
                                        .width(100.percent)
                                        .padding(top: 8, bottom: 8)
                                        .borderRadius(16)
                                        .onClick({ _ =>
                                            this.showHomeActionNotice(HOME_SETTINGS_ITEM_FOLDERS)
                                        })
                                    }
                                    .width(100.percent)
                                    .padding(left: 16, right: 16, top: 16, bottom: 16)
                                    .backgroundColor(COLOR_SURFACE)
                                    .borderRadius(24)
                                }
                                .id(ID_HOME_SETTINGS_SECTION_PREFERENCES)
                                .width(100.percent)
                            }
                        }
                        .id(ID_HOME_SETTINGS_LIST)
                        .listDirection(Axis.Vertical)
                        .edgeEffect(EdgeEffect.Spring)
                        .width(100.percent)
                        .height(100.percent)
                        .scrollBar(BarState.Off)
                    }
                    .id(ID_HOME_SETTINGS_PLACEHOLDER)
                    .width(100.percent)
                    .height(100.percent)
                    .backgroundColor(COLOR_APP_BACKGROUND)
                }
            }
            .width(100.percent)
            .layoutWeight(1)
            .padding(left: 16, right: 16, top: 16, bottom: 16)

            Row(10) {
                Button(HOME_TAB_CHATS_LABEL)
                    .id(ID_HOME_TAB_CHATS)
                    .layoutWeight(1)
                    .height(48)
                    .backgroundColor(if (this.activeTab == HOME_TAB_CHATS) {
                        COLOR_BRAND_SOFT
                    } else {
                        COLOR_SURFACE
                    })
                    .fontColor(if (this.activeTab == HOME_TAB_CHATS) {
                        COLOR_BRAND
                    } else {
                        COLOR_TEXT_SECONDARY
                    })
                    .borderRadius(20)
                    .onClick({ =>
                        this.showTab(HOME_TAB_CHATS)
                    })

                Button(HOME_TAB_CONTACTS_LABEL)
                    .id(ID_HOME_TAB_CONTACTS)
                    .layoutWeight(1)
                    .height(48)
                    .backgroundColor(if (this.activeTab == HOME_TAB_CONTACTS) {
                        COLOR_BRAND_SOFT
                    } else {
                        COLOR_SURFACE
                    })
                    .fontColor(if (this.activeTab == HOME_TAB_CONTACTS) {
                        COLOR_BRAND
                    } else {
                        COLOR_TEXT_SECONDARY
                    })
                    .borderRadius(20)
                    .onClick({ =>
                        this.showTab(HOME_TAB_CONTACTS)
                    })

                Button(HOME_TAB_SETTINGS_LABEL)
                    .id(ID_HOME_TAB_SETTINGS)
                    .layoutWeight(1)
                    .height(48)
                    .backgroundColor(if (this.activeTab == HOME_TAB_SETTINGS) {
                        COLOR_BRAND_SOFT
                    } else {
                        COLOR_SURFACE
                    })
                    .fontColor(if (this.activeTab == HOME_TAB_SETTINGS) {
                        COLOR_BRAND
                    } else {
                        COLOR_TEXT_SECONDARY
                    })
                    .borderRadius(20)
                    .onClick({ =>
                        this.showTab(HOME_TAB_SETTINGS)
                    })
            }
            .id(ID_HOME_TAB_BAR)
            .width(100.percent)
            .padding(left: 16, right: 16, top: 12, bottom: 18)
            .backgroundColor(COLOR_SURFACE)
        }
        .id(ID_HOME_ROOT)
        .width(100.percent)
        .height(100.percent)
        .backgroundColor(COLOR_APP_BACKGROUND)
        .onAppear({ =>
            if (!this.isSmokePreview()) {
                this.ensureRealSurfaceSessionStarted()
                requestTelegramDataSurfaceIfReady()
                this.syncRealChatListState()
            }
        })
    }
}
