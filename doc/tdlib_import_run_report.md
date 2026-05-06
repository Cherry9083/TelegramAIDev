# TDLib Import Run Report

## 1. 任务摘要
- Task: 在 `CJMP` 工程中执行 `TDLib` 导入、阶段 0 feasibility spike、iOS 集成修复、构建缓存优化与相关问题留痕整合。
- Goal:
  - 形成一份统一的 `TDLib` 导入运行报告，覆盖 Android / iOS / HOS 三端阶段 0 结果。
  - 整合编译修复、iOS UI 测试问题、iOS `tdjson` 集成修复、TDLib 构建缓存优化等过程记录。
  - 保留真实有效的构建、运行、测试与问题证据。
- Constraints:
  - 不扩大到阶段 2 真实 Telegram 授权流程。
  - 保持现有 `CJMP` 主流程与 smoke 骨架不被大范围重构。
  - 对已经被后续修复覆盖的旧判断，只保留最终有效结论。

## 2. 产出文档
- Unified run report: `doc/tdlib_import_run_report.md`

## 3. 基线理解
- `apps/cjmp` 已具备登录壳、home shell、chat detail、local send、smoke 页面与 Android/iOS 原生桥。
- 当前核心缺口不在 UI，而在真实 Telegram native bridge 与真实后端状态层。
- 阶段 0 的正确粒度是先验证 `tdjson` 能否在 Android/iOS 被构建、带包、加载并返回确定结果，而不是先做真实登录。
- HOS 当前只有基础工程壳，没有与 Android/iOS 对等的 `TDLib` bridge 或运行证据。

