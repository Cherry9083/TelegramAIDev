# Run Report

## 1. 任务摘要
- Task: 执行 `阶段 0：Android/iOS/HOS feasibility spike`。
- Goal:
  - 让 `TDLib tdjson` 在当前 `CJMP` 仓库中形成最小可复用的原生构建路径。
  - 验证 Android 与 iOS 至少能完成 `tdjson` 的最小 create/send/receive 探针链路。
  - 给 HOS 输出明确 feasibility 结论，而不是无证据承诺。
- Constraints:
  - 保持现有 `CJMP` 产品 UI 主流程不被重写。
  - 只做阶段 0 所需的最小桥接和验证，不提前扩张到真实 Telegram 登录。
  - `CJMP`/框架文档按仓库规则优先使用 Context7。

## 2. 产出文档
- Run report: `doc/run_report.md`
- Requirement / plan document: `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md`
- Round metric record: `reports/comparison/round-metrics/20260506T045423Z-cjmp-requirement-242f8e80.json`

## 3. 基线理解
- 现有 `apps/cjmp` 已完成登录壳、home shell、chat detail、local send、smoke 页面与 Android/iOS 平台桥。
- 当前缺口不在 UI，而在真实后端与原生 Telegram bridge。
- 阶段 0 最合适的验证粒度不是先做真实登录，而是先证明 `tdjson` 动态库能够在 Android/iOS 中被构建、带包、加载并返回确定结果。

