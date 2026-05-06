package ohos_app_cangjie_entry

internal import ohos.component.*
import ohos.base.AppLog
import ohos.router.Router
import ohos.state_macro_manage.Entry
import ohos.state_macro_manage.Component
import ohos.state_macro_manage.State
import std.unittest.*
import std.time.*

var smokeSuiteStatusSnapshot: String = SMOKE_IDLE
var smokeSuiteDetailSnapshot: String = getSmokeTrace()

func updateSmokeSuiteSnapshots(status: String, detail: String): Unit {
    smokeSuiteStatusSnapshot = status
    smokeSuiteDetailSnapshot = detail
}

func getSmokeSuiteStatusSnapshot(): String {
    return smokeSuiteStatusSnapshot
}

func getSmokeSuiteDetailSnapshot(): String {
    return smokeSuiteDetailSnapshot
}

@When[target_platform == "android"]
func scheduleSmokeSuiteStart(page: UITestPage): Unit {
    page.runSmokeSuite()
}

@When[target_platform != "android"]
func scheduleSmokeSuiteStart(page: UITestPage): Unit {
    let _ = spawn {
        sleep(500 * Duration.millisecond)
        page.runSmokeSuite()
    }
}

@When[target_platform == "android"]
func startSmokeSuiteOnCurrentPlatform(page: UITestPage): Unit {
    updateSmokeSuiteSnapshots(SMOKE_RUNNING, getSmokeTrace())
    if (unsafe { FfiStartSmokeSuiteRunner() } != 1) {
        setSmokeTrace("Smoke suite crashed: Android runner failed to start")
        updateSmokeSuiteSnapshots(SMOKE_CRASHED, getSmokeTrace())
        page.markSmokeCrashed(getSmokeTrace())
        return
    }
    let _ = spawn {
        while (true) {
            page.syncSmokeStateFromSnapshots()
            if (getSmokeSuiteStatusSnapshot() != SMOKE_RUNNING) {
                AppLog.info("telegram ui smoke report: detail=${getSmokeSuiteDetailSnapshot()}")
                break
            }
            sleep(200 * Duration.millisecond)
        }
    }
}

@When[target_platform != "android"]
func startSmokeSuiteOnCurrentPlatform(page: UITestPage): Unit {
    let _ = spawn {
        let report = TelegramSlice6SmokeSuite().asTestSuite().runTests()
        let detail = getSmokeTrace()
        let status = if (report.failedCount == 0 && report.errorCount == 0) {
            SMOKE_PASSED
        } else {
            SMOKE_FAILED
        }
        page.applySmokeCompletion(status, detail)
        AppLog.info("telegram ui smoke report: case=${report.caseCount} failed=${report.failedCount} error=${report.errorCount} detail=${detail}")
    }
}

@C
public func RunSmokeSuiteFromAttachedThread(): Int64 {
    try {
        let report = TelegramSlice6SmokeSuite().asTestSuite().runTests()
        let detail = getSmokeTrace()
        if (report.failedCount == 0 && report.errorCount == 0) {
            updateSmokeSuiteSnapshots(SMOKE_PASSED, detail)
            return 1
        }
        updateSmokeSuiteSnapshots(SMOKE_FAILED, detail)
        return 0
    } catch (e: Exception) {
        let detail = "Smoke suite crashed: ${e}"
        setSmokeTrace(detail)
        updateSmokeSuiteSnapshots(SMOKE_CRASHED, getSmokeTrace())
        return 0
    }
}

@Entry
@Component
class UITestPage {
    @State
    var smokeStatus: String = SMOKE_IDLE
    @State
    var smokeDetail: String = getSmokeTrace()

    protected override func aboutToAppear(): Unit {
        if (isUiTestAutorunEnabled()) {
            clearDemoSession()
            setSmokeTrace("Auto-run: cleared session, launching smoke suite")
            this.smokeDetail = getSmokeTrace()
            scheduleSmokeSuiteStart(this)
        }
    }

    func runSmokeSuite(): Unit {
        if (this.smokeStatus == SMOKE_RUNNING) {
            return
        }
        setSmokeTrace("Launching smoke suite")
        this.smokeStatus = SMOKE_RUNNING
        this.smokeDetail = getSmokeTrace()
        updateSmokeSuiteSnapshots(this.smokeStatus, this.smokeDetail)
        startSmokeSuiteOnCurrentPlatform(this)
    }

    func clearSavedDemoSession(): Unit {
        clearDemoSession()
        setSmokeTrace("Saved demo session cleared")
        this.smokeStatus = SMOKE_IDLE
        this.smokeDetail = getSmokeTrace()
    }

    func markSmokeCrashed(detail: String): Unit {
        this.smokeStatus = SMOKE_CRASHED
        this.smokeDetail = detail
    }

