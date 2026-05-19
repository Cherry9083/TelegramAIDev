package ohos_app_cangjie_entry

internal import ohos.component.*

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
type PlatformListScroller = ListScroller

@When[target_platform != "android" && target_platform != "ios" && target_platform != "ios-sim"]
type PlatformListScroller = Scroller
