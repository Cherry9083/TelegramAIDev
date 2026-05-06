# Telegram Commercial MVP CJMP Round Log

Use this file for per-round `CJMP` delivery and acceptance updates for the Telegram commercial MVP slice set.

Each round entry should include:

- timestamp
- framework lane: `CJMP`
- work item type and issue reference
- concise working effort or acceptance summary
- total duration
- internal step duration
- token consumption or `not observable`
- validation completed in the round
- parity impact, delivery status change, acceptance outcome, or notable workaround
- AI-efficiency friction summary, or `no confirmed friction in this round`
- 

## 2026-05-06 Round K

- timestamp: `2026-05-06T04:54:23Z` to `2026-05-06T05:54:xxZ`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `phase-0-android-ios-hos-feasibility-spike`
- concise working effort summary:
  - added a phase-0-only TDLib build script at [/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/scripts/build_tdlib_phase0.sh](/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/scripts/build_tdlib_phase0.sh) to build the minimum required `tdjson` artifacts for Android `arm64-v8a` and iOS simulator `arm64`
  - extended the existing Android JNI bridge and iOS Objective-C FFI bridge with a synchronous `tdjson` probe that loads the built library via `dlopen/dlsym`, creates a client, sends `getTextEntities`, polls for the response, and returns a prefixed success/failure string
  - wired the probe into the existing CJMP smoke suite and updated the shared build pipeline so Android copies `libtdjson.so` and iOS/iOS-sim copy `libtdjson.dylib` into the existing runtime packaging locations
  - rebuilt the CJMP Android app with `tdjson`, installed it onto the connected Android device, and confirmed the autorun smoke suite still completes with a terminal `passed` status
  - rebuilt the CJMP iOS simulator app path after fixing two repo-local compile issues surfaced by the new probe work, and confirmed `libtdjson.dylib` is copied into `/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/ios/frameworks`
- total duration: `not finished in metrics file at patch time`
- internal step duration:
  - `phase0-baseline`: `39m 14s`
  - `phase0-android-validation`: `5m 31s`
  - `phase0-ios-validation`: `4m 5s`
- token consumption: `not recorded`
- validation completed in the round:
  - `./scripts/build_tdlib_phase0.sh android` passed and produced `/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so`
  - `file /Users/user/Desktop/project/TelegramAIDev/apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` confirmed `ELF 64-bit ... ARM aarch64`
  - `./build.sh debug android autorun` passed
  - `./gradlew assembleDebug -x app:buildCangjieResourcesDebug` passed
  - `adb -s 3d62be73 install -r .../app-debug.apk` passed
  - `adb -s 3d62be73 shell run-as com.example.cjmp cat files/telegram_ui_smoke_status.txt` returned `passed`
  - `./scripts/build_tdlib_phase0.sh ios-sim` passed and produced `/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/build/tdlib-phase0/ios-sim/libtdjson.dylib`
  - `file /Users/user/Desktop/project/TelegramAIDev/apps/cjmp/build/tdlib-phase0/ios-sim/libtdjson.dylib` confirmed `Mach-O 64-bit dynamically linked shared library arm64`
  - `./build.sh debug ios-sim autorun` passed after fixing two repo-local compile conflicts and copied `libtdjson.dylib` into `/Users/user/Desktop/project/TelegramAIDev/apps/cjmp/ios/frameworks`
  - `xcodebuild test -project /Users/user/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj -scheme cjmp -destination 'platform=iOS Simulator,id=16017B09-D686-4207-A624-9CA58C899EE7' -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` passed
- parity impact / delivery status / notable workaround:
  - Android and iOS now both have evidence-backed phase-0 native feasibility for `tdjson`
  - HOS remains a gate rather than a peer delivery path because the repo still lacks a matching HOS native bridge and runtime evidence
  - notable workaround: Android runtime feasibility was proven through the existing app autorun smoke result file because the legacy instrumentation dependency chain still points at `jcenter.bintray.com`
- AI-efficiency friction summary:
  - confirmed repo/tooling friction: Android instrumentation currently fails before app execution because `com.android.support.test:runner:1.0.2` pulls `junit:4.12` from `jcenter.bintray.com`, which now fails TLS handshake in this environment
  - no new CJMP framework-level blocker was found for Android/iOS `tdjson` native feasibility itself; the main remaining risk is HOS bridge absence rather than Android/iOS platform inability

