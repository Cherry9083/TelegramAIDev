@NonProduct
features {}

package ohos_app_cangjie_entry

internal import ohos.component.*
import ohos.router.Router
import ohos.state_macro_manage.Entry
import ohos.state_macro_manage.Component
import ohos.state_macro_manage.State
import std.collection.ArrayList
import std.convert.*
import std.time.*
import std.unicode.*

let CHAT_DETAIL_TITLE_FALLBACK = "Conversation"
let CHAT_DETAIL_SUBTITLE_FALLBACK = "last seen recently"
let CHAT_DETAIL_SUBTITLE_ALEX = "last seen recently"
let CHAT_DETAIL_SUBTITLE_DESIGN = "5 members, 2 online"
let CHAT_DETAIL_SUBTITLE_OPS = "service notifications"
let CHAT_DETAIL_DATE_LABEL = "Today"
let CHAT_DETAIL_COMPOSER_COPY = "Message"
let CHAT_DETAIL_SEND_COPY = "Send"
let CHAT_DETAIL_DELIVERY_READ = "Read"
let CHAT_DETAIL_DELIVERY_PENDING = "Pending"
let CHAT_DETAIL_DELIVERY_SENT = "Sent"
let CHAT_DETAIL_LOCAL_FAILURE_PREFIX = "/fail"
let CHAT_DETAIL_SEND_FAILURE_NOTICE = "The local demo message could not be sent. Try again."
let CHAT_DETAIL_LOCAL_MESSAGE_TIME_LABEL = "09:28"
let LOCAL_MESSAGE_SLOT_FIRST = "first"
let LOCAL_MESSAGE_SLOT_SECOND = "second"

@Entry
@Component
class ChatDetailPage {
    @State
    var conversationId: String = CHAT_DETAIL_CONVERSATION_ALEX
    @State
    var composerText: String = ""
    @State
    var composerNotice: String = ""
    @State
    var firstLocalMessageText: String = ""
    @State
    var firstLocalMessageDelivery: String = ""
    @State
    var secondLocalMessageText: String = ""
    @State
    var secondLocalMessageDelivery: String = ""
    @State
    var telegramSendVersion: Int64 = 0
    @State
    var telegramMessagesVersion: Int64 = 0

    var messageScroller: PlatformListScroller = PlatformListScroller()
    private var didResolveConversation: Bool = false
    private var didStartRealMessageSync: Bool = false

    protected override func aboutToAppear(): Unit {
        if (this.didResolveConversation) {
            return
        }
        this.didResolveConversation = true
        this.conversationId = this.resolveConversationId()
        let chatId = this.realChatId()
        if (chatId != 0) {
            requestTelegramChatHistoryIfNeeded(chatId)
            this.telegramMessagesVersion = telegramChatMessagesVersion()
            this.startRealMessageSyncIfNeeded()
        }
    }

    func resolveConversationId(): String {
        match (Router.getParams()) {
            case Some(conversationId) => return conversationId
            case None => return CHAT_DETAIL_CONVERSATION_ALEX
        }
    }

    func currentTitle(): String {
        let chatId = this.realChatId()
        if (chatId != 0) {
            match (telegramChatRowById(chatId)) {
                case Some(row) => return row.title
                case None => return "Telegram chat"
            }
        }
        if (this.conversationId == CHAT_DETAIL_CONVERSATION_ALEX) {
            return "Alex Mason"
        } else if (this.conversationId == CHAT_DETAIL_CONVERSATION_DESIGN) {
            return "Design Sync"
        } else if (this.conversationId == CHAT_DETAIL_CONVERSATION_OPS) {
            return "Ops Bot"
        }
        return CHAT_DETAIL_TITLE_FALLBACK
    }

