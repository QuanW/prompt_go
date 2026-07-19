# Prompt GO

Prompt GO 是一个 macOS 本地 AI 文本处理工具。你可以在任意应用中选中文本，按下全局快捷键，让本地后台进程读取选中文本、套用 Markdown 提示词模板、调用大模型 API，并把结果自动输出回当前光标位置。

当前 fork 的重点是：macOS 菜单栏/LaunchAgent 使用体验、硅基流动 DeepSeek 兼容、原生全局快捷键 helper、可观测诊断，以及适合个人机器长期运行的工程化整理。

## 基本功能

- 全局快捷键触发：默认 `ctrl+shift+1/2/3/0`，映射到不同模板。
- 选中文本处理：从当前应用读取选中文本，作为 `{{input}}` 注入模板。
- Markdown 模板：模板放在 `prompt/`，支持 YAML front matter 配置模型、温度、token 等参数。
- 流式输出：调用模型后将响应逐步输出到当前光标位置。
- DeepSeek/SiliconFlow 兼容：支持官方 DeepSeek API，也支持硅基流动 OpenAI-compatible DeepSeek 模型名。
- macOS 原生快捷键：使用 C native helper 调用 `RegisterEventHotKey`，不再用 pynput 监听全局键盘事件。
- 菜单栏控制：通过 SwiftBar 启动、停止、重启、重载配置、查看状态。
- LaunchAgent 后台运行：由 macOS launchd 管理后台进程。
- 本地状态诊断：`doctor` 和 SwiftBar 读取脱敏的 `runtime/status.json`，显示运行态、API 配置状态、当前模型、最近触发结果。

## 系统要求

- macOS。
- Python 3.9 或更高版本。
- Xcode Command Line Tools，用于编译 `native/macos_hotkey_helper.c`。
- SwiftBar，可选但推荐，用于菜单栏控制。
- 一个兼容的 DeepSeek API 服务，例如 DeepSeek 官方或硅基流动。

安装 Command Line Tools：

```bash
xcode-select --install
```

## 安装

推荐放在不容易触发 macOS 隐私目录限制的位置，例如：

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone git@github.com:QuanW/prompt_go.git
cd prompt_go
git checkout codex/siliconflow-api-compat
```

创建虚拟环境并安装依赖：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

创建本机配置文件：

```bash
cp config/global_config.example.yaml config/global_config.yaml
cp config/hotkey_mapping.example.yaml config/hotkey_mapping.yaml
```

`config/global_config.yaml`、`config/hotkey_mapping.yaml`、日志、PID、runtime 状态和 `.venv/` 都是本机文件，已被 `.gitignore` 忽略，不应提交。

## 配置 API

DeepSeek 官方示例：

```yaml
api:
  deepseek:
    base_url: https://api.deepseek.com
    key: 'sk-your-deepseek-api-key'
    model: deepseek-chat
```

硅基流动示例：

```yaml
api:
  deepseek:
    base_url: https://api.siliconflow.cn/v1
    key: 'sk-your-siliconflow-api-key'
    model: deepseek-ai/DeepSeek-V3.2
```

模板 front matter 中可以使用 `厂商,模型` 格式，例如：

```markdown
model: deepseek,deepseek-ai/DeepSeek-V3.2
temperature: 0.3
max_tokens: 2000

---

请整理下面的内容：

{{input}}
```

## 配置快捷键

编辑 `config/hotkey_mapping.yaml`：

```yaml
hotkeys:
  ctrl+shift+1: tidy_content_plain_txt.md
  ctrl+shift+2: translate_plain_txt.md
  ctrl+shift+3: corect_english_grammer.md
  ctrl+shift+0: mermaid.md

settings:
  enabled: true
  response_delay: 100