## 4. 查询审计轨迹
| 步骤 | 阶段 | 分类 | 工具类型 | 工具名 | 目的 | 查询内容 | 来源 | 关键结论 | 是否用于实现 | 关联文件 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | baseline | local-doc-reading | local-doc | `sed` | 确认阶段 0 验收边界 | 读取 `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md` 阶段 0 章节 | 本地文档 | Android/iOS 阶段 0 重点是最小 `create/send/receive`；HOS 需要单独 feasibility gate | 是 | `docs/requirements/telegram-commercial-cjmp-tdlib-integration-plan.md` |
| 2 | baseline | local-code-reading | local-code | `sed` / `rg` | 确认现有桥接与 smoke 骨架 | 读取 Android JNI、iOS Objective-C FFI、`ui_test_page.cj`、`ui_test_smoke_case.cj` | 本地代码 | 现有 Android/iOS 平台桥和 smoke suite 足以承接最小 `tdjson` probe | 是 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m`, `apps/cjmp/lib/ui_test_page.cj`, `apps/cjmp/lib/ui_test_smoke_case.cj` |
| 3 | baseline | local-code-reading | local-code | `find` / `ls` | 检查第三方源码与 HOS 结构 | 检查 `third_party/td` 与 `apps/cjmp/hos` | 本地代码 | 仓库已带 `TDLib` 源码；HOS 缺少等量 native bridge | 是 | `third_party/td`, `apps/cjmp/hos` |
| 4 | research | platform-bridge | context7 | `resolve-library-id` + `query-docs` | 确认 `TDLib tdjson` 官方用法 | 查询 create/send/receive/execute/destroy 接口与异步模型 | Context7 `/websites/core_telegram_tdlib` | `tdjson` 是官方推荐的跨语言路径，`receive` 应顺序处理 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh`, `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` |
| 5 | research | platform-bridge | context7 | `resolve-library-id` + `query-docs` | 判断 OpenHarmony native 能力 | 查询 OpenHarmony shared library / N-API / native 集成 | Context7 `/openharmony/docs` | OpenHarmony 不是“完全不能做 native”，但当前仓库没有等量落地证据 | 是 | `doc/tdlib_import_run_report.md` |
| 6 | research | build | local-doc | `sed` / `curl` | 核对 TDLib 官方 Android/iOS 构建脚本 | 读取 `third_party/td/example/android/*.sh`、`example/ios/README.md`、`CMake/iOS.cmake` | 本地第三方源码 | 本次可裁剪为 Android arm64、iOS device arm64、iOS simulator arm64 三个最小目标 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 7 | research | build | local-env | `env` / `which` / `brew` | 核对本机构建工具链 | 检查 `CJMP_SDK_HOME`、`ANDROID_SDK_ROOT`、`xcodebuild`、`cmake`、`ninja`、`php`、`cjpm` | 本地环境 | `cmake/ninja/php` 初始缺失，后续补齐；Android SDK / Xcode / CJMP 工具链均存在 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 8 | implementation | decision | manual-analysis | 手工分析 | 选择最小接入方式 | 比较显式链接与 `dlopen/dlsym` probe | 本地分析 | 选择 `dlopen/dlsym`，最小化对现有 Android/JNI 与 iOS/Xcode 工程的侵入 | 是 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` |
| 9 | implementation | build | local-build | `./scripts/build_tdlib_phase0.sh android` | 构建 Android `tdjson` | Android arm64 OpenSSL + TDLib 构建 | 本地构建 | 首次失败点为 OpenSSL 未识别；补充显式 `OPENSSL_*` 变量后成功生成 `libtdjson.so` | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 10 | implementation | build | local-build | `./scripts/build_tdlib_phase0.sh ios-sim` | 构建 iOS simulator `tdjson` | iOS simulator arm64 OpenSSL + TDLib 构建 | 本地构建 | 成功生成 `libtdjson.dylib`，架构为 `Mach-O arm64` | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 11 | implementation | build | local-build | `./scripts/build_tdlib_phase0.sh ios` | 构建 iOS 真机 `tdjson` | iOS device arm64 OpenSSL + TDLib 构建 | 本地构建 | 成功生成 `build/tdlib-phase0/ios/libtdjson.dylib`，用于真机打包 | 是 | `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 12 | validation | build | local-build | `./build.sh debug android autorun` / `./gradlew assembleDebug -x app:buildCangjieResourcesDebug` | 验证 Android app 带包 | Android app 打包链路 | 本地构建 | `libtdjson.so` 成功进入 `android/app/libs/arm64-v8a`，APK 成功打包 | 是 | `apps/cjmp/build.sh` |
| 13 | validation | runtime | device | `adb install` / `adb shell am start` / `run-as` / `logcat` | 验证 Android 真机运行 | 安装、启动、检查 smoke 状态与日志 | Android 真机 | 状态文件为 `passed`，并直接看到 `TDLib phase0 probe result: phase0_ok:...` 日志 | 是 | `apps/cjmp/android/app/build/outputs/apk/debug/app-debug.apk`, `apps/cjmp/lib/ui_test_smoke_case.cj` |
| 14 | validation | issue | local-build | `./gradlew connectedDebugAndroidTest ...` | 判断 Android instrumentation 是否直通 | 运行 connected Android test | 本地构建 | 卡在 `jcenter.bintray.com` 的 `junit:4.12` TLS 握手，不是 `tdjson` 运行期问题 | 是 | `apps/cjmp/android/build.gradle` |
| 15 | validation | build | local-build | `./build.sh debug ios-sim autorun` | 验证 iOS-sim app 带包 | iOS simulator app 构建与 frameworks 拷贝 | 本地构建 | 首次暴露 repo 内编译问题：`FfiFreeString` 冲突、`UITestPage` 字段访问问题；修复后通过，且 `libtdjson.dylib` 被复制到 `ios/frameworks` | 是 | `apps/cjmp/lib/tdjson_phase0_probe.cj`, `apps/cjmp/lib/ui_test_page.cj`, `apps/cjmp/build.sh` |
| 16 | validation | runtime | simulator | `xcrun simctl bootstatus` | 验证模拟器可用于 UI smoke | 启动 `iPhone 17 Pro` 模拟器 | iOS Simulator | 模拟器成功 boot 完成 | 是 | `doc/tdlib_import_run_report.md` |
| 17 | validation | test | simulator | `xcodebuild test` | 验证 iOS-sim 运行期 smoke | 运行 `cjmpUITests` smoke | iOS Simulator | `TEST SUCCEEDED`，终态为 `Smoke suite passed` | 是 | `apps/cjmp/ios/cjmpUITests/CjmpUITests.swift` |
| 18 | validation | issue | runtime | iOS 真机日志 | 定位 iOS 真机 `dlopen` 失败 | 用户提供 `phase0_fail: dlopen ... libtdjson.dylib (no such file)` 日志 | 真机日志 | 原因是当时真机包内没有 `ios` 版 `libtdjson.dylib`；后续脚本已支持 `ios` 构建并拷贝 | 是 | `apps/cjmp/build.sh`, `apps/cjmp/scripts/build_tdlib_phase0.sh` |
| 19 | optimization | local-code-reading | local-code | `sed` / `grep` | 理解 `ios/frameworks` 动态库来源与缓存机制 | 读取 `build.sh` 与 `build_tdlib_phase0.sh` | 本地代码 | `ios/frameworks/*.dylib` 是构建时拷贝进去的 staging 目录，不是直接原地编译；TDLib 现已具备缓存检查，可复用预编译库 | 是 | `apps/cjmp/build.sh`, `apps/cjmp/scripts/build_tdlib_phase0.sh` |

