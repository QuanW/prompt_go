# SwiftBar 菜单栏控制

Prompt GO 可以通过 SwiftBar 在菜单栏中启动、停止、重启和重载配置。

## 前提

先在项目目录中准备好虚拟环境和依赖：

```bash
cd /Users/wquan/Downloads/softwares/prompt_go
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
ln -sf /Users/wquan/Downloads/softwares/prompt_go/swiftbar/prompt-go.5s.sh ~/SwiftBarPlugins/prompt-go.5s.sh
```

4. 确保脚本可执行：

```bash
chmod +x /Users/wquan/Downloads/softwares/prompt_go/scripts/prompt_goctl.sh
chmod +x /Users/wquan/Downloads/softwares/prompt_go/swiftbar/prompt-go.5s.sh
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

## macOS 权限

如果通过 SwiftBar 启动 Prompt GO，需要给 SwiftBar 授予必要权限：

- 系统设置 -> 隐私与安全性 -> 辅助功能
- 系统设置 -> 隐私与安全性 -> 输入监控

如果仍然从 Terminal 启动，则权限应授予 Terminal 或 iTerm2。