## 4. 查询审计轨迹
| 步骤 | 阶段 | 分类 | 工具类型 | 工具名 | 目的 | 查询内容 | 来源 | 关键结论 | 是否用于实现 | 关联文件 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | baseline | local-doc-reading | local-doc | `sed` | 确认阶段 0 验收边界 | 读取 `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md` 阶段 0 章节 | 本地文档 | 阶段 0 交付物是 `TDLib build spike`、bridge 设计说明、`HOS feasibility` 结论；Android/iOS 验收是最小 `create/send/receive` | 是 | `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md` |
| 2 | baseline | local-code-reading | local-code | `sed` / `rg` | 确认现有原生桥接与 smoke 骨架 | 读取 `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`、`apps/cjmp/ios/oc_bridge/cjmp_ffi.*`、`apps/cjmp/lib/ui_test_page.cj`、`apps/cjmp/lib/ui_test_smoke_case.cj` | 本地代码 | Android 已有 JNI + native runner；iOS 已有 Objective-C FFI；现有 smoke suite 可承接一个最小 native probe | 是 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m`, `apps/cjmp/lib/ui_test_page.cj`, `apps/cjmp/lib/ui_test_smoke_case.cj` |
| 3 | baseline | local-code-reading | local-code | `find` / `ls` | 判断仓库内是否已有 TDLib 源和 HOS 工程结构 | 检查 `third_party/td`、`apps/cjmp/hos` | 本地代码 | 仓库已内置 `third_party/td` 源码；HOS 只有基础 app 壳，没有与 Android/iOS 对等的 native TDLib bridge | 是 | `third_party/td`, `apps/cjmp/hos` |
| 4 | research | platform-bridge | context7 | `resolve-library-id` + `query-docs` | 获取 TDLib 当前官方接口说明 | 查询 `TDLib` 的 `tdjson` C/JSON interface、create/send/receive/destroy 模式 | Context7 `/websites/core_telegram_tdlib` | 官方确认 `td_json_client_create/send/receive/execute/destroy` 为推荐跨语言路径，`receive` 应由单线程顺序处理 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh`, `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` |
| 5 | research | platform-bridge | context7 | `resolve-library-id` + `query-docs` | 判断 HOS/OpenHarmony native 能力 | 查询 OpenHarmony 原生 C/C++ shared library 与 app-side 集成方式 | Context7 `/openharmony/docs` | OpenHarmony app 侧存在 native C/C++ shared library / N-API 集成路径，因此“HOS 完全无 native 能力”不成立，但当前仓库仍缺少实际 bridge 落点 | 是 | `doc/run_report.md` |
| 6 | research | build | local-doc | `curl` / `sed` | 核对 TDLib 官方 Android/iOS 示例构建脚本 | 读取 `third_party/td/example/android/*.sh`、`third_party/td/example/ios/README.md`、`CMake/iOS.cmake` | 本地第三方源码 | Android 官方脚本依赖 OpenSSL 与 NDK；iOS 官方路径依赖 OpenSSL 与 `CMake/iOS.cmake`；本次可裁剪到 Android arm64 与 iOS simulator arm64 两个最小目标 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 7 | research | build | local-env | `env` / `which` / `brew` | 核实现有本机构建条件 | 检查 `CJMP_SDK_HOME`、`ANDROID_SDK_ROOT`、`xcodebuild`、`cmake`、`ninja`、`php`、`cjpm` | 本地环境 | `CJMP`、Android SDK、Xcode 存在；`cmake/ninja/php` 初始缺失，后续通过 Homebrew 安装补齐 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 8 | implementation | decision | manual-analysis | 手工分析 | 决定最小接入方式 | 比较“静态链接改工程”与“动态库 `dlopen/dlsym` probe” | 本地分析 | 选择 `dlopen/dlsym`，因为它能最小化对现有 Android/JNI 与 iOS/Xcode 配置的侵入 | 是 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` |
| 9 | implementation | build | local-build | `./scripts/build_tdlib_phase0.sh android` | 构建 Android 阶段 0 产物 | Android arm64 OpenSSL + TDLib 构建 | 本地构建 | 首次失败点是 CMake 未识别 OpenSSL；补充 `OPENSSL_CRYPTO_LIBRARY`/`OPENSSL_SSL_LIBRARY`/`OPENSSL_INCLUDE_DIR` 后成功生成 `libtdjson.so` | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 10 | implementation | build | local-build | `./scripts/build_tdlib_phase0.sh ios-sim` | 构建 iOS simulator 阶段 0 产物 | iOS simulator arm64 OpenSSL + TDLib 构建 | 本地构建 | 成功生成 `libtdjson.dylib`，`file` 结果为 `Mach-O 64-bit dynamically linked shared library arm64` | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 11 | validation | build | local-build | `./build.sh debug android autorun` / `./gradlew assembleDebug -x app:buildCangjieResourcesDebug` | 验证 Android app 级带包 | Android app 打包链路 | 本地构建 | `libtdjson.so` 成功复制到 `apps/cjmp/android/app/libs/arm64-v8a`，APK 成功打包 | 是 | `apps/cjmp/build.sh` |
| 12 | validation | runtime | device | `adb install` / `adb shell am start` / `run-as` | 验证 Android 真机 autorun 结果 | 安装 APK 到设备 `3d62be73`，启动 app，读取 `telegram_ui_smoke_status.txt` | Android 真机 | 应用成功安装、启动；`run-as com.example.cjmp cat files/telegram_ui_smoke_status.txt` 返回 `passed` | 是 | `apps/cjmp/android/app/build/outputs/apk/debug/app-debug.apk` |
| 13 | validation | issue | local-build | `./gradlew connectedDebugAndroidTest ...` | 判断 Android instrumentation 是否也能直接跑通 | 运行 `connectedDebugAndroidTest` | 本地构建 | instrumentation 未进入 app 逻辑，卡在旧 `jcenter.bintray.com` 上的 `junit:4.12` TLS 握手失败；这是测试依赖源问题，不是 `tdjson` 接入问题 | 是 | `apps/cjmp/android/build.gradle`, `doc/run_report.md` |
| 14 | validation | build | local-build | `./build.sh debug ios-sim autorun` | 验证 iOS app 级带包 | iOS simulator app 构建与 frameworks 拷贝 | 本地构建 | 首次暴露了 repo 内已有的 `ios-sim` 编译问题：`FfiFreeString` 重复声明与 `UITestPage` 非 Android 分支直接字段访问；修复后，`libtdjson.dylib` 成功复制到 `apps/cjmp/ios/frameworks` 且 `build.sh` 通过 | 是 | `apps/cjmp/lib/tdjson_phase0_probe.cj`, `apps/cjmp/lib/ui_test_page.cj`, `apps/cjmp/build.sh` |
| 15 | validation | runtime | simulator | `xcrun simctl bootstatus` | 验证 iOS simulator 可用于后续阶段 | 启动 `iPhone 17 Pro` simulator | iOS Simulator | 模拟器成功 boot 完成，可承接后续 UI 测试 | 是 | `doc/run_report.md` |
| 16 | validation | test | simulator | `xcodebuild test` | 验证 iOS simulator 运行期 smoke | 运行 `xcodebuild test -project /Users/user/Desktop/project/TelegramAIDev/apps/cjmp/ios/cjmp.xcodeproj -scheme cjmp -destination 'platform=iOS Simulator,id=16017B09-D686-4207-A624-9CA58C899EE7' -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` | iOS Simulator | `TEST SUCCEEDED`；UI test attachment 终态显示 `Smoke suite passed` | 是 | `apps/cjmp/ios/cjmpUITests/CjmpUITests.swift` |

## 5. 决策记录
| 步骤 | 决策 | 原因 | 影响文件 | 备注 |
|---|---|---|---|---|
| 1 | 用 `tdjson` 最小 probe，而不是直接做真实 Telegram 登录 | 阶段 0 目标是 feasibility gate，不是阶段 2 授权交付 | `apps/cjmp/lib/tdjson_phase0_probe.cj`, `apps/cjmp/lib/ui_test_smoke_case.cj` | 降低实现成本并更快暴露真实 blocker |
| 2 | 用 `dlopen/dlsym` 接库，而不是先改静态/显式链接工程 | 能最小化 Android JNI、iOS Xcode 工程改动面 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` | 更适合阶段 0 |
| 3 | Android 先做到真机构建与 autorun smoke，instrumentation 失败时改用手动启动 + 设备状态文件证据 | instrumentation 失败原因为旧依赖源 TLS 握手，而不是 app/tdjson 本身 | `doc/run_report.md` | 继续推进可运行证据而不被无关问题阻断 |
| 4 | HOS 给出“可继续但高风险”的结论，而不是“已验证可交付” | OpenHarmony 官方原生能力存在，但当前仓库没有对等 bridge，也没有实际构建/运行证据 | `doc/run_report.md` | 符合阶段 0 gate 定位 |

