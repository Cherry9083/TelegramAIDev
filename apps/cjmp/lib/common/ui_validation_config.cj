@NonProduct
features {}

package ohos_app_cangjie_entry

var didUiTestAutoRouteStart: Bool = false

@When[ui_test == "autorun"]
func isUiTestAutorunEnabled(): Bool {
    return true
}

@When[ui_test != "autorun"]
func isUiTestAutorunEnabled(): Bool {
    return false
}

func tryMarkUiTestAutoRouteStarted(): Bool {
    if (didUiTestAutoRouteStart) {
        return false
    }
    didUiTestAutoRouteStart = true
    return true
}
