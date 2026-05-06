package ohos_app_cangjie_entry

import std.unittest.*
import std.unittest.common.*
import std.unittest.testmacro.*
import ohos.ui_test.Driver
import ohos.ui_test.On
import ohos.ui_test.UIComponent
import ohos.base.AppLog
import ohos.base.BusinessException
import ohos.router.Router

func logSmokeCheck(detail: String): Unit {
    setSmokeTrace(detail)
    AppLog.error("slice6 smoke: ${detail}")
}

func failSmokeStep(detail: String): Unit {
    logSmokeCheck("FAIL ${detail}")
    throw IllegalStateException(detail)
}

func assertSmoke(condition: Bool, detail: String): Unit {
    logSmokeCheck("ASSERT ${detail}")
    if (!condition) {
        failSmokeStep(detail)
    }
}

func waitForSmokeComponent(
    driver: Driver,
    id: String,
    detail: String
): UIComponent {
    return waitForSmokeComponent(driver, id, detail, 3000)
}

func waitForSmokeComponent(
    driver: Driver,
    id: String,
    detail: String,
    timeoutMs: Int32
): UIComponent {
    logSmokeCheck("WAIT ${detail} [${id}]")
    let pauseMs: Int32 = 500
    let attempts: Int32 = timeoutMs / pauseMs
    for (i in 0..attempts) {
        try {
            if (id == ID_CHAT_DETAIL_COMPOSER_INPUT){
                
            }
            return driver.findComponent(On().id(id))
        } catch (e: BusinessException) {
            if (i == attempts) {
                break
            }
            driver.delayMs(pauseMs)
        }
    }
    let missingDetail = "${detail}: missing ${id}"
    logSmokeCheck("FAIL ${missingDetail}")
    throw IllegalStateException(missingDetail)
}

func assertSmokeComponentExists(driver: Driver, id: String, detail: String): Unit {
    logSmokeCheck("ASSERT EXISTS ${detail} [${id}]")
    driver.assertComponentExist(On().id(id))
}

func logSmokeExpect(detail: String): Unit {
    logSmokeCheck("EXPECT ${detail}")
}

func expectSmokeBool(actual: Bool, expected: Bool, detail: String): Unit {
    logSmokeExpect(detail)
    if (actual != expected) {
        logSmokeCheck("EXPECT FAIL ${detail}; actual=${actual}; expected=${expected}")
    }
    @Expect(actual, expected)
}

func expectSmokeText(actual: String, expected: String, detail: String): Unit {
    logSmokeExpect(detail)
    if (actual != expected) {
        logSmokeCheck("EXPECT FAIL ${detail}; actual=${actual}; expected=${expected}")
    }
    @Expect(actual, expected)
}

func expectSmokeScrollText(
    list: UIComponent,
    id: String,
    expected: String,
    detail: String
): Unit {
    logSmokeCheck("SCROLL ${detail} [${id}]")
    match (list.scrollSearch(On().id(id))) {
        case Some(component) => handleSmokeScrollFound(component, id, expected, detail)
        case _ => handleSmokeScrollMissing(id, detail)
    }
}

func assertSmokeScrollMissing(
    list: UIComponent,
    id: String,
    detail: String
): Unit {
    logSmokeCheck("SCROLL MISS ${detail} [${id}]")
    match (list.scrollSearch(On().id(id))) {
        case Some(component) => handleUnexpectedSmokeScrollFound(component, id, detail)
        case None => handleExpectedSmokeScrollMissing(id, detail)
    }
}

func handleSmokeScrollFound(
    component: UIComponent,
    id: String,
    expected: String,
    detail: String
): Unit {
    let actualText = component.getText()
    logSmokeCheck("SCROLL FOUND ${detail} [${id}] text=${actualText}")
    expectSmokeText(actualText, expected, detail)
}

func handleSmokeScrollMissing(id: String, detail: String): Unit {
    logSmokeCheck("SCROLL NOT FOUND ${detail} [${id}]")
    failSmokeStep("${detail}: missing ${id}")
}

func handleUnexpectedSmokeScrollFound(
    component: UIComponent,
    id: String,
    detail: String
): Unit {
    logSmokeCheck("SCROLL UNEXPECTED FOUND ${detail} [${id}] text=${component.getText()}")
    failSmokeStep("${detail}: unexpected ${id}")
}