## 5. 决策记录
| 步骤 | 决策 | 原因 | 影响文件 | 备注 |
|---|---|---|---|---|
| 1 | 用 `tdjson` 最小 probe，而不是直接做真实 Telegram 登录 | 阶段 0 是 feasibility gate，不是阶段 2 授权交付 | `apps/cjmp/lib/tdjson_phase0_probe.cj`, `apps/cjmp/lib/ui_test_smoke_case.cj` | 降低实现成本 |
| 2 | 用 `dlopen/dlsym`，不先做重工程链接改造 | 最小化 Android/JNI、iOS/Xcode 工程改动面 | `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` | 更适合阶段 0 |
| 3 | Android instrumentation 失败时改用 app 启动 + 状态文件 + logcat 继续验证 | instrumentation 失败点在旧依赖源，不在 app/tdjson 本身 | `doc/tdlib_import_run_report.md` | 保持验证推进 |
| 4 | 为 iOS 真机与模拟器分别构建独立的 `tdjson` 产物 | 两者架构与打包路径不同，不能混用 | `apps/cjmp/scripts/build_tdlib_phase0.sh`, `apps/cjmp/build.sh` | 修复真机 `dlopen` 缺库问题 |
| 5 | 为 TDLib 构建增加缓存检查 | 修改 `CJMP` 代码时不应反复重编第三方原生库 | `apps/cjmp/scripts/build_tdlib_phase0.sh` | 提升迭代效率 |
| 6 | 保留 `ios/frameworks` 作为 staging 目录，而不是手工长期维护目录 | `build.sh` 每次都会清空并重建该目录 | `apps/cjmp/build.sh` | 真正稳定的缓存目录是 `build/tdlib-phase0/...` |

## 6. 问题与处理
| 步骤 | 问题 | 原因 | 解决方式 | 状态 | 备注 |
|---|---|---|---|---|---|
| 1 | 初始环境缺少 `cmake` / `ninja` / `php` | TDLib 官方示例构建链依赖这些工具 | 通过 Homebrew 安装 `cmake`、`ninja`、`php` | resolved | 构建前置问题 |
| 2 | Android 首次构建找不到 OpenSSL，`tdjson` 目标未生成 | 仅传 `OPENSSL_ROOT_DIR` 不足 | 在脚本中显式传 `OPENSSL_CRYPTO_LIBRARY` / `OPENSSL_SSL_LIBRARY` / `OPENSSL_INCLUDE_DIR` | resolved | Android 产物已成功生成 |
| 3 | Android instrumentation 卡在 `jcenter.bintray.com` 的 `junit:4.12` TLS 握手 | 旧测试依赖源不可用 | 改用 app 安装启动 + `run-as` + `logcat` 继续验证阶段 0 主目标 | partially-resolved | 属于 repo/tooling 债 |
| 4 | `tdjson_phase0_probe.cj` 与 `demo_session_store.cj` 出现 `FfiFreeString` 冲突 | 重复声明 / Android 平台可见性不一致 | 删除重复声明，并将 `demo_session_store.cj` 的 `FfiFreeString` 扩展到 Android/iOS/iOS-sim | resolved | 编译修复 |
| 5 | iOS-sim `UITestPage` 非 Android 分支直接访问字段导致编译问题 | 该编译路径下字段访问方式不兼容 | 改为 `applySmokeCompletion(...)` 封装状态更新 | resolved | 编译修复 |
| 6 | iOS 真机日志显示 `dlopen ... libtdjson.dylib (no such file)` | 真机包内没有 `ios` 版 `libtdjson.dylib` | 扩展 `build_tdlib_phase0.sh` 支持 `ios` 目标，并在 `build.sh` 的 `ios` 分支拷贝 `build/tdlib-phase0/ios/libtdjson.dylib` | resolved | 真机缺库问题 |
| 7 | `libtdjson.dylib` 最初没有被 Xcode 工程管理 | 只完成了文件拷贝，未嵌入工程时易出现运行时缺失 | 添加 `add_libtdjson_to_xcode.py`，并确认 `project.pbxproj` 中已有 Frameworks / Embed Libraries 配置 | resolved | 当前工程已包含该库 |
| 8 | TDLib 每次构建都会完整重编，开发迭代过慢 | 原始脚本没有缓存检查 | 为 Android、iOS、iOS-sim 三个 TDLib 构建函数添加产物存在性检查 | resolved | 现在可复用预编译产物 |
| 9 | HOS 当前无对等 TDLib bridge 落点 | 工程中只有基础 HOS 壳，尚未接 native TDLib 依赖或 bridge | 不强行进入实现，保留为阶段 0 结论与后续 issue | open | 阶段 0 应暴露的真实风险 |

