# cjmp — Telegram Client (CJMP)

基于 CJMP（Cangjie Mobile Platform）v0.6.2 的跨平台 Telegram 客户端，使用 Cangjie 语言编写，通过 TDLib 接入 Telegram，支持 Android / iOS / HarmonyOS 三端。

## 前置条件

| 依赖 | 版本要求 | 用途 |
|------|----------|------|
| CJMP SDK | v0.6.2+ | Cangjie 编译器 + Keels 框架 |
| Xcode | 16+ | iOS 构建 |
| Android SDK | 36+ / NDK 27.2 | Android 构建 |
| DevEco Studio | 6.1+ | HarmonyOS 构建 |
| JDK | 17+ | Android/HarmonyOS 构建 |
| Ruby + xcodeproj | macOS 自带 | iOS Xcode 工程写入 |
| CMake + Ninja | 3.22+ | TDLib 原生库构建 |

设置环境变量（参考 `.agents/skills/cjmp-env-setup`）：

```bash
export CJMP_SDK_HOME="<CJMP SDK 路径>"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
```

## 获取 Telegram API 凭据

应用需要 Telegram API 凭据才能连接 Telegram 服务器：

1. 访问 https://my.telegram.org → 登录你的 Telegram 账号
2. 点击 **API development tools**
3. 创建一个新应用，获取 **api_id** 和 **api_hash**
4. 准备你的 **Telegram 手机号**（含国家区号，如 `+8613800138000`）

## 配置凭据

有两种方式，二选一：

### 方式一：硬编码到测试文件（用于开发调试）

修改以下两个文件中的占位符：

**`lib/common/telegram_quick_test.cj`（第 12-14 行）：**

```cangjie
let TEST_API_ID = "你的 api_id"          // 例如 "34596433"
let TEST_API_HASH = "你的 api_hash"       // 例如 "1efe3477b86069c6635c01d79e8dfa15"
let TEST_PHONE_NUMBER = "你的手机号"       // 例如 "+8613800138000"
```

**`lib/common/telegram_real_test.cj`（第 11-13 行）：**

```cangjie
let apiId = "你的 api_id"
let apiHash = "你的 api_hash"
let phoneNumber = "你的手机号"
```

> ⚠️ **请勿将真实凭据提交到 git 仓库。** 默认占位符为 `YOUR_API_ID` / `YOUR_API_HASH` / `YOUR_PHONE`，提交时请确保保持占位符状态。

### 方式二：运行时通过应用 UI 输入（推荐）

应用启动后的登录页面提供 **API ID** 和 **API Hash** 输入框，直接在 UI 中输入即可，凭据会通过 FFI 持久化到设备本地存储。

## 构建与运行

### Android

```bash
keels build apk
# 产物：android/app/build/outputs/apk/debug/app-debug.apk
```

安装到模拟器/真机：

```bash
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

### iOS（模拟器）

```bash
keels build ios-sim
# 产物：ios/output/DerivedData/Build/Products/Debug-iphonesimulator/cjmp.app
```

### iOS（真机）

```bash
keels build ios
# 需配置 Apple 开发者签名
```

### HarmonyOS

```bash
keels build hap
# 产物：hos/entry/build/default/outputs/default/entry-default-unsigned.hap
# 需配置 HarmonyOS 签名后安装到真机
```

> HOS 构建需要完整交互式 shell 环境（`TOOL_HOME` 等变量），建议在终端中直接运行。

## 网络代理配置

Telegram 服务器在国内无法直连，需要配置代理。应用默认尝试连接本机 SOCKS5 代理：

- iOS / iOS 模拟器：`127.0.0.1:7897`
- Android 模拟器：`10.0.2.2:7897`（映射到宿主机 127.0.0.1:7897）
- HarmonyOS：系统 HTTP 代理

请确保代理软件（如 Clash）已启动并监听对应端口。

## 项目结构

```
apps/cjmp/
├── lib/                        # Cangjie 源码（C/S 源码集）
│   ├── common/                 # 跨平台通用代码
│   │   ├── index.cj            #   应用入口（EntryView，登录流程）
│   │   ├── home_shell_page.cj  #   主界面（聊天/联系人/设置）
│   │   ├── chat_detail_page.cj #   聊天详情页
│   │   ├── telegram_tdlib_facade.cj  # TDLib 状态机
│   │   ├── telegram_tdlib_bridge.cj  # TDLib FFI 桥接
│   │   ├── telegram_quick_test.cj    # ⚠️ 配置 API 凭据
│   │   └── telegram_real_test.cj     # ⚠️ 配置 API 凭据
│   ├── android/                # Android 平台特定代码
│   ├── ios/                    # iOS 平台特定代码
│   └── hos/                    # HarmonyOS 平台特定代码
├── android/                    # Android Gradle 工程
├── ios/                        # iOS Xcode 工程
├── hos/                        # HarmonyOS DevEco 工程
├── scripts/
│   └── build_tdlib_phase0.sh   # TDLib 原生库构建脚本
└── build.sh                    # 构建编排脚本
```

## 技术栈

- **语言**：Cangjie（仓颉编程语言）
- **UI 框架**：Keels（ArkUI 跨平台移植）
- **Telegram SDK**：TDLib（td_json_client C ABI）
- **工程模板**：CJMP v0.6.2 C/S 源码集