    func currentSubtitle(): String {
        let chatId = this.realChatId()
        if (chatId != 0) {
            if (chatId == telegramSettingsSelfChatId()) {
                return "Saved Messages"
            }
            return "Real Telegram conversation"
        }
        if (this.conversationId == CHAT_DETAIL_CONVERSATION_ALEX) {
            return CHAT_DETAIL_SUBTITLE_ALEX
        } else if (this.conversationId == CHAT_DETAIL_CONVERSATION_DESIGN) {
            return CHAT_DETAIL_SUBTITLE_DESIGN
        } else if (this.conversationId == CHAT_DETAIL_CONVERSATION_OPS) {
            return CHAT_DETAIL_SUBTITLE_OPS
        }
        return CHAT_DETAIL_SUBTITLE_FALLBACK
    }

    func realChatId(): Int64 {
        if (!this.conversationId.startsWith("tdchat:")) {
            return 0
        }
        try {
            return Int64.parse(this.conversationId.removePrefix("tdchat:"))
        } catch (_: Exception) {
            return 0
        }
    }

    func isRealChatDetail(): Bool {
        return this.realChatId() != 0
    }

    func updateComposerText(value: String): Unit {
        this.composerText = value
        if (!value.isEmpty()) {
            this.composerNotice = ""
        }
    }

    func deliveryColor(deliveryLabel: String): Int64 {
        if (deliveryLabel == CHAT_DETAIL_DELIVERY_PENDING) {
            return COLOR_TEXT_MUTED
        }
        if (deliveryLabel == TELEGRAM_SEND_STATE_ERROR) {
            return COLOR_STATUS_ERROR
        }
        return COLOR_BRAND
    }

    func hasFirstLocalMessage(): Bool {
        return !this.firstLocalMessageText.isEmpty()
    }

    func hasSecondLocalMessage(): Bool {
        return !this.secondLocalMessageText.isEmpty()
    }

    func firstLocalMessageBubbleId(): String {
        if (!this.hasSecondLocalMessage()) {
            return ID_CHAT_DETAIL_LOCAL_MESSAGE_BUBBLE
        }
        return "slice6_chat_detail_local_message_bubble_0"
    }

    func firstLocalMessageTextId(): String {
        if (!this.hasSecondLocalMessage()) {
            return ID_CHAT_DETAIL_LOCAL_MESSAGE_TEXT
        }
        return "slice6_chat_detail_local_message_text_0"
    }

    func firstLocalMessageDeliveryId(): String {
        if (!this.hasSecondLocalMessage()) {
            return ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY
        }
        return "slice6_chat_detail_local_message_delivery_0"
    }

    func secondLocalMessageBubbleId(): String {
        return ID_CHAT_DETAIL_LOCAL_MESSAGE_BUBBLE
    }

    func secondLocalMessageTextId(): String {
        return ID_CHAT_DETAIL_LOCAL_MESSAGE_TEXT
    }

    func secondLocalMessageDeliveryId(): String {
        return ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY
    }

    func isComposerReady(): Bool {
        return !this.composerText.isEmpty()
    }

    func appendPendingLocalMessage(draft: String): String {
        if (!this.hasFirstLocalMessage()) {
            this.firstLocalMessageText = draft
            this.firstLocalMessageDelivery = CHAT_DETAIL_DELIVERY_PENDING
            return LOCAL_MESSAGE_SLOT_FIRST
        }
        if (!this.hasSecondLocalMessage()) {
            this.secondLocalMessageText = draft
            this.secondLocalMessageDelivery = CHAT_DETAIL_DELIVERY_PENDING
            return LOCAL_MESSAGE_SLOT_SECOND
        }

        this.firstLocalMessageText = this.secondLocalMessageText
        this.firstLocalMessageDelivery = this.secondLocalMessageDelivery
        this.secondLocalMessageText = draft
        this.secondLocalMessageDelivery = CHAT_DETAIL_DELIVERY_PENDING
        return LOCAL_MESSAGE_SLOT_SECOND
    }

    func settleLocalMessage(slot: String, deliveryLabel: String): Unit {
        if (slot == LOCAL_MESSAGE_SLOT_FIRST) {
            if (this.hasFirstLocalMessage()) {
                this.firstLocalMessageDelivery = deliveryLabel
            }
            return
        }
        if (this.hasSecondLocalMessage()) {
            this.secondLocalMessageDelivery = deliveryLabel
        }
    }

