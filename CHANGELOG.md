# CHANGELOG

本文档记录当前 fork 的重要版本差异。更完整的开发背景见 [docs/DEVELOPMENT_LOG_CN.md](docs/DEVELOPMENT_LOG_CN.md)。

## [未发布]

### 计划
- 继续收敛上游遗留测试，修正 Kimi 枚举、文本过滤等与当前实现不一致的测试。
- 进一步模板化安装流程，降低多台 Mac 部署成本。
- 评估是否用更原生的 macOS 输出方式替换 `pynput.Controller` 文本输入自动化。

## [0.6.0] - 2026-07-17

### 移除
- 删除 macOS 上的 pynput 全局快捷键监听路径。
- 删除旧的快捷键 backend 状态字段和 `Hotkey: native` 菜单展示。
- 删除 `native_hotkeys` 示例配置开关。

### 变更
- 项目定位收敛为 macOS-only 工具。
- `doctor` 和 SwiftBar 只展示运行态、API 配置状态、当前模型和最近触发结果。
- `pynput` 仅保留用于文本输入/复制粘贴自动化，不再用于快捷键监听。

### 测试
- 更新快捷键监听测试，覆盖 native helper 成功、失败和非 macOS unsupported 路径。
- 修复 `tests/test_main.py` 中部分用例污染真实 `runtime/status.json` 的问题。

## [0.5.0] - 2026-07-17

### 变更
- macOS 快捷键监听固定走 C native helper，即 `RegisterEventHotKey` 路径。
- 移除旧的 Python/ctypes Carbon 注册器。
- native helper 启动失败时直接报错，不再回退到全键盘监听。

### 诊断
- SwiftBar 和 doctor 显示 `Hotkey: native`，用于确认迁移阶段的实际监听路径。

## [0.4.0] - 2026-07-17

### 新增
- `modules/runtime_status.py`：写入脱敏运行状态 `runtime/status.json`。
- `scripts/prompt_goctl.sh doctor`：显示项目路径、Python 路径、LaunchAgent 状态、API 配置状态、当前模型和最近错误。
- SwiftBar 下拉菜单显示 API/model/last trigger/last error。
- 日志清理入口和错误类型分类：permission、api、template、clipboard、hotkey、unknown。

### 变更
- `pyproject.toml` Python 声明调整为 `>=3.9`。
- 测试隔离 runtime status，避免污染真实运行状态。

## [0.3.0] - 2026-07-17

### 新增
- SwiftBar 紧凑颜色状态点，节省菜单栏空间。
- 用户级单实例锁，避免多个 Prompt GO 进程抢占快捷键。
- duplicate process 检测，帮助定位多个旧进程同时运行的问题。
- macOS Python 权限诊断，显示 `.venv/bin/python` 和 resolved Python 路径。

## [0.2.0] - 2026-07-17

### 新增
- SwiftBar 控制脚本，可执行 start/stop/restart/reload/doctor/open log。
- LaunchAgent 安装、卸载和状态控制。
- 项目路径迁移到 `~/Developer/prompt_go` 后的 plist/SwiftBar 路径更新。

### 变更
- 推荐用 LaunchAgent 管理后台服务，SwiftBar 作为菜单栏控制面板。

## [0.1.0] - 2026-07-17

### 新增
- SiliconFlow/DeepSeek 流式 SSE 兼容。
- 支持硅基流动 DeepSeek 模型名，例如 `deepseek-ai/DeepSeek-V3.2`。
- 改进 SSE 增量解码，避免中文流式内容被错误切分造成乱码解析失败。

## [upstream-1.0.0] - 2024-12-19

### 来源
- 基于 `astordu/prompt_go` 上游项目。
- 上游提供模板、快捷键、文本处理、DeepSeek API、流式输出等基础能力。
- 当前 fork 已显著偏向 macOS-only、本地 LaunchAgent/SwiftBar 工作流。