## 6. 问题与处理
| 步骤 | 问题 | 原因 | 解决方式 | 状态 | 备注 |
|---|---|---|---|---|---|
| 1 | 初始环境缺少 `cmake` / `ninja` / `php` | TDLib 官方示例构建链依赖这些工具 | 通过 Homebrew 安装 `cmake`、`ninja`、`php` | resolved | `brew install cmake ninja php` |
| 2 | Android TDLib 首次配置找不到 OpenSSL，`tdjson` 目标未生成 | 仅传 `OPENSSL_ROOT_DIR` 对当前交叉编译路径不够 | 在阶段 0 脚本中显式传 `OPENSSL_CRYPTO_LIBRARY` / `OPENSSL_SSL_LIBRARY` / `OPENSSL_INCLUDE_DIR` | resolved | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 3 | Android instrumentation 失败在 `jcenter.bintray.com` 的 `junit:4.12` TLS 握手 | 旧测试依赖源不可用 | 改用 app 安装启动 + `run-as` 读取 `telegram_ui_smoke_status.txt` 继续验证阶段 0 主目标 | partially-resolved | 属于 repo/tooling 债，不影响本轮 native feasibility |
| 4 | iOS `build.sh debug ios-sim autorun` 首次失败 | 我新增的 `FfiFreeString` 重复声明；非 Android smoke 分支对 `page.smokeStatus/smokeDetail` 的直接写法在该编译路径下过不去 | 删除重复声明；改为 `applySmokeCompletion(...)` 封装更新 | resolved | `apps/cjmp/lib/tdjson_phase0_probe.cj`, `apps/cjmp/lib/ui_test_page.cj` |
| 5 | HOS 当前无对等 TDLib bridge 落点 | 项目中只有基础 HOS app 壳，尚未接 native TDLib 依赖或 bridge | 不强行进入实现，保留为阶段 0 结论与后续 issue | open | 这正是阶段 0 要暴露的风险 |

