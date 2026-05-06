# Run Report: iOS TDLib Integration Issue

## 1. 任务摘要
- **Task**: 修复 iOS 测试中 TDLib phase0 探测失败的问题
- **Goal**: 使 `libtdjson.dylib` 能够在 iOS 模拟器测试中正确加载
- **Constraints**: 不破坏现有构建流程，保持 Android 和 iOS 构建的一致性

## 2. 产出文档
- Design document: N/A
- Acceptance document: N/A
- Run report: `doc/run_report_ios_tdlib_integration.md`

## 3. 基线理解
- **Existing implementation baseline**: 
  - TDLib 已通过 `scripts/build_tdlib_phase0.sh` 构建完成
  - Android 版本工作正常
  - iOS 版本构建成功但运行时加载失败
  - 错误信息: `dlopen failed: libtdjson.dylib (no such file)`

- **Main flow to preserve**:
  - 现有的 TDLib 构建流程
  - CJMP 构建脚本 `build.sh`
  - Xcode 项目结构

- **Expected change boundary**:
  - 仅修改 Xcode 项目配置
  - 添加 `libtdjson.dylib` 到项目
  - 配置正确的链接和嵌入设置

## 4. 查询审计轨迹
| 步骤 | 阶段 | 分类 | 工具类型 | 工具名 | 目的 | 查询内容 | 来源 | 关键结论 | 是否用于实现 | 关联文件 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | investigation | local-code | bash | find/grep | 定位 libtdjson.dylib 文件位置 | `find apps/cjmp -name "*tdlib*" -o -name "*tdjson*"` | 本地文件系统 | 发现 `libtdjson.dylib` 位于 `apps/cjmp/build/tdlib-phase0/ios-sim/` | 是 | N/A |
| 2 | investigation | local-code | read | Read | 检查 iOS FFI 桥接代码 | `apps/cjmp/ios/oc_bridge/cjmp_ffi.m` | 本地代码 | 确认代码尝试从 `privateFrameworksPath` 加载 `libtdjson.dylib` | 是 | cjmp_ffi.m:27 |
| 3 | investigation | local-code | read | Read | 检查构建脚本 | `apps/cjmp/build.sh` | 本地代码 | 发现构建脚本在 line 280 尝试复制 `${tdlibPhase0Root}/ios/libtdjson.dylib`，但实际路径应为 `ios-sim` | 是 | build.sh:280 |
| 4 | investigation | local-code | bash | grep | 检查 Xcode 项目配置 | `grep -c "libtdjson.dylib" project.pbxproj` | Xcode 项目文件 | 确认 `libtdjson.dylib` 未添加到 Xcode 项目 | 是 | project.pbxproj |

## 5. 决策记录
| 步骤 | 决策 | 原因 | 影响文件 | 备注 |
|---|---|---|---|---|
| 1 | 创建 Python 脚本添加 libtdjson 到 Xcode 项目 | Xcode project.pbxproj 文件格式复杂，手动编辑容易出错 | `scripts/add_libtdjson_to_xcode.py` | 生成唯一 UUID，添加文件引用、构建阶段和嵌入阶段 |
| 2 | 为测试目标添加 LIBRARY_SEARCH_PATHS | 测试目标需要能够找到 libtdjson.dylib 进行链接 | `project.pbxproj` | 添加 `$(PROJECT_DIR)/frameworks` 到库搜索路径 |
| 3 | 为测试目标添加 LD_RUNPATH_SEARCH_PATHS | 测试 bundle 需要在运行时找到主应用的 Frameworks 目录 | `project.pbxproj` | 添加 `@executable_path/../../Frameworks` 到 rpath |

## 6. 问题与处理
| 步骤 | 问题 | 原因 | 解决方式 | 状态 | 备注 |
|---|---|---|---|---|---|
| 1 | iOS 测试报错: `dlopen failed: libtdjson.dylib (no such file)` | `libtdjson.dylib` 未添加到 Xcode 项目，未被复制到 app bundle | 1. 创建 Python 脚本添加到 Xcode 项目<br>2. 配置为嵌入框架 | partially-resolved | 库已添加到项目并嵌入，但测试 bundle 仍无法加载 |
| 2 | 构建脚本路径错误 | `build.sh:280` 使用 `ios` 路径，但实际构建输出在 `ios-sim` | 未修复 | open | 当前使用 `ios-sim` 构建，路径不匹配需要修正 |
| 3 | 测试目标链接失败: `library 'tdjson' not found` | 测试目标的 LIBRARY_SEARCH_PATHS 未包含 frameworks 目录 | 添加 `$(PROJECT_DIR)/frameworks` 到 LIBRARY_SEARCH_PATHS | resolved | 链接成功 |
| 4 | 测试 bundle 运行时加载失败: `Library not loaded: @rpath/libtdjson.dylib` | 测试 bundle 的 rpath 不包含主应用的 Frameworks 目录 | 添加 `@executable_path/../../Frameworks` 到 LD_RUNPATH_SEARCH_PATHS | partially-resolved | rpath 已配置，但 dylib 仍未找到 |
| 5 | dylib 在运行时仍未找到 | 测试 bundle 查找路径中没有主应用的 Frameworks 目录 | 需要进一步调查：可能需要将 libtdjson 也复制到测试 bundle 的 Frameworks，或修改链接方式 | open | 当前 rpath 配置可能不正确，或需要不同的部署策略 |

