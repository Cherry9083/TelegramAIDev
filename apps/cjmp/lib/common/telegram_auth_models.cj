@NonProduct
features {}

package ohos_app_cangjie_entry

let TELEGRAM_AUTH_STEP_BOOTING = "booting"
let TELEGRAM_AUTH_STEP_PHONE = "waiting_phone_number"
let TELEGRAM_AUTH_STEP_CODE = "waiting_code"
let TELEGRAM_AUTH_STEP_PASSWORD = "waiting_password"
let TELEGRAM_AUTH_STEP_READY = "ready"
let TELEGRAM_AUTH_STEP_FAILED = "failed"

let TELEGRAM_CONNECTION_WAITING = "waiting_for_network"
let TELEGRAM_CONNECTION_READY = "ready"

func isTelegramAuthTerminalStep(step: String): Bool {
    return step == TELEGRAM_AUTH_STEP_READY || step == TELEGRAM_AUTH_STEP_FAILED
}
