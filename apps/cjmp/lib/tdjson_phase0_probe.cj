package ohos_app_cangjie_entry

let TDJSON_PHASE0_SUCCESS_PREFIX = "phase0_ok:"

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiRunTdjsonPhase0Probe(): CString

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
func runTdjsonPhase0Probe(): String {
    let result = unsafe { FfiRunTdjsonPhase0Probe() }
    let value = result.toString()
    // FfiFreeString is defined in demo_session_store.cj
    unsafe { FfiFreeString(result) }
    return value
}

@When[target_platform != "android" && target_platform != "ios" && target_platform != "ios-sim"]
func runTdjsonPhase0Probe(): String {
    return "phase0_skip:unsupported-platform"
}

func isTdjsonPhase0ProbeSuccess(result: String): Bool {
    return result.startsWith(TDJSON_PHASE0_SUCCESS_PREFIX)
}