## 2026-04-28 Round J

- timestamp: `2026-04-28T12:22:04Z` to `2026-04-28T12:29:45Z`
- framework lane: `CJMP`
- work item type and issue reference: `bug-fix`, `autorun-smoke-ios-fix`
- concise working effort summary:
  - changed [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/cjpm.toml](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/cjpm.toml) so every target now defaults to `--cfg ui_test=off`, making non-`autorun` builds produce the product code path by default
  - tightened [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/build.sh](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/build.sh) so `uiTestMode` is explicit: only `autorun` flips the smoke build on, anything else now errors instead of silently compiling the wrong mode
  - stabilized [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_page.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_page.cj) by top-aligning the smoke tools surface, promoting the `Open home shell preview`, `Open Alex chat detail preview`, and `Run smoke check` controls, and hiding manual-only buttons during `autorun` builds so the real-device smoke suite can reliably find `slice5_smoke_open_chat_detail_alex`
- total duration: `7m 41s`
- internal step duration:
  - `investigation`: `1m 47s`
  - `implementation`: `2m 13s`
  - `verification`: `1m 33s`
- token consumption: `total=4757873, input=4745847, cached_input=4394368, output=12026, reasoning_output=6294`
- validation completed in the round:
  - `./build.sh debug android` passed as the product build path
  - `./build.sh debug android autorun` passed as the Android smoke build path
  - `./build.sh debug ios` passed as the product build path
  - `./build.sh debug ios autorun` passed as the iOS smoke build path
  - `xcodebuild test -project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj -scheme cjmp -destination 'id=00008140-000408510A02801C' -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` passed on real device `Cen的iPhone`
  - exported `/tmp/cjmp-ui-test-20260428T122654Z.xcresult` attachments confirm the terminal state screenshot shows `Smoke suite passed`
- parity impact / delivery status / notable workaround:
  - `CJMP` now has a clean split between product and smoke builds without requiring manual file edits before switching platforms
  - the iOS smoke harness is again real-device-stable for the slice6 chat-detail path
  - notable workaround: the smoke tools page had been vertically centered with too many controls, which let the required Alex detail trigger fall out of the real-device visible/testable area
- AI-efficiency friction summary:
  - no confirmed new `CJMP` framework/tooling friction in this round; the failures were caused by repo-local build configuration drift and a repo-local smoke harness layout assumption

## 2026-03-26 Round A

- timestamp: `2026-03-26T08:26:46Z` to `2026-03-26T08:55:17Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `slice1-app-shell-startup-routing`
- concise working effort summary:
  - implemented slice1 startup routing states in `/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj` (`login`, `startup-failure`, `authenticated-placeholder`)
  - copied canonical shared assets into `/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/assets/telegram-commercial-mvp/`
  - fixed route dispatch from incorrect `match`-pattern usage to explicit `if/else` equality checks
- total duration: `28m 31s`
- internal step duration:
  - `implementation`: `6m 11s`
  - `build-validation`: `0s`
- token consumption: `total=7941487, input=7926157, cached_input=6447616, output=15330, reasoning_output=7300`
- validation completed in the round:
  - `keels build hap --debug` passed
  - `keels build apk --debug` passed after local environment fix
- parity impact / delivery status / notable workaround:
  - `CJMP` slice1 implementation delivered for startup routing baseline
  - notable workaround: removed `com.apple.quarantine` from `/Users/dzy/codes/cjmp-sdk-mac-arm64-0.2.1-release/cjmp-ui/android/macro/ohos/` to allow macro dylib loading on macOS
- AI-efficiency friction summary:
  - confirmed local tooling friction: macOS quarantine blocked `CJMP` macro dylib loading for Android APK path until manual xattr cleanup

## 2026-03-26 Round B

- timestamp: `2026-03-26T08:55:31Z` to `2026-03-26T08:56:04Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `slice1-acceptance-validation`
- concise acceptance summary:
  - runtime acceptance executed on Android device serial `3d62be73` after installing current debug build
  - first launch after `pm clear` lands on login with `Continue` CTA
  - startup failure state is reachable and can recover to login
  - authenticated handoff route lands on explicit placeholder and does not present home shell/chat list