func handleExpectedSmokeScrollMissing(id: String, detail: String): Unit {
    logSmokeCheck("SCROLL MISSING OK ${detail} [${id}]")
    logSmokeExpect(detail)
}

func logSmokeComponentSnapshot(
    driver: Driver,
    id: String,
    label: String,
    includeText: Bool
): Unit {
    try {
        let component = driver.findComponent(On().id(id))
        var snapshot = "SNAPSHOT ${label} [${id}] clickable=${component.isClickable()}"
        if (includeText) {
            snapshot = "${snapshot} text=${component.getText()}"
        }
        logSmokeCheck(snapshot)
    } catch (e: BusinessException) {
        logSmokeCheck("SNAPSHOT ${label} [${id}] missing")
    }
}

func logContactsSurfaceSnapshot(driver: Driver, stage: String): Unit {
    logSmokeCheck("CONTACTS SNAPSHOT ${stage}")
    logSmokeComponentSnapshot(driver, ID_HOME_CONTACTS_SEARCH, "contacts search", true)
    logSmokeComponentSnapshot(driver, ID_HOME_CONTACTS_QUICK_ACTION_ADD, "quick action add", true)
    logSmokeComponentSnapshot(driver, ID_HOME_CONTACTS_QUICK_ACTION_NEARBY, "quick action nearby", true)
    logSmokeComponentSnapshot(driver, ID_HOME_CONTACTS_NAME_ALEX, "contact alex", true)
    logSmokeComponentSnapshot(driver, ID_HOME_CONTACTS_NAME_SARA, "contact sara", true)
    logSmokeComponentSnapshot(driver, ID_HOME_ACTION_NOTICE, "home action notice", true)
}
//  首先根据按钮的ID进入测试，而非单纯检索按钮文字
//  进入后自动执行，错误就是下面内部的错误
//  结尾的时候，有内部流程问题，这里的页面没有返回smoke test，而swift那里确认为这里的test最后已经会返回smoke test，所以检测不到对应内容，AI自己去跑就报错了
@Test
public class TelegramSlice6SmokeSuite {
    @TestCase
    func test_phase0_tdjson_native_probe(): Unit {
        logSmokeCheck(">>> test_phase0_tdjson_native_probe STARTED <<<")
        let result = runTdjsonPhase0Probe()
        logSmokeCheck("TDLib phase0 probe result: ${result}")
        assertSmoke(isTdjsonPhase0ProbeSuccess(result), "TDLib phase0 native probe should succeed: ${result}")
        logSmokeCheck(">>> test_phase0_tdjson_native_probe COMPLETED <<<")
    }

