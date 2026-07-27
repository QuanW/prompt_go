import json

from modules.runtime_status import RuntimeStatus, classify_error


class DummyConfig:
    config_data = {
        "api": {
            "deepseek": {
                "key": "secret-value",
                "base_url": "https://example.test/v1",
                "model": "deepseek-ai/DeepSeek-V3",
            },
            "kimi": {
                "key": "",
                "base_url": "https://kimi.test",
                "model": "moonshot-v1-8k",
            },
        }
    }


def test_classify_error():
    assert classify_error("选中文本为空") == "clipboard"
    assert classify_error("API认证失败") == "api"
    assert classify_error("模板文件不存在") == "template"
    assert classify_error("辅助功能权限未授予") == "permission"


def test_runtime_status_redacts_api_key(tmp_path):
    status_path = tmp_path / "status.json"
    status = RuntimeStatus(status_path)

    status.set_api_status(DummyConfig())
    data = json.loads(status_path.read_text(encoding="utf-8"))

    assert data["api"]["providers"]["deepseek"]["configured"] is True
    assert data["api"]["providers"]["kimi"]["configured"] is False
    assert "secret-value" not in status_path.read_text(encoding="utf-8")
    assert data["model"]["name"] == "deepseek-ai/DeepSeek-V3"


def test_runtime_status_trigger_result(tmp_path):
    status = RuntimeStatus(tmp_path / "status.json")

    status.set_trigger_started("demo.md")
    status.set_trigger_result("demo.md", {
        "success": False,
        "error": "选中文本为空",
        "response_time": 0.1,
        "output_chars": 0,
        "total_chunks": 0,
    })

    data = json.loads((tmp_path / "status.json").read_text(encoding="utf-8"))
    assert data["state"] == "running"
    assert data["last_trigger"]["status"] == "error"
    assert data["last_trigger"]["error_type"] == "clipboard"
    assert data["last_error"]["type"] == "clipboard"
    assert data["last_trigger"]["output_chars"] == 0
    assert data["last_trigger"]["total_chunks"] == 0