    func submitLocalMessage(): Unit {
        if (!this.isComposerReady()) {
            return
        }

        let draft = this.composerText
        this.composerNotice = ""

        if (draft.startsWith(CHAT_DETAIL_LOCAL_FAILURE_PREFIX)) {
            this.composerNotice = CHAT_DETAIL_SEND_FAILURE_NOTICE
            return
        }

        let pendingSlot = this.appendPendingLocalMessage(draft)
        this.composerText = ""
        let _ = spawn {
            sleep(900 * Duration.millisecond)
            this.settleLocalMessage(pendingSlot, CHAT_DETAIL_DELIVERY_SENT)
        }
    }

    func submitTelegramMessage(): Unit {
        if (!this.isComposerReady()) {
            return
        }
        let draft = this.composerText.trim()
        if (draft.isEmpty()) {
            return
        }
        let chatId = preferredTelegramSendChatId(this.realChatId())
        this.composerText = ""
        this.composerNotice = ""
        if (!sendTelegramTextMessage(chatId, draft)) {
            this.composerNotice = telegramMessageSendNotice()
            this.telegramSendVersion = telegramMessageSendVersion()
            return
        }
        let initialSendVersion = telegramMessageSendVersion()
        let _ = spawn {
            var waitCount: Int64 = 0
            while (waitCount < 80 && initialSendVersion == telegramMessageSendVersion()) {
                sleep(250 * Duration.millisecond)
                waitCount++
            }
            this.telegramSendVersion = telegramMessageSendVersion()
            if (telegramMessageSendNotice().isEmpty()) {
                if (waitCount >= 80) {
                    this.composerNotice = "Telegram did not confirm the message before timeout."
                }
            } else {
                this.composerNotice = telegramMessageSendNotice()
            }
        }
    }

    func submitComposerMessage(): Unit {
        if (this.isRealChatDetail()) {
            this.submitTelegramMessage()
            return
        }
        this.submitLocalMessage()
    }

    func startRealMessageSyncIfNeeded(): Unit {
        if (this.didStartRealMessageSync) {
            return
        }
        this.didStartRealMessageSync = true
        let _ = spawn {
            while (this.isRealChatDetail()) {
                sleep(500 * Duration.millisecond)
                if (this.telegramMessagesVersion != telegramChatMessagesVersion()) {
                    this.telegramMessagesVersion = telegramChatMessagesVersion()
                }
            }
        }
    }

    func realMessageKindForRender(version: Int64): String {
        if (version < 0) {
            return TELEGRAM_CHAT_MESSAGES_KIND_IDLE
        }
        return telegramChatMessagesKind(this.realChatId())
    }

    func realMessageNoticeForRender(version: Int64): String {
        if (version < 0) {
            return ""
        }
        return telegramChatMessagesNotice(this.realChatId())
    }

    func realMessageRowsForRender(version: Int64): ArrayList<TelegramChatMessageRow> {
        if (version < 0) {
            return ArrayList<TelegramChatMessageRow>()
        }
        return telegramChatMessagesRows(this.realChatId())
    }

