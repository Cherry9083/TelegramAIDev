@NonProduct
features {}

package ohos_app_cangjie_entry

internal import ohos.component.*
import ohos.router.Router
import ohos.state_macro_manage.Entry
import ohos.state_macro_manage.Component

@Entry
@Component
class AuthenticatedPlaceholderPage {
    func returnToLoginShell(): Unit {
        Router.back()
    }

    func clearSessionAndReturn(): Unit {
        clearDemoSession()
        Router.back()
    }

    func build() {
        Column(16) {
            Image("resources/base/media/app-mark.svg")
                .width(72)
                .height(72)

            Text(PLACEHOLDER_TITLE)
                .id(ID_PLACEHOLDER_TITLE)
                .fontSize(20)
                .fontColor(COLOR_TEXT_PRIMARY)
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)

            Text(SHARED_AUTHENTICATED_DESTINATION_ID)
                .id(ID_PLACEHOLDER_DESTINATION)
                .fontSize(12)
                .fontColor(COLOR_TEXT_MUTED)
                .padding(left: 12, right: 12, top: 6, bottom: 6)
                .backgroundColor(COLOR_SURFACE_SUBTLE)
                .borderRadius(999)

            Text(getCurrentDemoSessionModeCopy())
                .id(ID_PLACEHOLDER_SESSION_MODE)
                .fontSize(16)
                .fontColor(COLOR_TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)

            Text("${PLACEHOLDER_PHONE_LABEL}: ${getCurrentDemoSessionPhoneNumber()}")
                .id(ID_PLACEHOLDER_PHONE)
                .fontSize(14)
                .fontColor(COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .width(100.percent)

            Text(getCurrentDemoSessionDetailCopy())
                .id(ID_PLACEHOLDER_SESSION_DETAIL)
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .width(100.percent)

            Text(PLACEHOLDER_NOTICE)
                .id(ID_PLACEHOLDER_NOTICE)
                .fontSize(14)
                .fontColor(COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .width(100.percent)

            Button(PLACEHOLDER_BACK_LABEL)
                .id(ID_PLACEHOLDER_BACK)
                .width(100.percent)
                .height(44)
                .backgroundColor(COLOR_BRAND_SOFT)
                .fontColor(COLOR_BRAND)
                .borderRadius(22)
                .onClick({ =>
                    this.returnToLoginShell()
                })

            Button(PLACEHOLDER_CLEAR_LABEL)
                .id(ID_PLACEHOLDER_CLEAR_SESSION)
                .width(100.percent)
                .height(44)
                .backgroundColor(COLOR_SURFACE)
                .fontColor(COLOR_TEXT_PRIMARY)
                .borderRadius(22)
                .onClick({ =>
                    this.clearSessionAndReturn()
                })
        }
        .id(ID_PLACEHOLDER_ROOT)
        .width(100.percent)
        .height(100.percent)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(left: 28, right: 28, top: 28, bottom: 28)
        .backgroundColor(COLOR_APP_BACKGROUND)
    }
}