## 7. 代码改动
| 文件 | 改动原因 | 改动摘要 | 关联查询步骤 |
|---|---|---|---|
| `apps/cjmp/scripts/build_tdlib_phase0.sh` | 新增并完善 TDLib 阶段 0 构建链 | 支持 Android arm64、iOS 真机 arm64、iOS-sim arm64；补充 OpenSSL 显式传参；增加缓存检查 | 4, 6, 7, 9, 10, 11, 19 |
| `apps/cjmp/build.sh` | 让 app 构建链自动使用 TDLib 产物 | iOS 构建前自动触发 TDLib 构建；Android / iOS / iOS-sim 分别拷贝 `tdjson` 到打包 staging 目录 | 12, 15, 18, 19 |
| `apps/cjmp/android/app/src/main/cpp/cjmp.cpp`, `apps/cjmp/android/app/src/main/cpp/cjmp.h` | 新增 Android 原生 `tdjson` probe | 增加 `FfiRunTdjsonPhase0Probe()`，通过 `dlopen/dlsym` 执行 `getTextEntities` | 4, 8, 13 |
| `apps/cjmp/ios/oc_bridge/cjmp_ffi.h`, `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` | 新增 iOS 原生 `tdjson` probe | 从 app bundle `Frameworks/libtdjson.dylib` 加载并执行 `getTextEntities` | 4, 8, 17, 18 |
| `apps/cjmp/lib/tdjson_phase0_probe.cj` | 暴露跨平台 probe | 增加 `runTdjsonPhase0Probe()` 与成功前缀判定 | 8, 13 |
| `apps/cjmp/lib/demo_session_store.cj` | 统一 `FfiFreeString` 平台可见性 | 将 `FfiFreeString` 平台支持扩展到 Android / iOS / iOS-sim | 4 |
| `apps/cjmp/lib/ui_test_smoke_case.cj` | 将阶段 0 探针纳入 smoke suite | 新增 `test_phase0_tdjson_native_probe()` 并记录日志 | 2, 13 |
| `apps/cjmp/lib/ui_test_page.cj` | 修复 `ios-sim` 构建与状态更新 | 非 Android smoke 完成分支改为 `applySmokeCompletion()` | 15 |
| `apps/cjmp/ios/cjmp.xcodeproj/project.pbxproj` | 把 `libtdjson.dylib` 纳入 iOS 工程 | 增加 Frameworks / Embed Libraries 引用与搜索路径配置 | 17, 18 |
| `apps/cjmp/scripts/add_libtdjson_to_xcode.py` | 自动化维护 Xcode 配置 | 避免手动编辑 `project.pbxproj` 出错 | 17 |
| `apps/cjmp/scripts/run_ui_tests.sh` | 标准化 iOS UI 测试执行与清理 | 自动清理旧结果、杀掉卡住进程、统一 resultBundle 路径 | `ios_ui_test_issues.md` |

