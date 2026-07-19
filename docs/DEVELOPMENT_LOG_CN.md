# Prompt GO 开发日志

本文档回顾从上游 `astordu/prompt_go` 到当前 fork 的改造过程，帮助后续继续开发时快速理解“为什么现在是这样”。

## 当前状态快照

- 仓库：`QuanW/prompt_go`
- 分支：`codex/siliconflow-api-compat`
- 推荐本地路径：`~/Developer/prompt_go`
- 推荐运行方式：LaunchAgent 后台进程 + SwiftBar 菜单栏控制
- Python：项目虚拟环境 `.venv`，当前声明 `>=3.9`
- 快捷键监听：macOS C native helper，调用 `RegisterEventHotKey`
- API：仍复用 `deepseek` provider 配置，可指向 DeepSeek 官方或硅基流动 `https://api.siliconflow.cn/v1`
- 本地配置：`config/global_config.yaml` 和 `config/hotkey_mapping.yaml` 不入库

## 关键设计决策

### 1. macOS-only，而不是跨平台工具

最初上游项目宣称跨平台，并使用 pynput 监听全局键盘事件。实际使用目标只有 macOS，因此我们把快捷键监听收敛为 macOS 原生热键注册。这样代码路径更少，权限边界更清楚，也更接近菜单栏工具的最佳实践。

### 2. 原生 helper 监听快捷键

当前路径是：

```text
Prompt GO Python 进程
  -> native/macos_hotkey_helper.c
  -> RegisterEventHotKey
  -> Unix datagram socket
  -> Python hotkey handler
```

这样不会监听所有键盘事件，只注册配置里的具体热键。相比 pynput 全局监听，权限语义更窄，也更容易向用户解释。

### 3. 保留 pynput 作为文本输入自动化

`pynput` 不再用于快捷键监听，但 `modules/text_processor.py` 仍使用 `pynput.keyboard.Controller` 模拟复制、粘贴和逐字符输出。未来可以继续评估是否改成更原生的 macOS 输出方式，但这和快捷键监听是两个问题。

### 4. LaunchAgent 负责后台进程，SwiftBar 负责控制

Terminal 长期运行不适合日常使用。现在推荐：

- LaunchAgent 负责启动/停止后台 Python 进程。
- SwiftBar 只作为菜单栏控制器。
- `scripts/prompt_goctl.sh` 是统一入口，SwiftBar 和用户命令都调用它。

### 5. runtime status 必须脱敏

`runtime/status.json` 用于 doctor/SwiftBar 显示状态，只保存 provider 是否配置、当前模型、最近触发结果、错误类型等信息，不保存 API key 或用户选中文本。

## 开发阶段回顾

### 阶段一：SiliconFlow SSE 兼容

问题：硅基流动返回的流式 SSE chunk 在中文内容上被错误切分，出现类似乱码和 JSON 解析失败。

处理：

- 改进 `modules/model_client.py` 的 SSE 增量解析。
- 支持 OpenAI-compatible `chat.completion.chunk` 格式。
- 增加硅基流动 DeepSeek 模型名白名单。
- 保持 provider 仍为 `deepseek`，通过 `base_url` 切换到硅基流动。

相关提交：`98f94de Add SiliconFlow stream compatibility`

### 阶段二：SwiftBar 与 LaunchAgent

目标：不要在 Terminal 里长期运行。

处理：

- 新增 `scripts/prompt_goctl.sh`，统一控制 status/start/stop/restart/reload/log/doctor。
- 新增 SwiftBar 插件 `swiftbar/prompt-go.5s.sh`。
- 新增 LaunchAgent install/uninstall，plist 由脚本按当前项目路径生成。
- 后续迁移项目到 `~/Developer/prompt_go`，修正脚本、LaunchAgent、SwiftBar 软链接路径。

相关提交：

- `85a4d34 Add SwiftBar controls and tighten hotkey handling`
- `fd7a9ff Add SwiftBar permission diagnostics`
- `c3e7140 Add LaunchAgent service controls`
- `f5b1456 Update service paths after project move`

### 阶段三：快捷键权限与 native helper

问题：pynput 全局监听需要较重权限，而且会看到大量无关按键事件；用户也观察到 `cmd+c` 等按键都会被监听。

处理：

