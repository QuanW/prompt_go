"""Runtime status snapshot for Prompt GO.

The status file is intentionally redacted. It is meant for local tools such as
SwiftBar and doctor, not for storing secrets or full request payloads.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional


SCHEMA_VERSION = 1


def _now() -> str:
    return _dt.datetime.now().astimezone().isoformat(timespec="seconds")


def classify_error(error: Optional[str]) -> Optional[str]:
    if not error:
        return None

    text = str(error).lower()
    if any(token in text for token in ["permission", "accessibility", "input monitoring", "辅助功能", "权限"]):
        return "permission"
    if any(token in text for token in ["api", "模型", "model", "认证", "密钥", "超时", "timeout", "rate", "http", "连接失败"]):
        return "api"
    if any(token in text for token in ["模板", "template", "占位符"]):
        return "template"
    if any(token in text for token in ["剪贴板", "clipboard", "选中文本", "文本为空", "selection"]):
        return "clipboard"
    if any(token in text for token in ["hotkey", "快捷键", "helper", "监听器", "listener"]):
        return "hotkey"
    return "unknown"


class RuntimeStatus:
    """Maintain an atomic redacted runtime status JSON file."""

    def __init__(self, path: Path):
        self.path = Path(path)
        self.data: Dict[str, Any] = {
            "schema_version": SCHEMA_VERSION,
            "state": "initializing",
            "updated_at": _now(),
            "pid": os.getpid(),
            "project_dir": str(Path.cwd()),
            "api": {"providers": {}},
            "model": {"provider": None, "name": None},
            "counters": {"processed_requests": 0, "error_count": 0},
            "last_trigger": None,
            "last_error": None,
        }

    def update(self, **fields: Any) -> None:
        self.data.update(fields)
        self.data["updated_at"] = _now()
        self.write()

    def set_api_status(self, config_manager: Any) -> None:
        providers: Dict[str, Dict[str, Any]] = {}
        api_config = {}
        if config_manager:
            try:
                api_config = config_manager.get("api", {})
            except Exception:
                api_config = getattr(config_manager, "config_data", {}).get("api", {})
        if isinstance(api_config, dict):
            for provider, config in api_config.items():
                if not isinstance(config, dict):
                    continue
                key = str(config.get("key") or "")
                providers[str(provider)] = {
                    "configured": bool(key.strip()),
                    "base_url": config.get("base_url"),
                    "model": config.get("model"),
                }

        self.data["api"] = {"providers": providers}

        preferred_provider = None
        for provider, config in providers.items():
            if config.get("configured"):
                preferred_provider = provider
                break
        if preferred_provider:
            self.data["model"] = {
                "provider": preferred_provider,
                "name": providers[preferred_provider].get("model"),
            }
        self.update()

    def set_trigger_started(self, template_name: str) -> None:
        self.update(
            state="processing",
            last_trigger={
                "time": _now(),
                "template": template_name,
                "status": "running",
                "success": None,
                "error_type": None,
                "error": None,
                "response_time": None,
                "model": None,
            },
        )

    def set_trigger_result(self, template_name: str, result: Dict[str, Any]) -> None:
        error = result.get("error")
        success = bool(result.get("success"))
        error_type = None if success else classify_error(error)
        model = result.get("api_model_name") or result.get("model_name")
        trigger = {
            "time": _now(),
            "template": template_name,
            "status": "success" if success else "error",
            "success": success,
            "error_type": error_type,
            "error": error,
            "response_time": result.get("response_time"),
            "model": model,
        }
        fields: Dict[str, Any] = {
            "state": "running",
            "last_trigger": trigger,
        }
        if model:
            fields["model"] = {"provider": None, "name": model}
        if not success:
            fields["last_error"] = {
                "time": trigger["time"],
                "type": error_type,
                "message": error,
            }
        self.update(**fields)

    def set_error(self, message: str, error_type: Optional[str] = None) -> None:
        self.update(
            state="error",
            last_error={
                "time": _now(),
                "type": error_type or classify_error(message),
                "message": message,
            },
        )

    def write(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            payload = json.dumps(self.data, ensure_ascii=False, indent=2, sort_keys=True)
            with tempfile.NamedTemporaryFile(
                "w",
                encoding="utf-8",
                dir=str(self.path.parent),
                prefix=f".{self.path.name}.",
                delete=False,
            ) as handle:
                handle.write(payload)
                handle.write("\n")
                temp_name = handle.name
            os.replace(temp_name, self.path)
        except Exception:
            # Runtime status must never break hotkey handling.
            return