- acceptance outcome: `passed (slice #1 contract)`
- total duration: `33s`
- internal step duration:
  - `runtime-validation`: `0s`
  - `evidence-capture`: `0s`
- token consumption: `total=388014, input=387609, cached_input=383104, output=405, reasoning_output=120`
- evidence captured:
  - `/Users/dzy/Desktop/project/TelegramAIDev/.cache/android-acceptance/slice1-first-launch-after-clear.png`
  - `/Users/dzy/Desktop/project/TelegramAIDev/.cache/android-acceptance/slice1-failure-screen.png`
  - `/Users/dzy/Desktop/project/TelegramAIDev/.cache/android-acceptance/slice1-after-continue-to-placeholder.png`
- parity impact / notable workaround:
  - slice1 acceptance is now runtime-verified for `CJMP`
- AI-efficiency friction summary:
  - no confirmed AI-efficiency friction in this acceptance round

## 2026-03-29 Round C

- timestamp: `2026-03-29T04:50:01Z` to `2026-03-29T04:53:39Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `telegram-commercial-mvp-slice2`
- concise working effort summary:
  - upgraded `/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj` from slice1 direct handoff to a slice2 two-step demo login (`phone-entry` -> `verification`)
  - added `TextInput`-based phone and verification inputs, continue/verify CTAs, inline validation and failure feedback, and success handoff to the existing authenticated placeholder
  - kept startup failure fallback route and ensured authenticated destination remains an explicit placeholder, not home shell/chat list
- total duration: `3m 38s`
- internal step duration:
  - `implementation`: `2m 37s`
  - `validation`: `25s`
- token consumption: `total=1179944, input=1173318, cached_input=1036928, output=6626, reasoning_output=3416`
- validation completed in the round:
  - `keels build apk --debug` passed
  - `keels build hap --debug` passed
  - `keels devices` reports `0` connected devices, so runtime acceptance was not executed in this round
- parity impact / delivery status / notable workaround:
  - `CJMP` slice2 demo login flow is implemented and compile-validated
  - runtime acceptance remains pending until an Android device/emulator is connected
- AI-efficiency friction summary:
  - no confirmed CJMP framework/tooling friction in this round; runtime validation was blocked only by missing connected device

## 2026-04-01 Round D

- timestamp: `2026-04-01T02:40:45Z` to `2026-04-01T02:47:21Z`
- framework lane: `CJMP`
- work item type and issue reference: `bug-fix`, `ui-test-smoke-businessexception`
- concise working effort summary:
  - replaced the in-app `Run smoke check` action in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj) with a safe embedded selector-contract check instead of directly invoking `ohos.ui_test` driver assertions
  - added shared selector constants in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj) so the UI page, component `.id(...)` bindings, and external smoke case stay aligned
  - kept the external iOS smoke case in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj) for real automation-harness assertions
- total duration: `6m 36s`
- internal step duration:
  - `investigation`: `12s`
  - `implementation`: `1m 0s`
  - `verification`: `57s`
  - `reporting`: `51s`
- token consumption: `total=1409448, input=1396039, cached_input=1347840, output=13409, reasoning_output=5796`
- validation completed in the round:
  - `keels build ios-sim --platform ios-sim-arm64 --debug` passed
- parity impact / delivery status / notable workaround:
  - the CJMP demo app no longer throws `BusinessException 17000003` from the UI test page button path when the user taps `Run smoke check`
  - the UI test page now honestly reports an embedded selector contract, while driver-backed assertions remain available only to external UI automation
- AI-efficiency friction summary:
  - confirmed CJMP friction: `ohos.ui_test` driver assertions can be compiled into the app target, but invoking them from the app process fails at runtime with `BusinessException 17000003 Assertion failed` instead of surfacing a clearer contract or earlier guard
  - durable evidence recorded in [/Users/dzy/Desktop/project/TelegramAIDev/reports/cjmp-issues/2026-04-01-ios-ui-test-driver-runtime-assertion.md](/Users/dzy/Desktop/project/TelegramAIDev/reports/cjmp-issues/2026-04-01-ios-ui-test-driver-runtime-assertion.md)

## 2026-04-01 Round E

- timestamp: `2026-04-01T03:01:08Z` to `2026-04-01T03:17:44Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `ui-test-framework-conversion`
- concise working effort summary:
  - converted the `UI Test` page in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj) from an embedded selector-only fallback into a real smoke-suite trigger that runs `UITestSmokeSuite().asTestSuite().runTests()`
  - split the smoke-suite launcher from the controls under test, keeping the embedded login target addressable through shared selector constants in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj)
  - rewrote [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj) into a real `@Test` suite and replaced unsupported `waitForComponent(...)` calls with current SDK-compatible `delayMs(...) + assertComponentExist(...) + findComponent(...)` checks
  - added a shared iOS launch scheme at [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme) so iOS has the documented AbilityDelegator launch arguments alongside the already-wired Android host activity