    @TestCase
    func test_slice4_contacts_and_settings_surfaces(): Unit {
        let driver = Driver.create()
        try {
            driver.delayMs(400)
            logSmokeCheck("Contacts and settings smoke suite bootstrapped from the UI test page")

            clearDemoSession()
            driver.delayMs(400)
            assertSmoke(persistDemoSession("+8613800138000", true), "Contacts/settings smoke should persist a valid demo session")
            driver.delayMs(400)
            assertSmoke(resolveDemoSessionRestoreState() == SESSION_RESTORE_RESTORED, "Contacts/settings smoke should restore the persisted session")
            driver.delayMs(400)

            let openHomePreview = waitForSmokeComponent(driver, ID_SMOKE_OPEN_HOME, "Open the home shell preview for contacts/settings coverage", 4000)
            expectSmokeBool(openHomePreview.isClickable(), true, "Open home preview button should be clickable for contacts/settings coverage")
            openHomePreview.click()

            let homeSmokeBack = waitForSmokeComponent(driver, ID_HOME_SMOKE_BACK, "Expect the smoke back action after opening the home shell preview", 5000)

            let contactsTab = waitForSmokeComponent(driver, ID_HOME_TAB_CONTACTS, "Switch to Contacts tab for the shared grouped list surface")
            expectSmokeBool(contactsTab.isClickable(), true, "Contacts tab should be clickable for the shared grouped list surface")
            contactsTab.click()
            driver.delayMs(500)
            
            let contactsTitle = waitForSmokeComponent(driver, ID_HOME_TITLE, "Expect the Contacts title after switching tabs")
            expectSmokeText(contactsTitle.getText(), HOME_TITLE_CONTACTS, "Contacts title should match the shared design copy")
            let contactsSubtitle = waitForSmokeComponent(driver, ID_HOME_SUBTITLE, "Expect the Contacts subtitle after switching tabs")
            expectSmokeText(contactsSubtitle.getText(), HOME_SUBTITLE_CONTACTS, "Contacts subtitle should match the shared design copy")
            assertSmokeComponentExists(driver, ID_HOME_CONTACTS_PLACEHOLDER, "Contacts tab should expose the real grouped-list surface")
            logContactsSurfaceSnapshot(driver, "after opening contacts tab")

            let contactsSearch = waitForSmokeComponent(driver, ID_HOME_CONTACTS_SEARCH, "Expect the Contacts search field")
            expectSmokeBool(contactsSearch.isClickable(), true, "Contacts search field should be clickable")

            let contactsQuickActionsTitle = waitForSmokeComponent(driver, ID_HOME_CONTACTS_QUICK_ACTIONS_TITLE, "Expect the Contacts quick actions title")
            expectSmokeText(contactsQuickActionsTitle.getText(), HOME_CONTACTS_QUICK_ACTIONS_TITLE, "Contacts quick actions title should match the shared copy")
            let quickActionAdd = waitForSmokeComponent(driver, ID_HOME_CONTACTS_QUICK_ACTION_ADD, "Expect the Add Contact quick action")
            expectSmokeText(quickActionAdd.getText(), HOME_CONTACTS_QUICK_ACTION_ADD, "Add Contact quick action should match the shared copy")
            let quickActionNearby = waitForSmokeComponent(driver, ID_HOME_CONTACTS_QUICK_ACTION_NEARBY, "Expect the People Nearby quick action")
            expectSmokeText(quickActionNearby.getText(), HOME_CONTACTS_QUICK_ACTION_NEARBY, "People Nearby quick action should match the shared copy")
            let quickActionInvite = waitForSmokeComponent(driver, ID_HOME_CONTACTS_QUICK_ACTION_INVITE, "Expect the Invite Friends quick action")
            expectSmokeText(quickActionInvite.getText(), HOME_CONTACTS_QUICK_ACTION_INVITE, "Invite Friends quick action should match the shared copy")
            expectSmokeBool(quickActionAdd.isClickable(), true, "Add Contact quick action should be clickable")
            quickActionAdd.click()
            let contactsActionNotice = waitForSmokeComponent(driver, ID_HOME_ACTION_NOTICE, "Expect the Contacts quick action feedback notice")
            expectSmokeText(contactsActionNotice.getText(), "${HOME_CONTACTS_QUICK_ACTION_ADD} ${HOME_ACTION_NOTICE_SUFFIX}", "Contacts quick action should show deferred feedback")
            logContactsSurfaceSnapshot(driver, "after tapping add contact quick action")

            let contactsList = waitForSmokeComponent(driver, ID_HOME_CONTACTS_LIST, "Expect the Contacts list for grouped contacts")
            let contactsAlex = waitForSmokeComponent(driver, ID_HOME_CONTACTS_NAME_ALEX, "Expect the A section seed contact near the top of Contacts")
            expectSmokeText(contactsAlex.getText(), "Alex Mason", "Contacts list should include the A section seed contact before filtering")

            let contactsSearchForInput = waitForSmokeComponent(driver, ID_HOME_CONTACTS_SEARCH, "Reacquire the Contacts search field before typing")
            expectSmokeBool(contactsSearchForInput.isClickable(), true, "Reacquired Contacts search field should be clickable")
            contactsSearchForInput.click()
            contactsSearchForInput.clearText()
            logSmokeCheck("CONTACTS search input probe: typing Sa into the visible search field")
            contactsSearchForInput.inputText("Sa")
            driver.delayMs(300)
            expectSmokeText(contactsSearchForInput.getText(), "Sa", "Contacts search field should accept user input")
            logContactsSurfaceSnapshot(driver, "after entering Sa in contacts search")
            let filteredContactsList = waitForSmokeComponent(driver, ID_HOME_CONTACTS_LIST, "Expect the filtered Contacts list after searching")
            logSmokeCheck("CONTACTS filtered probe: expect Alex missing and Sara visible")
            try {
                driver.findComponent(On().id(ID_HOME_CONTACTS_NAME_ALEX))
                failSmokeStep("Contacts search should filter Alex out for the Sa query but Alex was found")
            } catch (e: BusinessException) {
                logSmokeCheck("CONTACTS filtered probe: Alex correctly absent after Sa filter")
            }
            let saraStatus = driver.findComponent(On().id(ID_HOME_CONTACTS_STATUS_SARA))
            expectSmokeText(saraStatus.getText(), HOME_CONTACT_STATUS_LAST_SEEN_RECENTLY, "Sara should expose the shared last-seen status")

            let settingsTab = waitForSmokeComponent(driver, ID_HOME_TAB_SETTINGS, "Switch to Settings tab for the shared grouped list surface")
            expectSmokeBool(settingsTab.isClickable(), true, "Settings tab should be clickable for the shared grouped list surface")
            settingsTab.click()
            driver.delayMs(500)

            let settingsTitle = waitForSmokeComponent(driver, ID_HOME_TITLE, "Expect the Settings title after switching tabs")
            expectSmokeText(settingsTitle.getText(), HOME_TITLE_SETTINGS, "Settings title should match the shared design copy")
            let settingsSubtitle = waitForSmokeComponent(driver, ID_HOME_SUBTITLE, "Expect the Settings subtitle after switching tabs")
            expectSmokeText(settingsSubtitle.getText(), HOME_SUBTITLE_SETTINGS, "Settings subtitle should match the shared design copy")
            assertSmokeComponentExists(driver, ID_HOME_SETTINGS_PLACEHOLDER, "Settings tab should expose the real grouped-list surface")

            let settingsProfileTitle = waitForSmokeComponent(driver, ID_HOME_SETTINGS_PROFILE_TITLE, "Expect the Settings profile title")
            expectSmokeText(settingsProfileTitle.getText(), HOME_SETTINGS_PROFILE_TITLE, "Settings profile title should match the shared copy")
            let settingsProfilePhone = waitForSmokeComponent(driver, ID_HOME_SETTINGS_PROFILE_PHONE, "Expect the Settings profile phone number")
            expectSmokeText(settingsProfilePhone.getText(), HOME_SETTINGS_PROFILE_PHONE, "Settings profile phone should match the shared demo phone")
            let settingsSessionHeadline = waitForSmokeComponent(driver, ID_HOME_SETTINGS_SESSION_HEADLINE, "Expect the Settings session headline")
            expectSmokeText(settingsSessionHeadline.getText(), PLACEHOLDER_SESSION_MODE_RESTORED, "Settings session headline should show the restored-session copy")
            let settingsSessionBody = waitForSmokeComponent(driver, ID_HOME_SETTINGS_SESSION_BODY, "Expect the Settings session body")
            expectSmokeText(settingsSessionBody.getText(), PLACEHOLDER_SESSION_DETAIL_PERSISTED, "Settings session body should show the persisted-session detail copy")

            let settingsList = waitForSmokeComponent(driver, ID_HOME_SETTINGS_LIST, "Expect the Settings list for grouped sections")
            let settingsDevices = waitForSmokeComponent(driver, ID_HOME_SETTINGS_ITEM_DEVICES, "Expect the Devices row text")
            expectSmokeText(settingsDevices.getText(), HOME_SETTINGS_ITEM_DEVICES, "Settings list should include the Devices row")
            expectSmokeScrollText(settingsList, ID_HOME_SETTINGS_ITEM_PRIVACY, HOME_SETTINGS_ITEM_PRIVACY, "Settings list should include the Privacy and Security row")
            expectSmokeScrollText(settingsList, ID_HOME_SETTINGS_ITEM_FOLDERS, HOME_SETTINGS_ITEM_FOLDERS, "Settings list should include the Chat Folders row")
            expectSmokeBool(settingsDevices.isClickable(), true, "Settings Devices row should be clickable")
            settingsDevices.click()
            let settingsActionNotice = waitForSmokeComponent(driver, ID_HOME_ACTION_NOTICE, "Expect the Settings row feedback notice")
            expectSmokeText(settingsActionNotice.getText(), "${HOME_SETTINGS_ITEM_DEVICES} ${HOME_ACTION_NOTICE_SUFFIX}", "Settings rows should show deferred feedback")
            let signOutAction = waitForSmokeComponent(driver, ID_HOME_SETTINGS_SIGN_OUT, "Expect the visible Settings sign out action")
            expectSmokeText(signOutAction.getText(), HOME_SIGN_OUT_LABEL, "Settings should keep the sign out action visible above the grouped sections")

            let homeSmokeBackToTools = waitForSmokeComponent(driver, ID_HOME_SMOKE_BACK, "Return from the contacts/settings preview to the smoke tools")
            expectSmokeBool(homeSmokeBackToTools.isClickable(), true, "Back to smoke button should stay clickable after contacts/settings coverage")
            homeSmokeBackToTools.click()
            let _ = waitForSmokeComponent(driver, ID_SMOKE_RUN, "Expect the smoke page after completing contacts/settings coverage", 5000)
            logSmokeCheck("Contacts and settings smoke suite passed")
        } catch (e: Exception) {
            logSmokeCheck("Contacts and settings smoke suite failed at: ${getSmokeTrace()}")
            throw e
        }
    }

