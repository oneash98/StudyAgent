from __future__ import annotations

import logging
import os
from typing import Any

from study_agent_core.logging_utils import format_log_kv

logger = logging.getLogger("study_agent.mcp")


def _level_enabled(level: str) -> bool:
    configured = os.getenv("MCP_LOG_LEVEL", "INFO").upper()
    levels = {"DEBUG": 10, "INFO": 20, "WARN": 30, "WARNING": 30, "ERROR": 40, "OFF": 100}
    if levels.get(level, 20) < levels.get(configured, 20):
        return False
    if levels.get(configured, 20) >= levels["OFF"]:
        return False
    return True


def log_debug(message: str, **fields: Any) -> None:
    if not _level_enabled("DEBUG"):
        return
    if fields:
        logger.debug("%s %s", message, format_log_kv(fields))
    else:
        logger.debug("%s", message)
