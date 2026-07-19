# SwiftBar 菜单栏控制

Prompt GO 可以通过 SwiftBar 在菜单栏中启动、停止、重启和重载配置。推荐进一步安装 macOS LaunchAgent，让 launchd 管理后台进程，SwiftBar 只负责控制和查看状态。

## 前提

先在项目目录中准备好虚拟环境和依赖：

```bash
cd /Users/wquan/Developer/prompt_go
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

控制脚本会优先使用项目内的 `.venv/bin/python`。

## 安装 SwiftBar 插件

1. 安装并打开 SwiftBar。
2. 设置 SwiftBar 插件目录，例如 `~/SwiftBarPlugins`。
3. 将插件脚本复制或软链接到插件目录：

```bash
ln -sf /Users/wquan/Developer/prompt_go/swiftbar/prompt-go.5s.sh ~/SwiftBarPlugins/prompt-go.5s.sh
```

4. 确保脚本可执行：

```bash
chmod +x /Users/wquan/Developer/prompt_go/scripts/prompt_goctl.sh
chmod +x /Users/wquan/Developer/prompt_go/swiftbar/prompt-go.5s.sh
```

如果你的项目目录不同，可以在 SwiftBar 启动环境中设置 `PROMPT_GO_DIR`，或直接编辑 `swiftbar/prompt-go.5s.sh` 顶部的默认路径。

## 手动控制

也可以不使用 SwiftBar，直接运行：

```bash
scripts/prompt_goctl.sh status
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh reload
scripts/prompt_goctl.sh stop
scripts/prompt_goctl.sh restart
```

## 安装 LaunchAgent

安装后，Prompt GO 会由 macOS launchd 管理。SwiftBar 菜单里的 Start、Stop、Restart 会自动切换为控制 LaunchAgent。

```bash
scripts/prompt_goctl.sh install-agent
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh status
```

卸载：

```bash
scripts/prompt_goctl.sh uninstall-agent
```

安装位置：

```text
~/Library/LaunchAgents/com.quanw.prompt-go.plist
```

LaunchAgent 会使用当前项目里的 `.venv/bin/python`、`main.py`、`config` 和 `prompt` 目录。如果更换项目路径或虚拟环境，请重新运行 `install-agent` 生成新的 plist。

如果项目位于 `Downloads`、`Desktop` 或 `Documents` 等 macOS 隐私保护目录，LaunchAgent 启动的 Python 可能会遇到文件访问限制，例如：

```text
PermissionError: [Errno 1] Operation not permitted: '.venv/pyvenv.cfg'
```

更推荐把项目放到不受隐私保护拦截的开发目录，例如：

```text
~/Developer/prompt_go
```

迁移目录后重新执行：

```bash
scripts/prompt_goctl.sh uninstall-agent
scripts/prompt_goctl.sh install-agent
```

如果暂时不迁移目录，`prompt_goctl.sh start` 会在 LaunchAgent 启动失败时回退到 SwiftBar 直启模式。

## 状态显示

SwiftBar 菜单栏标题使用紧凑颜色状态灯，节省菜单栏空间：

- 绿色：Prompt GO 正在运行。
- 橙色：存在权限警告或 stale PID。
- 红色：已停止或状态命令失败。

下拉菜单会显示更详细的运行状态，包括当前模型、API 配置状态和最近一次触发结果。这些信息来自本地运行状态文件：

```bash
runtime/status.json
```

该文件只保存脱敏状态，例如 API provider 是否已配置、当前模型名、最近错误类型，不保存 API key。

## macOS 权限

如果通过 SwiftBar 启动 Prompt GO，需要给 SwiftBar 授予必要权限：

- 系统设置 -> 隐私与安全性 -> 辅助功能
- 系统设置 -> 隐私与安全性 -> 输入监控

如果仍然从 Terminal 启动，则权限应授予 Terminal 或 iTerm2。当前快捷键监听使用 macOS 原生热键 helper，不再通过 pynput 监听全局键盘事件。

如果通过 LaunchAgent 启动，macOS 可能会要求给实际的 Python 可执行文件授权。可以通过 Doctor 查看路径：

```bash
scripts/prompt_goctl.sh doctor
```

通常是：

```text
/Users/wquan/Developer/prompt_go/.venv/bin/python
```

如果日志中出现下面的警告，说明 macOS 没有把键盘事件交给当前启动宿主：

```text
This process is not trusted! Input event monitoring will not be possible
```

处理方式：

1. 完全退出 SwiftBar。
2. 在“辅助功能”和“输入监控”中授予 SwiftBar 权限。
3. 如果仍然无效，点击 SwiftBar 菜单中的 Doctor，查看实际使用的 Python 路径，并把该 Python 可执行文件也加入上述权限列表。
4. 重新打开 SwiftBar，再启动 Prompt GO。

可以手动运行诊断：

```bash
scripts/prompt_goctl.sh doctor
```