    func build() {
        Column(0) {
            Row(14) {
                Button("Back")
                    .id(ID_CHAT_DETAIL_BACK)
                    .height(40)
                    .backgroundColor(COLOR_BRAND_SOFT)
                    .fontColor(COLOR_BRAND)
                    .borderRadius(20)
                    .padding(left: 14, right: 14)
                    .onClick({ =>
                        Router.back()
                    })

                Image("resources/base/media/avatar-placeholder.svg")
                    .width(44)
                    .height(44)

                Column(4) {
                    Text(this.currentTitle())
                        .id(ID_CHAT_DETAIL_TITLE)
                        .fontSize(18)
                        .fontColor(COLOR_TEXT_PRIMARY)
                        .fontWeight(FontWeight.Bold)

                    Text(this.currentSubtitle())
                        .id(ID_CHAT_DETAIL_SUBTITLE)
                        .fontSize(12)
                        .fontColor(COLOR_TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
            }
            .id(ID_CHAT_DETAIL_TOP_BAR)
            .width(100.percent)
            .padding(left: 18, right: 18, top: 20, bottom: 18)
            .backgroundColor(COLOR_SURFACE)

            List(space: 14, initialIndex: 0, scroller: this.messageScroller) {
                ListItem() {
                    Row() {
                        Text(CHAT_DETAIL_DATE_LABEL)
                            .id(ID_CHAT_DETAIL_DATE_SEPARATOR)
                            .fontSize(12)
                            .fontColor(COLOR_TEXT_MUTED)
                            .padding(left: 12, right: 12, top: 7, bottom: 7)
                            .backgroundColor(COLOR_SURFACE)
                            .borderRadius(999)
                    }
                    .width(100.percent)
                    .justifyContent(FlexAlign.Center)
                }

                ListItem() {
                    Row() {
                        Column(6) {
                            Text("Let's keep the MVP narrow, but the surface should still feel close to Telegram.")
                                .fontSize(15)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .width(100.percent)

                            Text("09:21")
                                .fontSize(11)
                                .fontColor(COLOR_TEXT_MUTED)
                        }
                        .id(ID_CHAT_DETAIL_MESSAGE_1)
                        .alignItems(HorizontalAlign.Start)
                        .width(76.percent)
                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                        .backgroundColor(COLOR_SURFACE)
                        .borderRadius(20)
                    }
                    .width(100.percent)
                    .justifyContent(FlexAlign.Start)
                }

                ListItem() {
                    Row() {
                        Column(6) {
                            Text("Agreed. Home shell, chats, detail, and send flow should all feel believable.")
                                .fontSize(15)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .width(100.percent)

                            Row(8) {
                                Text("09:24")
                                    .fontSize(11)
                                    .fontColor(COLOR_TEXT_MUTED)

                                Text(CHAT_DETAIL_DELIVERY_READ)
                                    .id(ID_CHAT_DETAIL_MESSAGE_2_DELIVERY)
                                    .fontSize(11)
                                    .fontColor(COLOR_BRAND)
                                    .fontWeight(FontWeight.Medium)
                            }
                        }
                        .id(ID_CHAT_DETAIL_MESSAGE_2)
                        .alignItems(HorizontalAlign.End)
                        .width(76.percent)
                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                        .backgroundColor(COLOR_BRAND_SOFT)
                        .borderRadius(20)
                    }
                    .width(100.percent)
                    .justifyContent(FlexAlign.End)
                }

                ListItem() {
                    Row() {
                        Column(6) {
                            Text("Also keep Contacts and Settings visible in the shell, even if they stay shallow.")
                                .fontSize(15)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .width(100.percent)

                            Text("09:26")
                                .fontSize(11)
                                .fontColor(COLOR_TEXT_MUTED)
                        }
                        .id(ID_CHAT_DETAIL_MESSAGE_3)
                        .alignItems(HorizontalAlign.Start)
                        .width(78.percent)
                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                        .backgroundColor(COLOR_SURFACE)
                        .borderRadius(20)
                    }
                    .width(100.percent)
                    .justifyContent(FlexAlign.Start)
                }

                ListItem() {
                    Row() {
                        Column(6) {
                            Text("That keeps the demo credible without exploding the implementation scope.")
                                .fontSize(15)
                                .fontColor(COLOR_TEXT_PRIMARY)
                                .width(100.percent)

                            Row(8) {
                                Text("09:27")
                                    .fontSize(11)
                                    .fontColor(COLOR_TEXT_MUTED)

                                Text(CHAT_DETAIL_DELIVERY_READ)
                                    .id(ID_CHAT_DETAIL_MESSAGE_4_DELIVERY)
                                    .fontSize(11)
                                    .fontColor(COLOR_BRAND)
                                    .fontWeight(FontWeight.Medium)
                            }
                        }
                        .id(ID_CHAT_DETAIL_MESSAGE_4)
                        .alignItems(HorizontalAlign.End)
                        .width(76.percent)
                        .padding(left: 16, right: 16, top: 14, bottom: 14)
                        .backgroundColor(COLOR_BRAND_SOFT)
                        .borderRadius(20)
                    }
                    .width(100.percent)
                    .justifyContent(FlexAlign.End)
                }

                if (this.hasFirstLocalMessage()) {
                    ListItem() {
                        Row() {
                            Column(6) {
                                Text(this.firstLocalMessageText)
                                    .id(this.firstLocalMessageTextId())
                                    .fontSize(15)
                                    .fontColor(COLOR_TEXT_PRIMARY)
                                    .width(100.percent)

                                Row(8) {
                                    Text(CHAT_DETAIL_LOCAL_MESSAGE_TIME_LABEL)
                                        .fontSize(11)
                                        .fontColor(COLOR_TEXT_MUTED)

                                    Text(this.firstLocalMessageDelivery)
                                        .id(this.firstLocalMessageDeliveryId())
                                        .fontSize(11)
                                        .fontColor(this.deliveryColor(this.firstLocalMessageDelivery))
                                        .fontWeight(FontWeight.Medium)
                                }
                            }
                            .id(this.firstLocalMessageBubbleId())
                            .alignItems(HorizontalAlign.End)
                            .width(76.percent)
                            .padding(left: 16, right: 16, top: 14, bottom: 14)
                            .backgroundColor(COLOR_BRAND_SOFT)
                            .borderRadius(20)
                        }
                        .width(100.percent)
                        .justifyContent(FlexAlign.End)
                    }
                }

                if (this.hasSecondLocalMessage()) {
                    ListItem() {
                        Row() {
                            Column(6) {
                                Text(this.secondLocalMessageText)
                                    .id(this.secondLocalMessageTextId())
                                    .fontSize(15)
                                    .fontColor(COLOR_TEXT_PRIMARY)
                                    .width(100.percent)

                                Row(8) {
                                    Text(CHAT_DETAIL_LOCAL_MESSAGE_TIME_LABEL)
                                        .fontSize(11)
                                        .fontColor(COLOR_TEXT_MUTED)

                                    Text(this.secondLocalMessageDelivery)
                                        .id(this.secondLocalMessageDeliveryId())
                                        .fontSize(11)
                                        .fontColor(this.deliveryColor(this.secondLocalMessageDelivery))
                                        .fontWeight(FontWeight.Medium)
                                }
                            }
                            .id(this.secondLocalMessageBubbleId())
                            .alignItems(HorizontalAlign.End)
                            .width(76.percent)
                            .padding(left: 16, right: 16, top: 14, bottom: 14)
                            .backgroundColor(COLOR_BRAND_SOFT)
                            .borderRadius(20)
                        }
                        .width(100.percent)
                        .justifyContent(FlexAlign.End)
                    }
                }

                if (this.isRealChatDetail() &&
                    this.realMessageKindForRender(this.telegramMessagesVersion) == TELEGRAM_CHAT_MESSAGES_KIND_LOADING) {
                    ListItem() {
                        Row() {
                            Text("Loading Telegram messages...")
                                .fontSize(12)
                                .fontColor(COLOR_TEXT_MUTED)
                        }
                        .width(100.percent)
                        .justifyContent(FlexAlign.Center)
                    }
                }

                if (this.isRealChatDetail() &&
                    this.realMessageKindForRender(this.telegramMessagesVersion) == TELEGRAM_CHAT_MESSAGES_KIND_ERROR) {
                    ListItem() {
                        Row() {
                            Text(this.realMessageNoticeForRender(this.telegramMessagesVersion))
                                .fontSize(12)
                                .fontColor(COLOR_STATUS_ERROR)
                                .width(80.percent)
                                .textAlign(TextAlign.Center)
                        }
                        .width(100.percent)
                        .justifyContent(FlexAlign.Center)
                    }
                }

                if (this.isRealChatDetail()) {
                    ForEach(
                        this.realMessageRowsForRender(this.telegramMessagesVersion),
                        itemGeneratorFunc: { row: TelegramChatMessageRow, _: Int64 =>
                            ListItem() {
                                Row() {
                                    Column(6) {
                                        Text(row.text)
                                            .id(ID_CHAT_DETAIL_REAL_MESSAGE_TEXT)
                                            .fontSize(15)
                                            .fontColor(COLOR_TEXT_PRIMARY)
                                            .width(100.percent)

                                        Row(8) {
                                            Text(row.timeLabel)
                                                .fontSize(11)
                                                .fontColor(COLOR_TEXT_MUTED)

                                            if (row.isOutgoing) {
                                                Text(row.deliveryLabel)
                                                    .id(ID_CHAT_DETAIL_REAL_MESSAGE_DELIVERY)
                                                    .fontSize(11)
                                                    .fontColor(this.deliveryColor(row.deliveryLabel))
                                                    .fontWeight(FontWeight.Medium)
                                            }
                                        }
                                    }
                                    .alignItems(if (row.isOutgoing) { HorizontalAlign.End } else { HorizontalAlign.Start })
                                    .width(76.percent)
                                    .padding(left: 16, right: 16, top: 14, bottom: 14)
                                    .backgroundColor(if (row.isOutgoing) { COLOR_BRAND_SOFT } else { COLOR_SURFACE })
                                    .borderRadius(20)
                                }
                                .width(100.percent)
                                .justifyContent(if (row.isOutgoing) { FlexAlign.End } else { FlexAlign.Start })
                            }
                        },
                        keyGeneratorFunc: { row: TelegramChatMessageRow, _: Int64 => "${row.chatId}-${row.messageId}" }
                    )
                }
            }
            .id(ID_CHAT_DETAIL_MESSAGE_LIST)
            .listDirection(Axis.Vertical)
            .edgeEffect(EdgeEffect.Spring)
            .width(100.percent)
            .layoutWeight(1)
            .padding(left: 16, right: 16, top: 16, bottom: 16)
            .scrollBar(BarState.Off)

            Column(10) {
                if (!this.composerNotice.isEmpty()) {
                    Text(this.composerNotice)
                        .id(ID_CHAT_DETAIL_SEND_NOTICE)
                        .fontSize(12)
                        .fontColor(COLOR_STATUS_ERROR)
                        .width(100.percent)
                }

                Row(12) {
                    TextInput(text: this.composerText, placeholder: CHAT_DETAIL_COMPOSER_COPY)
                        .id(ID_CHAT_DETAIL_COMPOSER_INPUT)
                        .layoutWeight(1)
                        .height(46)
                        .backgroundColor(COLOR_SURFACE_SUBTLE)
                        .fontSize(15)
                        .fontColor(COLOR_TEXT_PRIMARY)
                        .textAlign(TextAlign.Start)
                        .padding(left: 16, right: 16, top: 0, bottom: 0)
                        .borderRadius(22)
                        .onChange({ value: String =>
                            this.updateComposerText(value)
                        })

                    Button(CHAT_DETAIL_SEND_COPY)
                        .id(ID_CHAT_DETAIL_COMPOSER_SEND)
                        .height(46)
                        .backgroundColor(if (this.isComposerReady()) {
                            COLOR_BRAND
                        } else {
                            COLOR_SURFACE_SUBTLE
                        })
                        .fontColor(if (this.isComposerReady()) {
                            COLOR_SURFACE
                        } else {
                            COLOR_TEXT_MUTED
                        })
                        .fontWeight(FontWeight.Bold)
                        .borderRadius(23)
                        .padding(left: 16, right: 16)
                        .onClick({ =>
                            this.submitComposerMessage()
                        })
                }
            }
            .id(ID_CHAT_DETAIL_COMPOSER_SHELL)
            .width(100.percent)
            .padding(left: 16, right: 16, top: 12, bottom: 18)
            .backgroundColor(COLOR_SURFACE)
        }
        .id(ID_CHAT_DETAIL_ROOT)
        .width(100.percent)
        .height(100.percent)
        .backgroundColor(COLOR_APP_BACKGROUND)
    }
}