## 7. 代码改动
| 文件 | 改动原因 | 改动摘要 | 关联查询步骤 |
|---|---|---|---|
| `apps/cjmp/scripts/build_tdlib_phase0.sh` | 新增阶段 0 最小构建链 | 只构建 Android arm64 与 iOS simulator arm64 的 OpenSSL + TDLib `tdjson` 产物 | 4, 6, 7, 9, 10 |
| `apps/cjmp/build.sh` | 让 app 构建链能携带阶段 0 产物 | Android 拷贝 `libtdjson.so` / `libc++_shared.so`；iOS/iOS-sim 拷贝 `libtdjson.dylib` | 8, 11, 14 |
| `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/android/app/src/main/cpp/cjmp.h` | 新增 Android 原生 `tdjson` probe | 增加 `FfiRunTdjsonPhase0Probe()`，通过 `dlopen/dlsym` 执行 `getTextEntities` 探针 | 4, 8, 12 |
| `apps/cjmp/ios/oc_bridge/cjmp_ffi.h`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` | 新增 iOS 原生 `tdjson` probe | 增加 `FfiRunTdjsonPhase0Probe()`，从 app bundle 的 `Frameworks/libtdjson.dylib` 加载并执行 `getTextEntities` 探针 | 4, 8, 15, 16 |
| `apps/cjmp/lib/tdjson_phase0_probe.cj` | 把 native probe 暴露给 `CJMP` | 增加 `runTdjsonPhase0Probe()` 与成功前缀判定 | 8 |
| `apps/cjmp/lib/ui_test_smoke_case.cj` | 把阶段 0 探针纳入现有 smoke suite | 新增 `test_phase0_tdjson_native_probe()` | 2, 12 |
| `apps/cjmp/lib/ui_test_page.cj` | 修复 `ios-sim` 构建中的状态更新问题 | 非 Android smoke 完成分支改为通过 `applySmokeCompletion()` 更新状态 | 14, 16 |

## 8. 验证记录
| 步骤 | 检查项 | 方法 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | Android `tdjson` 原生库能否构建 | `./scripts/build_tdlib_phase0.sh android` | 通过 | `apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` |
| 2 | Android `tdjson` 产物架构是否正确 | `file apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` | 通过 | `ELF 64-bit LSB shared object, ARM aarch64` |
| 3 | Android app 是否能携带 `tdjson` 打包 | `./build.sh debug android autorun` + `./gradlew assembleDebug -x app:buildCangjieResourcesDebug` | 通过 | `apps/cjmp/android/app/libs/arm64-v8a/libtdjson.so` 存在；`assembleDebug` 成功 |
| 4 | Android 真机 app 启动后 smoke 是否完成 | `adb install`、`adb shell am start`、`adb shell run-as com.example.cjmp cat files/telegram_ui_smoke_status.txt` | 通过 | 状态文件为 `passed` |
| 5 | Android instrumentation 是否直接可跑 | `./gradlew connectedDebugAndroidTest ...` | 未通过 | 失败点为 `jcenter.bintray.com/junit:4.12` TLS 握手，不是 `tdjson` 运行期错误 |
| 6 | iOS simulator `tdjson` 原生库能否构建 | `./scripts/build_tdlib_phase0.sh ios-sim` | 通过 | `apps/cjmp/build/tdlib-phase0/ios-sim/libtdjson.dylib` |
| 7 | iOS simulator `tdjson` 产物架构是否正确 | `file apps/cjmp/build/tdlib-phase0/ios-sim/libtdjson.dylib` | 通过 | `Mach-O 64-bit dynamically linked shared library arm64` |
| 8 | iOS app 是否能携带 `tdjson` 打包 | `./build.sh debug ios-sim autorun` | 通过 | `apps/cjmp/ios/frameworks/libtdjson.dylib` 被成功复制 |
| 9 | iOS simulator 是否可用于后续验收 | `xcrun simctl bootstatus "iPhone 17 Pro" -b` | 通过 | boot status 终态 `Finished` |
| 10 | iOS simulator UI smoke 是否仍可通过 | `xcodebuild test ... -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` | 通过 | `** TEST SUCCEEDED **`；结果 bundle: `/Users/user/Library/Developer/Xcode/DerivedData/cjmp-cvrntgcphybzmzgdlkowpkdpdlzj/Logs/Test/Test-cjmp-2026.05.06_13-59-24-+0800.xcresult` |
| 11 | HOS 是否已有等量实现证据 | 本地代码/工程结构检查 | 未通过 | 当前无 TDLib bridge、无产物、无运行结果 |

## 9. 最终结论
- Android:
  - `可继续`。
  - 已拿到 `tdjson` Android arm64 动态库产物。
  - app 已成功带包、安装到真机并在 autorun smoke 后写出 `passed`。
  - 剩余问题主要是老 instrumentation 依赖源，不是 `tdjson` native feasibility。
- iOS:
  - `可继续`。
  - 已拿到 `tdjson` iOS simulator arm64 动态库产物。
  - `build.sh debug ios-sim autorun` 已成功把 `libtdjson.dylib` 带入 `ios/frameworks`。
  - `xcodebuild test` 已在 `iPhone 17 Pro` simulator 上通过，UI smoke attachment 终态为 `Smoke suite passed`。
- HOS:
  - `高风险需额外 issue`。
  - OpenHarmony 官方文档说明原生 C/C++ shared library 路径存在，因此不是“理论上完全不支持”。
  - 但当前仓库没有与 Android/iOS 对等的 HOS native bridge、TDLib 依赖接入或运行证据，所以还不能把 HOS 视为已验证可继续交付项。

## 10. 风险与人工关注点
- `apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` 体积非常大，当前仍带 `debug_info`，后续若进入正式交付，需要做 strip / release 优化，否则 APK 体积压力明显。
- Android instrumentation 当前卡在 `jcenter.bintray.com` 的 `junit:4.12` TLS 握手；若后续还要依赖 `connectedDebugAndroidTest` 作为固定验收路径，需先更新测试依赖源。
- iOS 本轮验证的是 simulator arm64 构建、app 级带包与 simulator UI smoke，不是 iPhone 真机运行；若进入下一阶段，建议补一轮真机 `xcodebuild test` 或 app 启动验证。
- HOS 目前只有“官方能力存在 + 仓库无实现”的结论，建议单独形成 `CJMP` issue，再决定是否继续投入 HOS 原生桥接。