```

快捷键监听在 macOS 上只使用原生 helper。若快捷键被其他应用占用，helper 会注册失败或该组合无法触发，此时请换一个组合并执行 reload/restart。

## 使用

首次建议先安装 LaunchAgent：

```bash
scripts/prompt_goctl.sh install-agent
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh doctor
```

常用控制命令：

```bash
scripts/prompt_goctl.sh status
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh stop
scripts/prompt_goctl.sh restart
scripts/prompt_goctl.sh reload
scripts/prompt_goctl.sh log
scripts/prompt_goctl.sh doctor
```

基本使用流程：

1. 在任意应用里选中一段文本。
2. 按下 `ctrl+shift+1`、`ctrl+shift+2` 等配置好的快捷键。
3. Prompt GO 自动读取选中文本、调用对应模板和模型。
4. 结果会输出到当前光标位置。

如果你修改了 `config/hotkey_mapping.yaml` 或模板文件，可以执行：

```bash
scripts/prompt_goctl.sh reload
```

如果 reload 后快捷键不生效，执行：

```bash
scripts/prompt_goctl.sh restart
```

## SwiftBar 菜单栏控制

安装 SwiftBar 后，将插件脚本软链接到 SwiftBar 插件目录。示例：

```bash
ln -sf ~/Developer/prompt_go/swiftbar/prompt-go.5s.sh ~/Documents/SwiftBar/prompt-go.5s.sh
```

确保脚本可执行：

```bash
chmod +x scripts/prompt_goctl.sh
chmod +x swiftbar/prompt-go.5s.sh
```

SwiftBar 菜单栏会显示一个紧凑状态点：

- 绿色：服务正在运行。
- 橙色：可能存在权限告警或 stale PID。
- 红色：服务停止或状态命令失败。

下拉菜单可执行 Stop、Restart、Reload Config、Doctor、Open Log 等操作。更详细说明见 [docs/swiftbar_cn.md](docs/swiftbar_cn.md)。

## macOS 权限

根据启动方式，可能需要给不同应用授权：

- SwiftBar 启动或控制：给 SwiftBar 授予 Accessibility。
- LaunchAgent 启动：macOS 可能要求给实际 Python 可执行文件授予 Accessibility/Input Monitoring。
- Terminal 手动启动：给 Terminal 或 iTerm2 授权。

查看实际 Python 路径：

```bash
scripts/prompt_goctl.sh doctor
```

常见路径类似：

```text
/Users/wquan/Developer/prompt_go/.venv/bin/python
/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9
```

如果 `.venv/bin/python` 是符号链接，macOS 权限列表里可能需要添加最终解析出来的 Python 可执行文件。

## 卸载

停止服务并卸载 LaunchAgent：

```bash
cd ~/Developer/prompt_go
scripts/prompt_goctl.sh stop
scripts/prompt_goctl.sh uninstall-agent
```

删除 SwiftBar 软链接，按你的插件目录调整路径：

```bash
rm ~/Documents/SwiftBar/prompt-go.5s.sh
```

删除项目目录：

```bash
cd ~/Developer
rm -rf prompt_go
```

如果你只想卸载后台服务但保留项目代码，只执行 `stop` 和 `uninstall-agent` 即可。

## 换目录继续开发

移动或重新 clone 到新目录后，需要重新生成 LaunchAgent plist 和 SwiftBar 软链接，因为它们包含项目绝对路径。

```bash
cd /new/path/prompt_go
scripts/prompt_goctl.sh uninstall-agent
scripts/prompt_goctl.sh install-agent
scripts/prompt_goctl.sh restart
ln -sf /new/path/prompt_go/swiftbar/prompt-go.5s.sh ~/Documents/SwiftBar/prompt-go.5s.sh
scripts/prompt_goctl.sh doctor
```

如果换目录后权限失效，重新检查 macOS Accessibility/Input Monitoring 授权。

## 开发与测试

常用测试：

```bash
source .venv/bin/activate
python -m pytest tests/test_hotkey_listener.py tests/test_runtime_status.py tests/test_main.py -q -p no:cacheprovider
bash -n scripts/prompt_goctl.sh swiftbar/prompt-go.5s.sh
git diff --check
```

完整测试里目前仍有部分上游遗留测试与当前实现不一致，例如 Kimi 枚举和文本过滤断言；开发新功能时优先跑受影响模块测试，并逐步修正旧测试。

## 项目结构

```text
prompt_go/
├── main.py                         # 主程序入口
├── native/macos_hotkey_helper.c     # macOS 原生快捷键 helper
├── scripts/prompt_goctl.sh          # 启动/停止/诊断/LaunchAgent 控制
├── swiftbar/prompt-go.5s.sh         # SwiftBar 菜单栏插件
├── modules/                         # 核心模块
├── config/*.example.yaml            # 配置模板
├── prompt/                          # 提示词模板
├── docs/                            # 使用和开发文档
└── tests/                           # 测试
```

## 相关文档

- [SwiftBar 菜单栏控制](docs/swiftbar_cn.md)
- [开发日志](docs/DEVELOPMENT_LOG_CN.md)
- [CHANGELOG](CHANGELOG.md)
