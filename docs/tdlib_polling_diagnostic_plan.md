# TDLib Polling Diagnostic Plan

## Problem Summary

After submitting a phone number to TDLib, the polling loop continuously returns NULL (no updates). The FFI bridge confirms that:
- ✅ `td_json_client_send` is called successfully (returns void, no errors)
- ✅ Polling loop is running (iterations 138, 193, 194...)
- ❌ `td_json_client_receive` returns NULL on every call

## Root Cause Hypotheses

### Hypothesis 1: Malformed Phone Request JSON
TDLib might be silently rejecting the phone request due to incorrect JSON format.

**Evidence needed:**
- Full phone request JSON (not truncated)
- Verify phone number format (must be international: +1234567890)

### Hypothesis 2: Missing TDLib Database Directories
TDLib requires database directories to exist before it can process requests.

**Evidence needed:**
- Check if `${filesDir}/telegram_tdlib_db` exists
- Check if `${filesDir}/telegram_tdlib_files` exists

### Hypothesis 3: TDLib Client in Bad State
The initial bootstrap might not have completed properly, leaving TDLib in a state where it ignores requests.

**Evidence needed:**
- Verify initial update was received after client creation
- Verify `authorizationStateWaitTdlibParameters` was processed
- Verify `authorizationStateWaitPhoneNumber` was received before phone submission

### Hypothesis 4: TDLib Sending Updates But Not Being Received
The FFI bridge or threading might have an issue where updates are lost.

**Evidence needed:**
- Check if ANY updates are received (connection state, errors, etc.)
- Verify the polling thread is actually calling the FFI function

## Diagnostic Changes Made

### 1. Enhanced Polling Loop Logging
**File:** `telegram_tdlib_facade.cj` - `startTelegramAuthPollingIfNeeded()`

**Added:**
- Track consecutive NULL responses
- Log warning every 10 NULL responses with current state
- Show `submitInFlight` flag status

**What to look for:**
```
telegram auth poll: WARNING - 10 consecutive NULL responses, current step=waiting_phone_number, submitInFlight=true
```

If `submitInFlight=true` after phone submission, it means TDLib never responded with ANY update (not even an error).

### 2. Full Phone Request JSON Logging
**File:** `telegram_tdlib_facade.cj` - `submitTelegramPhoneNumber()`

**Added:**
- Log full request JSON (not truncated)
- Log current auth step before submission
- Log `submitInFlight` flag status

**What to look for:**
```
submitTelegramPhoneNumber: FULL REQUEST JSON: {"@type":"setAuthenticationPhoneNumber","@extra":"submit-phone","phone_number":"+1234567890","settings":{...}}
```

Verify:
- Phone number has `+` prefix
- JSON is well-formed
- `@type` is correct

### 3. Bootstrap State Verification
**File:** `telegram_tdlib_facade.cj` - `bootstrapTelegramAuth()`

**Added:**
- Log application files directory
- Log database and files paths
- Warn if no initial update received
- Log auth step after initial update

**What to look for:**
```
bootstrapTelegramAuth: WARNING - no initial update received from TDLib!
```

This would indicate TDLib client creation succeeded but it's not sending the initial state.

### 4. Parameters Submission Logging
**File:** `telegram_tdlib_facade.cj` - `updateTelegramAuthStepFromRawJson()`

**Added:**
- Log when `authorizationStateWaitTdlibParameters` is received
- Log when parameters are being prepared
- Log parameters request length
- Log success/failure of parameter submission
- Log when `authorizationStateWaitPhoneNumber` is received

**What to look for:**
```
telegram auth: received authorizationStateWaitTdlibParameters
telegram auth: sending setTdlibParameters, length=XXX
telegram auth: parameters submitted successfully, waiting for next state
telegram auth: received authorizationStateWaitPhoneNumber - ready for phone input
```

If this sequence is incomplete, the bootstrap failed.

### 5. Non-Auth Update Logging
**File:** `telegram_tdlib_facade.cj` - `updateTelegramAuthStepFromRawJson()`

**Added:**
- Log ALL updates received, even non-auth ones
- Show first 100 chars of ignored updates

**What to look for:**
```
telegram auth: received non-auth update (ignoring): {"@type":"updateOption",...}
```

If we see ANY updates (even non-auth), it proves TDLib is responding and the FFI bridge works.

## Next Steps

### Step 1: Rebuild and Run
```bash
cd apps/cjmp
# Build for Android
./gradlew assembleDebug

# Install and run
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
adb logcat -c
adb logcat | grep -E "(CJApp|CJMP_JNI)"
```

### Step 2: Analyze Logs

Look for these key log sequences:

**Bootstrap sequence (should see):**
1. `bootstrapTelegramAuth: creating TDLib client`
2. `bootstrapTelegramAuth: client handle = 1`
3. `bootstrapTelegramAuth: initial update: {...authorizationStateWaitTdlibParameters...}`
4. `telegram auth: received authorizationStateWaitTdlibParameters`
5. `telegram auth: sending setTdlibParameters, length=XXX`
6. `telegram auth: received authorizationStateWaitPhoneNumber - ready for phone input`

**Phone submission sequence (should see):**
1. `submitTelegramPhoneNumber: FULL REQUEST JSON: {...}`
2. `submitTelegramPhoneNumber: request sent successfully`
3. Within 1-5 seconds: `telegram auth: RECEIVED UPDATE: {...authorizationStateWaitCode...}`

**If stuck (what we're seeing now):**
1. `submitTelegramPhoneNumber: request sent successfully`
2. `telegram auth poll: WARNING - 10 consecutive NULL responses, current step=waiting_phone_number, submitInFlight=true`

### Step 3: Root Cause Identification

Based on the logs, we can determine:

**If no initial update received:**
- TDLib client creation is broken
- Check TDLib library version compatibility

**If initial update received but no phone response:**
- Check the FULL phone request JSON
- Verify phone number format
- Check if TDLib is sending errors (look for `"@type":"error"`)

**If ANY non-auth updates received:**
- TDLib is working, but phone request is malformed or ignored
- Focus on phone request JSON format

**If absolutely NO updates after bootstrap:**
- TDLib might be waiting for database directories to be created
- Check filesystem permissions
- Check if TDLib requires explicit directory creation

## Expected Fix

Based on the most likely root cause, the fix will be one of:

1. **Create TDLib directories before client creation**
2. **Fix phone number format** (ensure `+` prefix)
3. **Fix phone request JSON structure**
4. **Increase TDLib log verbosity** to see internal errors

## Reference: TDLib Phone Request Format

Correct format:
```json
{
  "@type": "setAuthenticationPhoneNumber",
  "@extra": "submit-phone",
  "phone_number": "+1234567890",
  "settings": {
    "allow_flash_call": false,
    "allow_missed_call": false,
    "is_current_phone_number": false,
    "allow_sms_retriever_api": false
  }
}
```

Phone number MUST:
- Start with `+`
- Include country code
- Contain only digits after `+`
- Be a valid Telegram-registered number