- total duration: `16m 36s`
- internal step duration:
  - `investigation`: `7m 14s`
  - `implementation`: `2m 5s`
  - `reporting`: `23s`
- token consumption: `total=6474303, input=6435304, cached_input=5890048, output=38999, reasoning_output=22091`
- validation completed in the round:
  - `keels build ios-sim --platform ios-sim-arm64 --debug` passed
  - `keels build apk --platform android-arm64 --debug` passed
- parity impact / delivery status / notable workaround:
  - the CJMP demo now wires `Run smoke check` to real unittest/UI-test execution instead of only showing an in-page status message
  - the UI smoke path now validates the embedded login flow and route handoff selectors through the actual `ohos.ui_test` driver when the app is launched with AbilityDelegator-enabled arguments
  - runtime acceptance is still pending on a simulator/device launched through the delegator-enabled path; without that launch contract the suite is expected to fail and the page now tells the user that explicitly
  - notable workaround: the documentation advertises `waitForComponent(...)`, but the current SDK surface used by this app target did not expose it during `ios-sim` compilation, so the suite had to be adapted to supported APIs
- AI-efficiency friction summary:
  - confirmed CJMP friction: the documented `ohos.ui_test` API surface and the currently consumable app-target binding are not fully aligned, which forced a code-level workaround during delivery
  - confirmed CJMP friction: driver-backed UI tests still depend on non-obvious delegator launch wiring outside normal in-app button flows, so the product surface must explain that contract instead of assuming direct invocation will work

## 2026-04-01 Round F

- timestamp: `2026-04-01T07:32:14Z` to `2026-04-01T07:33:54Z`
- framework lane: `CJMP`
- work item type and issue reference: `bug-fix`, `ios-ui-test-exclusive-scope`
- concise working effort summary:
  - removed the `exclusiveScope { ... }` wrapper from the real `Run smoke check` button path in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj) so the spawned task now proceeds directly to `runUITestSmokeSuiteSummary()`
  - preserved the current diagnostic logs and the real `runUITestSmokeSuiteSummary()` to `UITestSmokeSuite().asTestSuite().runTests()` call chain for the in-app smoke trigger
- total duration: `1m 40s`
- internal step duration:
  - `patch`: `11s`
  - `build`: `27s`
- token consumption: `total=418858, input=415354, cached_input=400768, output=3504, reasoning_output=694`
- validation completed in the round:
  - `keels build ios-sim --platform ios-sim-arm64 --debug` passed
- parity impact / delivery status / notable workaround:
  - the latest iOS runtime logs had stopped after `runUITestSmokeCheck: inside spawn before exclusiveScope`; this round removes that boundary so the next simulator run can confirm whether `exclusiveScope` itself was the blocker
  - the in-app smoke button still exercises the real UI-test suite path instead of any embedded fallback or mock selector check
- AI-efficiency friction summary:
  - current evidence points to a non-obvious iOS runtime/concurrency problem around entering `exclusiveScope` from the spawned app-target task, which is harder to diagnose than a direct `Driver.create()` or `runTests()` failure because no framework exception was surfaced before the body executed

## 2026-04-01 Round G

- timestamp: `2026-04-01T07:57:32Z` to `2026-04-01T07:59:00Z`
- framework lane: `CJMP`
- work item type and issue reference: `bug-fix`, `ui-test-success-expectations`
- concise working effort summary:
  - read the local CJMP test framework guide at [/Users/dzy/Desktop/CJMP/docs/zh-cn/app-dev/quick-start/test-framework.md](/Users/dzy/Desktop/CJMP/docs/zh-cn/app-dev/quick-start/test-framework.md) and aligned the smoke case with the documented `@Expect(actual, expected)` style
  - added two explicit success-state assertions in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj) so the real UI smoke test now verifies the authenticated placeholder text after login handoff and verifies that the `Run smoke check` button is clickable after returning to the UI test page