- 尝试 macOS native backend。
- 最终采用 C helper 调用 `RegisterEventHotKey`。
- 单实例锁防止多个进程抢占热键。
- doctor 显示 Python resolved path，辅助配置 macOS 权限。

相关提交：

- `bfee0e9 Prepare native macOS hotkey backend`
- `8336cd1 Use native macOS hotkey helper`
- `9405677 Clarify macOS Python permissions`
- `cb01aaf Detect duplicate Prompt GO instances`
- `69bd10f Add user-level single instance lock`

### 阶段四：可观测性

目标：SwiftBar 和 doctor 能看到“服务是否真的可用”。

处理：

- 新增 `modules/runtime_status.py`。
- 运行状态写入 `runtime/status.json`。
- doctor 显示 runtime state、API configured、current model、last trigger、last error。
- SwiftBar 下拉菜单显示模型、API、最近触发结果。
- 增加错误分类和日志清理入口。
- Python 版本声明从 `>=3.13` 调整为 `>=3.9`。

相关提交：`c6fa011 Add runtime status observability`

### 阶段五：收敛快捷键架构

目标：既然只在 macOS 使用，就不要保留不必要的监听方案。

处理：

- macOS 固定使用 native helper。
- 删除 Python/ctypes Carbon 注册器。
- 删除 pynput 全局快捷键监听路径。
- 删除 backend/hotkey_backend 状态字段和 SwiftBar/doctor 的 Hotkey 展示。
- 删除 `native_hotkeys` 示例配置。
- 保留 `pynput.Controller` 作为文本输入自动化。

相关提交：

- `a368c72 Use native helper for macOS hotkeys`
- `11c7818 Remove legacy hotkey backend state`

## 当前文件职责

- `main.py`：主进程生命周期、初始化、PID/锁、runtime status 更新。
- `modules/hotkey_listener.py`：快捷键映射、配置热重载、macOS native helper 管理。
- `native/macos_hotkey_helper.c`：注册 macOS 全局热键并通过 Unix socket 通知 Python。
- `modules/model_client.py`：DeepSeek/SiliconFlow API 客户端、SSE 解析。
- `modules/text_processor.py`：选中文本读取、模板处理、模型调用、输出到光标。
- `modules/runtime_status.py`：脱敏 runtime status 写入。
- `scripts/prompt_goctl.sh`：服务控制、LaunchAgent 管理、doctor。
- `swiftbar/prompt-go.5s.sh`：SwiftBar 菜单栏状态和控制项。

## 后续开发建议

### 高优先级

- 修正旧测试与当前实现不一致的问题，尤其是 Kimi 枚举、文本过滤、完整 text_processor 测试。
- 将安装流程脚本化，例如新增 `scripts/bootstrap_macos.sh`，自动检查 venv、clang、配置文件、LaunchAgent、SwiftBar 链接。
- 改善 helper 错误输出，把热键占用、clang 缺失、socket 问题区分得更清楚。

### 中优先级

- 研究替换 `pynput.Controller` 的文本输出路径，进一步降低权限复杂度。
- 给 `native/macos_hotkey_helper.c` 增加独立测试或 smoke test。
- 增强 doctor：检查配置文件是否存在、模板是否存在、helper 是否可编译、SwiftBar 链接是否正确。

### 低优先级

- 整理英文文档。
- 清理上游仍残留的跨平台措辞。
- 评估是否把 provider 从 `deepseek` 扩展为更通用的 OpenAI-compatible provider。

## 安全注意事项

- 永远不要提交 `config/global_config.yaml`。
- 提交前可用脚本或人工检查确认 API key 没有进入 tracked files。
- `runtime/status.json` 应继续保持脱敏，不保存 prompt、选中文本或完整模型响应。
- GitHub push 前优先查看 `git status --short --ignored`，确认只有工程文件被 staged。

## 常用开发命令

```bash
source .venv/bin/activate
python -m pytest tests/test_hotkey_listener.py tests/test_runtime_status.py tests/test_main.py -q -p no:cacheprovider
bash -n scripts/prompt_goctl.sh swiftbar/prompt-go.5s.sh
git diff --check
scripts/prompt_goctl.sh doctor
```

更新服务：

```bash
scripts/prompt_goctl.sh restart
```

提交前检查：

```bash
git status --short --ignored
git diff --stat
```
