# Prompt GO

Prompt GO is a macOS local AI text-processing helper. Select text in any app, press a configured global hotkey, and Prompt GO applies a Markdown prompt template, calls a DeepSeek-compatible API, and writes the result back to the current cursor position.

This fork focuses on macOS daily use: SiliconFlow/DeepSeek compatibility, a native hotkey helper, LaunchAgent background service control, SwiftBar menu-bar controls, and local diagnostics.

## Features

- Global hotkeys mapped to Markdown templates.
- Local selected-text capture and cursor output.
- Streaming API output.
- DeepSeek official API and SiliconFlow DeepSeek model names.
- macOS native hotkey helper based on `RegisterEventHotKey`.
- LaunchAgent service management through `scripts/prompt_goctl.sh`.
- SwiftBar menu-bar control.
- Redacted runtime status for `doctor` and SwiftBar.

## Requirements

- macOS.
- Python 3.9+.
- Xcode Command Line Tools.
- SwiftBar, optional but recommended.

```bash
xcode-select --install
```

## Install

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone git@github.com:QuanW/prompt_go.git
cd prompt_go
git checkout codex/siliconflow-api-compat

python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

cp config/global_config.example.yaml config/global_config.yaml
cp config/hotkey_mapping.example.yaml config/hotkey_mapping.yaml
```

Edit `config/global_config.yaml` with your API settings. SiliconFlow example:

```yaml
api:
  provider: deepseek
  deepseek:
    base_url: https://api.siliconflow.cn/v1
    key: 'sk-your-siliconflow-api-key'
    model: deepseek-ai/DeepSeek-V4-Flash
```

Templates use this global model by default. Add `model: provider,specific-model`
to a template only when that task really needs a different model.

Install and start the LaunchAgent:

```bash
scripts/prompt_goctl.sh install-agent
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh doctor
```

## Use

1. Select text in any app.
2. Press a configured hotkey, for example `ctrl+shift+1`.
3. Prompt GO processes the selected text with the mapped template.
4. The result is written back to the cursor location.

Common commands:

```bash
scripts/prompt_goctl.sh status
scripts/prompt_goctl.sh start
scripts/prompt_goctl.sh stop
scripts/prompt_goctl.sh restart
scripts/prompt_goctl.sh reload
scripts/prompt_goctl.sh log
scripts/prompt_goctl.sh doctor
```

## SwiftBar

Link the plugin into your SwiftBar plugin directory:

```bash
ln -sf ~/Developer/prompt_go/swiftbar/prompt-go.5s.sh ~/Documents/SwiftBar/prompt-go.5s.sh
```

See [docs/swiftbar_cn.md](docs/swiftbar_cn.md) for the detailed menu-bar setup notes.

## Permissions

Depending on how Prompt GO is started, macOS may require Accessibility/Input Monitoring permissions for SwiftBar, Terminal, or the resolved Python executable. Run:

```bash
scripts/prompt_goctl.sh doctor
```

## Uninstall

```bash
cd ~/Developer/prompt_go
scripts/prompt_goctl.sh stop
scripts/prompt_goctl.sh uninstall-agent
rm ~/Documents/SwiftBar/prompt-go.5s.sh
```

Then remove the project directory if desired.

## Development

```bash
source .venv/bin/activate
python -m pytest tests/test_hotkey_listener.py tests/test_runtime_status.py tests/test_main.py -q -p no:cacheprovider
bash -n scripts/prompt_goctl.sh swiftbar/prompt-go.5s.sh
git diff --check
```

Development notes and version history are in [docs/DEVELOPMENT_LOG_CN.md](docs/DEVELOPMENT_LOG_CN.md) and [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