    @TestCase
    func test_slice6_home_chat_detail_and_local_send_flow(): Unit {
        let driver = Driver.create()
        try {
            driver.delayMs(400)
            logSmokeCheck("Smoke suite bootstrapped from the UI test page")

            clearDemoSession()
            driver.delayMs(400)
            assertSmoke(resolveDemoSessionRestoreState() == SESSION_RESTORE_MISSING, "Fresh smoke run should start without a saved demo session")
            driver.delayMs(400)
            assertSmoke(persistDemoSession("+8613800138000", true), "Valid demo session was not persisted")
            driver.delayMs(400)
            assertSmoke(resolveDemoSessionRestoreState() == SESSION_RESTORE_RESTORED, "Valid demo session was not persisted for relaunch restore")
            driver.delayMs(400)
            assertSmoke(getCurrentDemoSessionPhoneNumber() == "+8613800138000", "Persisted demo session did not keep the expected phone number")

            let openAlexDetailPreview = waitForSmokeComponent(driver, ID_SMOKE_OPEN_CHAT_DETAIL_ALEX, "Open the Alex chat detail preview from the smoke tools", 4000)
            expectSmokeBool(openAlexDetailPreview.isClickable(), true, "Open Alex chat detail preview button should be clickable")
            openAlexDetailPreview.click()
            let _ = waitForSmokeComponent(driver, ID_CHAT_DETAIL_MESSAGE_LIST, "Expect the chat detail message list after opening the Alex conversation", 5000)
            let detailBack = waitForSmokeComponent(driver, ID_CHAT_DETAIL_BACK, "Expect the chat detail back action after opening the Alex conversation", 5000)
            expectSmokeBool(detailBack.isClickable(), true, "Chat detail back button should be clickable")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_DATE_SEPARATOR, "Chat detail should show the date separator")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_MESSAGE_1, "Chat detail should show message 1")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_MESSAGE_2, "Chat detail should show message 2")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_MESSAGE_3, "Chat detail should show message 3")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_MESSAGE_4, "Chat detail should show message 4")
            let message2Delivery = waitForSmokeComponent(driver, ID_CHAT_DETAIL_MESSAGE_2_DELIVERY, "Expect delivery state on the first outgoing message")
            expectSmokeText(message2Delivery.getText(), "Read", "First outgoing message delivery state should be Read")
            let message4Delivery = waitForSmokeComponent(driver, ID_CHAT_DETAIL_MESSAGE_4_DELIVERY, "Expect delivery state on the second outgoing message")
            expectSmokeText(message4Delivery.getText(), "Read", "Second outgoing message delivery state should be Read")
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_COMPOSER_SHELL, "Chat detail should show the composer shell")
            let composerInput = waitForSmokeComponent(driver, ID_CHAT_DETAIL_COMPOSER_INPUT, "Expect the editable composer input")
            expectSmokeBool(composerInput.isClickable(), true, "Composer input should be clickable")
            logSmokeCheck("Start the first composer input interaction on chat detail")
            // composerInput.click()
            // composerInput.clearText()
            // bugpoint：版本切换0.2.2修复
            composerInput.inputText("Slice 6 local send works")

            let sendButton = waitForSmokeComponent(driver, ID_CHAT_DETAIL_COMPOSER_SEND, "Send a local demo message")
            expectSmokeBool(sendButton.isClickable(), true, "Send button should be clickable")
            logSmokeCheck("Tap the first local send action on chat detail")
            sendButton.click()

            let localMessage = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_TEXT, "Expect the local message append immediately")
            expectSmokeText(localMessage.getText(), "Slice 6 local send works", "Local message text should match the first sent draft")
            let localMessagePending = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY, "Expect the local message to start pending")
            expectSmokeText(localMessagePending.getText(), "Pending", "Local message delivery should start as Pending")

            driver.delayMs(1200)
            let localMessageSent = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY, "Expect the local message to settle to sent")
            expectSmokeText(localMessageSent.getText(), "Sent", "Local message delivery should settle to Sent")

            let composerAfterSuccess = waitForSmokeComponent(driver, ID_CHAT_DETAIL_COMPOSER_INPUT, "Expect the composer input after a successful send")
            expectSmokeText(composerAfterSuccess.getText(), "", "Composer input should clear after a successful send")
            logSmokeCheck("Start the recoverable failure composer interaction on chat detail")
            composerAfterSuccess.click()
            composerAfterSuccess.inputText("/fail retry path")
            sendButton.click()

            let sendFailure = waitForSmokeComponent(driver, ID_CHAT_DETAIL_SEND_NOTICE, "Expect a recoverable local send failure notice")
            expectSmokeText(sendFailure.getText(), CHAT_DETAIL_SEND_FAILURE_NOTICE, "Send failure notice should match the recoverable error copy")
            let composerAfterFailure = waitForSmokeComponent(driver, ID_CHAT_DETAIL_COMPOSER_INPUT, "Expect the failed draft to remain editable")
            expectSmokeText(composerAfterFailure.getText(), "/fail retry path", "Failed draft should remain in the composer input")
            logSmokeCheck("Start the recovery composer interaction on chat detail")
            composerAfterFailure.clearText()
            composerAfterFailure.inputText("Recovered local send")
            sendButton.click()
            driver.swipe(220, 760, 220, 320) // 新消息并无component ID，所以根据ID找是无法找到的，先换成截屏方式

            let recoveredLocalMessage = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_TEXT, "Expect the recovered local message append")
            expectSmokeText(recoveredLocalMessage.getText(), "Recovered local send", "Recovered local message text should match the second sent draft")
            let recoveredPending = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY, "Expect the recovered local message to start pending")
            expectSmokeText(recoveredPending.getText(), "Pending", "Recovered local message delivery should start as Pending")

            driver.delayMs(1200)
            let recoveredSent = waitForSmokeComponent(driver, ID_CHAT_DETAIL_LOCAL_MESSAGE_DELIVERY, "Expect the recovered local message to settle to sent")
            expectSmokeText(recoveredSent.getText(), "Sent", "Recovered local message delivery should settle to Sent")

            // bug point ，滑动后无法点击返回
            driver.swipe(220, 760, 220, 320)
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_CHAT_DETAIL_MESSAGE_LIST, "Chat detail message list should remain visible after scrolling")
            let detailBackAfterScroll = waitForSmokeComponent(driver, ID_CHAT_DETAIL_BACK, "Return from the chat detail to the smoke tools")
            expectSmokeBool(detailBackAfterScroll.isClickable(), true, "Detail back button should be clickable")
            detailBackAfterScroll.click()
            let _ = waitForSmokeComponent(driver, ID_SMOKE_OPEN_HOME, "Expect the smoke page controls after returning from chat detail", 5000)

            let openHomePreview = waitForSmokeComponent(driver, ID_SMOKE_OPEN_HOME, "Open the home shell preview from the smoke tools")
            expectSmokeBool(openHomePreview.isClickable(), true, "Open home preview button should be clickable")
            openHomePreview.click()
            let homeSmokeBack = waitForSmokeComponent(driver, ID_HOME_SMOKE_BACK, "Expect the smoke back action after opening the home shell preview", 5000)
            expectSmokeBool(homeSmokeBack.isClickable(), true, "Home smoke back button should be clickable")
            let _ = waitForSmokeComponent(driver, ID_HOME_SMOKE_SHOW_LOADING, "Expect the smoke state controls in the home shell preview")
            let _ = waitForSmokeComponent(driver, ID_HOME_CHAT_LIST, "Expect the populated chat list in the smoke preview")
            let _ = waitForSmokeComponent(driver, ID_CHAT_ROW_ALEX, "Expect the Alex conversation row")
            let _ = waitForSmokeComponent(driver, ID_CHAT_ROW_ALEX_UNREAD, "Expect the Alex unread badge")
            let _ = waitForSmokeComponent(driver, ID_CHAT_ROW_DESIGN, "Expect the Design Sync conversation row")
            let _ = waitForSmokeComponent(driver, ID_CHAT_ROW_OPS, "Expect the Ops Bot conversation row")
            let _ = waitForSmokeComponent(driver, ID_CHAT_ROW_OPS_UNREAD, "Expect the Ops unread badge")

            let loadingState = waitForSmokeComponent(driver, ID_HOME_SMOKE_SHOW_LOADING, "Switch to the loading preview state")
            expectSmokeBool(loadingState.isClickable(), true, "Loading state toggle should be clickable")
            loadingState.click()
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_HOME_CHAT_LIST_LOADING, "Loading state should show the loading list placeholder")

            let emptyState = waitForSmokeComponent(driver, ID_HOME_SMOKE_SHOW_EMPTY, "Switch to the empty preview state")
            expectSmokeBool(emptyState.isClickable(), true, "Empty state toggle should be clickable")
            emptyState.click()
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_HOME_CHAT_LIST_EMPTY, "Empty state should show the empty list placeholder")

            let errorState = waitForSmokeComponent(driver, ID_HOME_SMOKE_SHOW_ERROR, "Switch to the error preview state")
            expectSmokeBool(errorState.isClickable(), true, "Error state toggle should be clickable")
            errorState.click()
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_HOME_CHAT_LIST_ERROR, "Error state should show the error list placeholder")

            let retryButton = waitForSmokeComponent(driver, ID_HOME_CHAT_LIST_RETRY, "Recover the chat list from the error state")
            expectSmokeBool(retryButton.isClickable(), true, "Retry button should be clickable")
            retryButton.click()
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_HOME_CHAT_LIST, "Retry should recover the populated chat list")

            let contactsTab = waitForSmokeComponent(driver, ID_HOME_TAB_CONTACTS, "Switch to Contacts tab")
            expectSmokeBool(contactsTab.isClickable(), true, "Contacts tab should be clickable")
            contactsTab.click()
            driver.delayMs(500)
            assertSmokeComponentExists(driver, ID_HOME_CONTACTS_PLACEHOLDER, "Contacts tab should show the contacts placeholder")

            let settingsTab = waitForSmokeComponent(driver, ID_HOME_TAB_SETTINGS, "Switch to Settings tab")
            expectSmokeBool(settingsTab.isClickable(), true, "Settings tab should be clickable")
            settingsTab.click()
            driver.delayMs(500)
            assertSmokeComponentExists(driver, ID_HOME_SETTINGS_PLACEHOLDER, "Settings tab should show the settings placeholder")
            assertSmokeComponentExists(driver, ID_HOME_SETTINGS_SIGN_OUT, "Settings tab should show the sign out control")

            let chatsTab = waitForSmokeComponent(driver, ID_HOME_TAB_CHATS, "Return to Chats tab")
            expectSmokeBool(chatsTab.isClickable(), true, "Chats tab should be clickable")
            chatsTab.click()
            driver.delayMs(500)
            let _ = waitForSmokeComponent(driver, ID_HOME_CHAT_LIST, "Expect the populated chat list after returning to Chats")
            driver.swipe(200, 820, 200, 260)
            driver.delayMs(300)
            assertSmokeComponentExists(driver, ID_CHAT_ROW_OPS, "Chats tab should still show the Ops conversation after scrolling")
            logSmokeCheck("Chat list and chat detail checks completed with stable scrolling")
            let homeSmokeBackToTools = waitForSmokeComponent(driver, ID_HOME_SMOKE_BACK, "Return from the home preview to the smoke tools")
            expectSmokeBool(homeSmokeBackToTools.isClickable(), true, "Back to smoke button should be clickable")
            homeSmokeBackToTools.click()
            let _ = waitForSmokeComponent(driver, ID_SMOKE_RUN, "Expect the smoke page after returning from the home preview", 5000)
            logSmokeCheck("Returned to the smoke page after the home preview checks")

            logSmokeCheck("Smoke suite passed")
        } catch (e: Exception) {
            logSmokeCheck("Smoke suite failed at: ${getSmokeTrace()}")
            throw e
        }
    }
}
