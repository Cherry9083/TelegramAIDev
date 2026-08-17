features {os.ios}

package ohos_app_cangjie_entry

specific public func logicTest(): String {
    let nativeResult: CString = unsafe { FfiLogicTest() }
    let result = nativeResult.toString()
    unsafe { FfiFreeString(nativeResult) }
    result
}

foreign func FfiLogicTest(): CString

// FfiFreeString is declared in common/demo_session_store.cj (visible to all source-sets)