## 7. 代码改动
| 文件 | 改动原因 | 改动摘要 | 关联查询步骤 |
|---|---|---|---|
| `scripts/add_libtdjson_to_xcode.py` | 自动化添加 libtdjson 到 Xcode 项目 | 创建 Python 脚本，生成 UUID，添加 PBXFileReference、PBXBuildFile、Frameworks 和 Embed Libraries 阶段 | 4 |
| `ios/cjmp.xcodeproj/project.pbxproj` | 添加 libtdjson 支持 | 1. 添加 libtdjson.dylib 文件引用<br>2. 添加到 Frameworks 构建阶段<br>3. 添加到 Embed Libraries 阶段<br>4. 配置测试目标的 LIBRARY_SEARCH_PATHS<br>5. 配置测试目标的 LD_RUNPATH_SEARCH_PATHS | 4 |

## 8. 验证记录
| 步骤 | 检查项 | 方法 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | libtdjson.dylib 是否存在 | `ls -la apps/cjmp/ios/frameworks/libtdjson.dylib` | ✓ 通过 | 文件存在，大小 25MB，arm64 架构 |
| 2 | libtdjson.dylib 是否添加到 Xcode 项目 | `grep -c "libtdjson.dylib" project.pbxproj` | ✓ 通过 | 找到 5 处引用 |
| 3 | iOS 模拟器构建是否成功 | `./build.sh release ios-sim` | ✓ 通过 | 构建成功，libtdjson.dylib 被复制到 frameworks 目录 |
| 4 | 测试目标链接是否成功 | `xcodebuild test` 链接阶段 | ✓ 通过 | 链接成功，无 "library not found" 错误 |
| 5 | 测试 bundle 运行时加载 | `xcodebuild test` 运行阶段 | ✗ 失败 | 错误: `Library not loaded: @rpath/libtdjson.dylib` |

## 9. 最终结论

### 已完成工作
1. ✓ 定位问题：`libtdjson.dylib` 未添加到 Xcode 项目
2. ✓ 创建自动化脚本：`scripts/add_libtdjson_to_xcode.py`
3. ✓ 添加 libtdjson 到 Xcode 项目：文件引用、构建阶段、嵌入阶段
4. ✓ 配置测试目标的库搜索路径：LIBRARY_SEARCH_PATHS
5. ✓ 配置测试目标的运行时搜索路径：LD_RUNPATH_SEARCH_PATHS
6. ✓ iOS 模拟器构建成功
7. ✓ 测试目标链接成功

### 未解决问题
1. ✗ 测试 bundle 运行时仍无法加载 `libtdjson.dylib`
   - 错误：`Library not loaded: @rpath/libtdjson.dylib`
   - 原因：dylib loader 在多个路径中查找但都未找到
   - 尝试的路径包括：
     - `/Users/user/Library/Developer/Xcode/DerivedData/.../Debug-iphonesimulator/libtdjson.dylib`
     - `.../cjmpUITests-Runner.app/PlugIns/cjmpUITests.xctest/Frameworks/libtdjson.dylib`
     - `.../cjmpUITests-Runner.app/Frameworks/libtdjson.dylib`
     - 系统路径

### 根本原因分析
测试 bundle (cjmpUITests.xctest) 链接了 `libtdjson.dylib`，但该库实际只存在于主应用 (cjmp.app) 的 Frameworks 目录中。测试 bundle 的 rpath 配置为 `@executable_path/../../Frameworks`，理论上应该能找到主应用的 Frameworks，但实际运行时仍然失败。

可能的原因：
1. UI 测试的可执行路径与预期不同
2. 测试 bundle 不应该直接链接 libtdjson，而应该通过主应用间接访问
3. 需要将 libtdjson 也复制到测试 bundle 的 Frameworks 目录

## 10. 风险与人工关注点

### 需要人工验证的点
1. **测试架构设计**：确认 UI 测试 bundle 是否应该直接链接 libtdjson，还是应该只通过主应用访问
2. **部署策略**：确认是否需要将 libtdjson 复制到测试 bundle 的 Frameworks 目录
3. **rpath 配置**：验证 `@executable_path/../../Frameworks` 在 UI 测试环境中是否正确

### 建议的后续步骤
1. **方案 A**：修改测试目标，不直接链接 libtdjson
   - 从测试目标的 Frameworks 构建阶段移除 libtdjson
   - 测试代码通过主应用的 FFI 接口间接访问 TDLib
   
2. **方案 B**：将 libtdjson 复制到测试 bundle
   - 修改 Xcode 项目，添加 Copy Files 构建阶段
   - 将 libtdjson.dylib 复制到测试 bundle 的 Frameworks 目录
   
3. **方案 C**：使用弱链接
   - 将 libtdjson 配置为可选依赖
   - 在运行时动态加载

### 剩余风险
- 当前配置下，iOS 测试无法运行
- 需要选择正确的部署策略才能继续
- 可能需要重新设计测试架构

### Context7 使用说明
本次任务未涉及 CJMP 框架 API 或仓颉语言特性查询，主要是 iOS 原生构建配置问题，因此未使用 Context7。所有信息来源于：
- 本地代码阅读
- Xcode 项目文件分析
- iOS 构建系统文档（基于已有知识）
- 运行时错误日志分析