## 8. 验证记录
| 步骤 | 检查项 | 方法 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | Android `tdjson` 原生库能否构建 | `./scripts/build_tdlib_phase0.sh android` | 通过 | `apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` |
| 2 | Android `tdjson` 产物架构是否正确 | `file apps/cjmp/build/tdlib-phase0/android/arm64-v8a/libtdjson.so` | 通过 | `ELF 64-bit LSB shared object, ARM aarch64` |
| 3 | Android app 是否能携带 `tdjson` 打包 | `./build.sh debug android autorun` + `./gradlew assembleDebug -x app:buildCangjieResourcesDebug` | 通过 | `apps/cjmp/android/app/libs/arm64-v8a/libtdjson.so` 存在 |
| 4 | Android 真机 smoke 是否完成 | `adb install`、`adb shell am start`、`adb shell run-as com.example.cjmp cat files/telegram_ui_smoke_status.txt` | 通过 | 状态文件为 `passed` |
| 5 | Android phase0 probe 是否真的执行成功 | `adb logcat -d | rg "TDLib phase0 probe result"` | 通过 | 日志显示 `phase0_ok:{"@type":"textEntities"...}` |
| 6 | Android instrumentation 是否直接可跑 | `./gradlew connectedDebugAndroidTest ...` | 未通过 | 卡在 `jcenter.bintray.com/junit:4.12` TLS 握手 |
| 7 | iOS-sim `tdjson` 原生库能否构建 | `./scripts/build_tdlib_phase0.sh ios-sim` | 通过 | `apps/cjmp/build/tdlib-phase0/ios-sim/libtdjson.dylib` |
| 8 | iOS 真机 `tdjson` 原生库能否构建 | `./scripts/build_tdlib_phase0.sh ios` | 通过 | `apps/cjmp/build/tdlib-phase0/ios/libtdjson.dylib` |
| 9 | iOS `tdjson` 产物架构是否正确 | `file .../ios/libtdjson.dylib`、`file .../ios-sim/libtdjson.dylib` | 通过 | 均为 `Mach-O ... arm64` |
| 10 | iOS-sim app 是否能携带 `tdjson` 打包 | `./build.sh debug ios-sim autorun` | 通过 | `apps/cjmp/ios/frameworks/libtdjson.dylib` 被复制 |
| 11 | iOS simulator 是否可用于后续验收 | `xcrun simctl bootstatus "iPhone 17 Pro" -b` | 通过 | boot status `Finished` |
| 12 | iOS simulator UI smoke 是否通过 | `xcodebuild test ... -only-testing:cjmpUITests/CjmpUITests/testRunSmokeCheckFromUiTestPage` | 通过 | `** TEST SUCCEEDED **`；终态 `Smoke suite passed` |
| 13 | iOS 真机缺库问题是否已定位 | 用户提供真机日志 | 通过 | 报错明确指向 app bundle 中缺少 `Frameworks/libtdjson.dylib`，已由后续脚本修复 |
| 14 | TDLib 缓存优化是否生效 | 检查脚本是否有 `already exists, skipping build` 逻辑 | 通过 | `build_tdlib_phase0.sh` 已对 Android / iOS / iOS-sim 加入缓存检查 |
| 15 | HOS 是否已有等量实现证据 | 本地代码/工程结构检查 | 未通过 | 当前无 TDLib bridge、无产物、无运行结果 |

## 9. 最终结论
- Android：
  - `可继续`
  - `tdjson` Android arm64 动态库已成功构建、带包、真机启动并通过现有 smoke 路径。
  - `test_phase0_tdjson_native_probe` 在 Android 上有直接日志证据，返回 `phase0_ok`.
- iOS：
  - `可继续`
  - `tdjson` 已分别构建出 iOS 真机版与 iOS-sim 版动态库。
  - `build.sh debug ios-sim autorun` 已成功把 `libtdjson.dylib` 带入 `ios/frameworks`。
  - `xcodebuild test` 已在 `iPhone 17 Pro` 模拟器上通过，UI smoke 终态为 `Smoke suite passed`。
  - 真机曾出现 `dlopen ... libtdjson.dylib (no such file)`，根因是当时包内没有真机版库；当前脚本已支持 `ios` 目标并会拷贝真机版 `libtdjson.dylib`。
- HOS：
  - `高风险需额外 issue`
  - OpenHarmony 官方能力层面并非完全不支持 native C/C++，但当前仓库没有对等 `TDLib` bridge、产物或运行证据，不能与 Android/iOS 同等承诺。

## 10. 风险与人工关注点
- Android `libtdjson.so` 当前体积非常大，仍带 `debug_info`，后续进入正式交付前需要做 strip / release 优化。
- Android instrumentation 仍受旧 `jcenter` 测试依赖源阻断；如需把 `connectedDebugAndroidTest` 作为固定验收路径，必须先迁移依赖源。
- iOS 当前最强证据是 simulator UI smoke；若进入下一阶段，建议补一轮真机 `xcodebuild test` 或 app 启动验证，确认真机包内 `libtdjson.dylib` 实际加载成功。
- `ios/frameworks` 与 `android/app/libs` 都是 staging 目录，每次构建会被重建；稳定可复用的预编译 `tdjson` 产物目录是：
  - `apps/cjmp/build/tdlib-phase0/android/arm64-v8a/`
  - `apps/cjmp/build/tdlib-phase0/ios/`
  - `apps/cjmp/build/tdlib-phase0/ios-sim/`
- 修改 `CJMP` 业务/UI 代码后，通常可以直接复用这些预编译 `tdjson` 产物，不必重新编 `TDLib`；只有在修改 `TDLib` 源、OpenSSL、编译参数、目标平台/架构时才需要重编。
