package ohos_app_cangjie_entry

internal import ohos.base.AppLog

let SESSION_RESTORE_MISSING = "missing"
let SESSION_RESTORE_INVALID = "invalid"
let SESSION_RESTORE_RESTORED = "restored"

let PLACEHOLDER_TITLE = "Demo session ready"
let PLACEHOLDER_PHONE_LABEL = "Demo phone"
let PLACEHOLDER_SESSION_MODE_FRESH = "Signed in during this run"
let PLACEHOLDER_SESSION_MODE_RESTORED = "Restored local demo session"
let PLACEHOLDER_SESSION_DETAIL_PERSISTED = "This session is saved on this device until you clear it."
let PLACEHOLDER_SESSION_DETAIL_EPHEMERAL = "This session is active for this run only and will not restore on relaunch."
let PLACEHOLDER_BACK_LABEL = "Back to login shell"
let PLACEHOLDER_CLEAR_LABEL = "Clear local demo session"
let LOGIN_RESTORE_INVALID_NOTICE = "Saved demo session was invalid. Continue with phone login."

var currentDemoSessionPhoneNumber: String = ""
var currentDemoSessionRestored: Bool = false
var currentDemoSessionPersisted: Bool = false
var androidDemoSessionStoredPhoneNumber: String = ""

func clearCurrentDemoSessionPresentation(): Unit {
    currentDemoSessionPhoneNumber = ""
    currentDemoSessionRestored = false
    currentDemoSessionPersisted = false
}

func updateCurrentDemoSessionPresentation(
    phoneNumber: String,
    restored: Bool,
    persisted: Bool
): Unit {
    currentDemoSessionPhoneNumber = phoneNumber
    currentDemoSessionRestored = restored
    currentDemoSessionPersisted = persisted
}

func getCurrentDemoSessionPhoneNumber(): String {
    return currentDemoSessionPhoneNumber
}

func isCurrentDemoSessionRestored(): Bool {
    return currentDemoSessionRestored
}

func isCurrentDemoSessionPersisted(): Bool {
    return currentDemoSessionPersisted
}

func getCurrentDemoSessionModeCopy(): String {
    if (isCurrentDemoSessionRestored()) {
        return PLACEHOLDER_SESSION_MODE_RESTORED
    }
    return PLACEHOLDER_SESSION_MODE_FRESH
}

func getCurrentDemoSessionDetailCopy(): String {
    if (isCurrentDemoSessionPersisted()) {
        return PLACEHOLDER_SESSION_DETAIL_PERSISTED
    }
    return PLACEHOLDER_SESSION_DETAIL_EPHEMERAL
}

@When[target_platform == "ios"]
func writeDemoSessionStorage(phoneNumber: String): Bool {
    let phoneCString = unsafe { LibC.mallocCString(phoneNumber) }
    let didPersist = unsafe { FfiSaveDemoSessionPhone(phoneCString) }
    unsafe { LibC.free(phoneCString) }
    return didPersist == 1
}

@When[target_platform == "ios-sim"]
func writeDemoSessionStorage(phoneNumber: String): Bool {
    let phoneCString = unsafe { LibC.mallocCString(phoneNumber) }
    let didPersist = unsafe { FfiSaveDemoSessionPhone(phoneCString) }
    unsafe { LibC.free(phoneCString) }
    return didPersist == 1
}

@When[target_platform == "android"]
func writeDemoSessionStorage(phoneNumber: String): Bool {
    androidDemoSessionStoredPhoneNumber = phoneNumber
    return true
}

@When[target_platform == "ios"]
func readDemoSessionStorage(): String {
    let storedPhone: CString = unsafe { FfiLoadDemoSessionPhone() }
    let result = storedPhone.toString()
    unsafe { FfiFreeString(storedPhone) }
    return result
}

@When[target_platform == "ios-sim"]
func readDemoSessionStorage(): String {
    let storedPhone: CString = unsafe { FfiLoadDemoSessionPhone() }
    let result = storedPhone.toString()
    unsafe { FfiFreeString(storedPhone) }
    return result
}

@When[target_platform == "android"]
func readDemoSessionStorage(): String {
    return androidDemoSessionStoredPhoneNumber
}

@When[target_platform == "ios"]
func clearDemoSessionStorage(): Unit {
    unsafe { FfiClearDemoSessionPhone() }
}

@When[target_platform == "ios-sim"]
func clearDemoSessionStorage(): Unit {
    unsafe { FfiClearDemoSessionPhone() }
}

@When[target_platform == "android"]
func clearDemoSessionStorage(): Unit {
    androidDemoSessionStoredPhoneNumber = ""
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func writeDemoSessionStorage(phoneNumber: String): Bool {
    AppLog.error("demo session persistence is unavailable on the current target platform")
    return false
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func readDemoSessionStorage(): String {
    return ""
}

@When[target_platform != "ios" && target_platform != "ios-sim" && target_platform != "android"]
func clearDemoSessionStorage(): Unit {
}

func seedDemoSessionForSmoke(
    phoneNumber: String,
    isAuthenticated: Bool,
    keepSignedIn: Bool
): Unit {
    if (!isAuthenticated || !keepSignedIn) {
        clearDemoSession()
        return
    }
    if (!writeDemoSessionStorage(phoneNumber)) {
        AppLog.error("demo session storage unavailable while seeding smoke session")
    }
}

func clearDemoSession(): Unit {
    clearDemoSessionStorage()
    clearCurrentDemoSessionPresentation()
}

func persistDemoSession(phoneNumber: String, keepSignedIn: Bool): Bool {
    updateCurrentDemoSessionPresentation(phoneNumber, false, keepSignedIn)
    if (!keepSignedIn) {
        clearDemoSession()
        updateCurrentDemoSessionPresentation(phoneNumber, false, false)
        return false
    }
    if (writeDemoSessionStorage(phoneNumber)) {
        return true
    }
    AppLog.error("demo session storage unavailable while persisting login state")
    return false
}

func resolveDemoSessionRestoreState(): String {
    let phoneNumber = readDemoSessionStorage()
    if (phoneNumber.isEmpty()) {
        clearCurrentDemoSessionPresentation()
        return SESSION_RESTORE_MISSING
    }
    if (!isValidDemoPhone(phoneNumber)) {
        clearDemoSession()
        return SESSION_RESTORE_INVALID
    }
    updateCurrentDemoSessionPresentation(phoneNumber, true, true)
    return SESSION_RESTORE_RESTORED
}

@When[target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiSaveDemoSessionPhone(phoneNumber: CString): Int64

@When[target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiLoadDemoSessionPhone(): CString

@When[target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiClearDemoSessionPhone(): Unit

@When[target_platform == "android" || target_platform == "ios" || target_platform == "ios-sim"]
foreign func FfiFreeString(str: CString): Unit