- total duration: `1m 28s`
- internal step duration:
  - `implementation`: `25s`
- token consumption: `total=455264, input=452590, cached_input=438400, output=2674, reasoning_output=1152`
- validation completed in the round:
  - `keels build ios-sim --platform ios-sim-arm64 --debug` passed
- parity impact / delivery status / notable workaround:
  - the in-app smoke case no longer treats “ran to the end without throwing” as the only success signal; it now requires both route transition correctness and return-path interactivity correctness
- AI-efficiency friction summary:
  - the CJMP test framework guide documents the necessary `@Expect` forms, but without adding these explicit checks the app-side smoke case could appear to have executed while still lacking any positive success criteria

## 2026-04-01 Round H

- timestamp: `2026-04-01T08:27:02Z` to `2026-04-01T08:38:07Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `xcode-ui-test-target`
- concise working effort summary:
  - added a new Xcode UI test bundle target to [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/project.pbxproj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/project.pbxproj) and wired it into the shared [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme)
  - added a minimal external XCTest UI flow in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmpUITests/cjmpUITests.swift](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmpUITests/cjmpUITests.swift) that launches `com.example.cjmp` with the required delegator arguments, tries to open the UI test page, taps `Run smoke check`, and waits for a smoke-result status
- total duration: `11m 5s`
- internal step duration:
  - `implementation`: `48s`
- validation completed in the round:
  - `keels build ios-sim --platform ios-sim-arm64 --debug` passed
  - `xcodebuild test -project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj -scheme cjmp -destination 'platform=iOS Simulator,id=59A2A8FF-64EA-4BCB-8060-8E6AF27EF2AB' -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` launched the app and test runner successfully, but the test failed waiting for the first `Open UI test page` button lookup
- parity impact / delivery status / notable workaround:
  - the repo now has a real external Xcode UI automation entry point for the iOS simulator instead of relying only on in-app smoke triggers
  - the external UI test path currently stops at XCTest element discovery, not at simulator launch or test-runner setup
  - the simulator frameworks had to be refreshed with `keels build ios-sim` before `xcodebuild test` could link the app against `IOSSIMULATOR` dylibs
- AI-efficiency friction summary:
  - confirmed CJMP friction: even after the Xcode UI test layer is in place and can launch the app, the current iOS surface does not yet expose the expected button as an XCTest-discoverable element, so external auto-click still needs an accessibility-bridging solution or a coordinate-based fallback

## 2026-04-02 Round I

- timestamp: `2026-04-02T06:34:09Z` to `2026-04-02T06:52:47Z`
- framework lane: `CJMP`
- work item type and issue reference: `requirement`, `telegram-commercial-mvp-slice1`
- concise working effort summary:
  - ran the slice1 self-check against `docs/cjmp-codex-delivery-setup.md` and confirmed that `keels doctor -v` passes, but the current Codex MCP config still lacks Context7 access and the shell does not expose `CJMP_SDK_HOME`, `cjpm`, `cjc`, or `cjfmt`
  - recreated `apps/cjmp` from the Keels app template, restored [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/.agents/guidelines.md](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/.agents/guidelines.md), and synced the shared Telegram assets into [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/assets/telegram-commercial-mvp/](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/assets/telegram-commercial-mvp/)
  - replaced [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/index.cj) with a slice1-only startup routing shell (`login`, `startup-failure`, `authenticated-placeholder`) plus a dedicated in-app smoke page
  - added shared smoke selectors in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_selectors.cj), a real `ohos.ui_test` suite in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj), and the required Xcode UI test shell in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmpUITests/cjmpUITests.swift](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmpUITests/cjmpUITests.swift)
  - wired the shared iOS scheme and test target by restoring [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/xcshareddata/xcschemes/cjmp.xcscheme) and the compatible [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/project.pbxproj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj/project.pbxproj)
- total duration: `18m 38s`
- internal step duration:
  - `project-create`: `2m 39s`
  - `implementation`: `6m 56s`
  - `reporting`: `27s`
- token consumption: `total=3920418, input=3881022, cached_input=3532288, output=39396, reasoning_output=21934`
- validation completed in the round:
  - `keels doctor -v` passed
  - `keels build ios --platform ios-arm64 --debug` passed in `/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp`
  - `.agents/skills/cjmp-ui-test/scripts/check_ios_destination.sh --project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj --scheme cjmp` found the real device `00008140-000408510A02801C` (`Cen的iPhone`)
  - `.agents/skills/cjmp-ui-test/scripts/run_xcode_ui_test.sh --project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj --scheme cjmp --device-id 00008140-000408510A02801C --only-testing cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` passed on the connected iPhone
  - the exported final screenshot at `/tmp/xcresult-attachments-20260402T065041Z/0DBBA212-18AB-449C-AFB6-BA2CFF7AB778.png` shows `Smoke suite passed. caseCount: 1, passedCount: 1, failedCount: 0, errorCount: 0, skippedCount: 0`
  - `keels build ios-sim --platform ios-sim-arm64 --debug` failed during dependency resolution because the template pointed to a missing simulator `cjmp-libs` directory
- parity impact / delivery status / notable workaround:
  - `CJMP` slice1 app shell and startup routing are re-established in `apps/cjmp` and now have real-device iOS smoke evidence rather than only compile proof
  - notable workaround: the outer XCTest shell still needed normalized-coordinate fallback because the CJMP-rendered buttons did not surface as discoverable `XCUIElementTypeButton` nodes by label on this real-device run
- AI-efficiency friction summary:
  - confirmed CJMP tooling friction: the current `keels` app template and installed SDK disagree on the iOS simulator `cjmp-libs` path, which blocks `ios-sim` builds and removes simulator acceptance as a reliable fallback in this lane
  - durable evidence recorded in [/Users/dzy/Desktop/project/TelegramAIDev/reports/cjmp-issues/2026-04-02-ios-sim-template-path-mismatch.md](/Users/dzy/Desktop/project/TelegramAIDev/reports/cjmp-issues/2026-04-02-ios-sim-template-path-mismatch.md)

## 2026-04-13 Round J

- timestamp: `2026-04-13T09:02:36Z` to `2026-04-13T09:25:35Z`
- framework lane: `CJMP`
- work item type and issue reference: `bug-fix`, `contacts-settings-surface-polish`
- concise working effort summary:
  - updated [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj) so the `Contacts` quick actions no longer render avatar-like leading markers and now sit as left-aligned text rows
  - implemented local `Contacts` filtering in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj) using the existing in-memory contact data, hid quick actions while search is active, and added an empty-result state instead of keeping the previous no-op input field
  - simplified the `Settings` grouped sections in [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/home_shell_page.cj) by removing avatar placeholders from `Account` and `Preferences` rows and deleting the redundant bottom `Session` section
  - updated [/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj](/Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/lib/ui_test_smoke_case.cj) so the smoke suite now proves the `Contacts` search is real by asserting that query `Sa` filters `Alex Mason` out while preserving `Sara Kim`
- total duration: `22m 59s`
- internal step duration:
  - `implementation`: `16m 50s`
  - `verification`: `5m 16s`
- token consumption: `total=3404777, input=3383429, cached_input=2842112, output=21348, reasoning_output=7019`
- validation completed in the round:
  - `/Users/dzy/.codex/skills/cjmp-ui-test/scripts/check_ios_destination.sh --project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj --scheme cjmp` found the connected real device `00008140-000408510A02801C` (`Cen的iPhone`)
  - `/Users/dzy/.codex/skills/cjmp-ui-test/scripts/run_xcode_ui_test.sh --project /Users/dzy/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj --scheme cjmp --device-id 00008140-000408510A02801C --only-testing cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` passed on the connected iPhone
  - the exported terminal screenshot at `/tmp/xcresult-attachments-20260413T092418Z/FDE9083B-ED39-4B06-932E-E09AA580209E.png` shows `Smoke suite passed`
- parity impact / delivery status / notable workaround:
  - the `CJMP` `Contacts` surface now behaves like a real local search over the seeded contact list and no longer carries placeholder icon chrome in quick actions
  - the `CJMP` `Settings` grouped rows are closer to the intended Telegram-like text-first navigation pattern and no longer spend horizontal space on decorative avatar markers
  - notable workaround: search still operates only on the local seeded contact set in the current `CJMP` lane; no cross-device sync or native contacts integration was introduced in this round
- AI-efficiency friction summary:
  - no confirmed AI-efficiency friction in this round