    func syncSmokeStateFromSnapshots(): Unit {
        this.smokeStatus = getSmokeSuiteStatusSnapshot()
        this.smokeDetail = getSmokeSuiteDetailSnapshot()
    }

    func applySmokeCompletion(status: String, detail: String): Unit {
        this.smokeStatus = status
        this.smokeDetail = detail
        updateSmokeSuiteSnapshots(status, detail)
    }

    func build() {
        Column(12) {
            Text("Telegram MVP UI smoke tools")
                .fontSize(24)
                .fontColor(COLOR_TEXT_PRIMARY)
                .fontWeight(FontWeight.Bold)

            Text("This page is implementation-local and is excluded from the canonical product UI.")
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .width(100.percent)

            Text(this.smokeStatus)
                .id(ID_SMOKE_STATUS)
                .fontSize(20)
                .fontColor(COLOR_TEXT_PRIMARY)
                .fontWeight(FontWeight.Bold)
                .padding(left: 16, right: 16, top: 14, bottom: 14)
                .width(100.percent)
                .backgroundColor(COLOR_SURFACE)
                .borderRadius(18)
                .textAlign(TextAlign.Center)

            Text("Trace: ${this.smokeDetail}")
                .id(ID_SMOKE_DETAIL)
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .width(100.percent)
                .padding(left: 14, right: 14, top: 10, bottom: 10)
                .backgroundColor(COLOR_BRAND_SOFT)
                .borderRadius(16)
                .maxLines(4)

            Button("Open home shell preview")
                .id(ID_SMOKE_OPEN_HOME)
                .width(100.percent)
                .height(48)
                .backgroundColor(COLOR_SURFACE)
                .fontColor(COLOR_TEXT_PRIMARY)
                .borderRadius(18)
                .onClick({ =>
                    Router.push(url: ROUTE_HOME_SHELL, params: ENTRY_MODE_HOME_SMOKE_DEFAULT)
                })

            Button("Open Alex chat detail preview")
                .id(ID_SMOKE_OPEN_CHAT_DETAIL_ALEX)
                .width(100.percent)
                .height(48)
                .backgroundColor(COLOR_SURFACE)
                .fontColor(COLOR_TEXT_PRIMARY)
                .borderRadius(18)
                .onClick({ =>
                    Router.push(url: ROUTE_CHAT_DETAIL, params: CHAT_DETAIL_CONVERSATION_ALEX)
                })

            Button("Run smoke check")
                .id(ID_SMOKE_RUN)
                .width(100.percent)
                .height(52)
                .backgroundColor(COLOR_BRAND)
                .fontColor(COLOR_SURFACE)
                .borderRadius(26)
                .fontWeight(FontWeight.Bold)
                .onClick({ =>
                    this.runSmokeSuite()
                })

            if (!isUiTestAutorunEnabled()) {
                Button("Open login shell")
                    .id(ID_SMOKE_OPEN_LOGIN)
                    .width(100.percent)
                    .height(48)
                    .backgroundColor(COLOR_SURFACE)
                    .fontColor(COLOR_TEXT_PRIMARY)
                    .borderRadius(18)
                    .onClick({ =>
                        Router.push(url: "EntryView", params: ENTRY_MODE_SMOKE_LOGIN)
                    })

                Button("Open demo login shell")
                    .id(ID_SMOKE_OPEN_LOGIN_DEMO)
                    .width(100.percent)
                    .height(48)
                    .backgroundColor(COLOR_SURFACE)
                    .fontColor(COLOR_TEXT_PRIMARY)
                    .borderRadius(18)
                    .onClick({ =>
                        Router.push(url: "EntryView", params: ENTRY_MODE_SMOKE_LOGIN_DEMO)
                    })

                Button("Clear local demo session")
                    .id(ID_SMOKE_CLEAR_SESSION)
                    .width(100.percent)
                    .height(48)
                    .backgroundColor(COLOR_SURFACE)
                    .fontColor(COLOR_TEXT_PRIMARY)
                    .borderRadius(18)
                    .onClick({ =>
                        this.clearSavedDemoSession()
                    })

                Button("Back to login shell")
                    .id(ID_SMOKE_BACK)
                    .width(100.percent)
                    .height(44)
                    .backgroundColor(COLOR_BRAND_SOFT)
                    .fontColor(COLOR_BRAND)
                    .borderRadius(22)
                    .onClick({ =>
                        Router.back()
                    })
            }
        }
        .id(ID_SMOKE_ROOT)
        .width(100.percent)
        .height(100.percent)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .padding(left: 24, right: 24, top: 24, bottom: 24)
        .backgroundColor(COLOR_APP_BACKGROUND)
    }
}

@When[target_platform == "android"]
foreign func FfiStartSmokeSuiteRunner(): Int64
