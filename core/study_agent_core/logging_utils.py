from __future__ import annotations

import logging
import os
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Literal


_LEVELS = {
    "CRITICAL": logging.CRITICAL,
    "ERROR": logging.ERROR,
    "WARN": logging.WARNING,
    "WARNING": logging.WARNING,
    "INFO": logging.INFO,
    "DEBUG": logging.DEBUG,
    "NOTSET": logging.NOTSET,
    "OFF": logging.CRITICAL + 10,
}


def _parse_level(value: str | None, default: str) -> int:
    return _LEVELS.get(str(value or default).strip().upper(), _LEVELS[default])


def _truthy_env(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() not in ("0", "false", "no", "off", "")


def _resolve_log_path(service_name: str, default_filename: str) -> Path | None:
    explicit = (os.getenv(f"{service_name}_LOG_FILE") or "").strip()
    if explicit:
        return Path(explicit).expanduser()

    log_dir = (os.getenv("STUDY_AGENT_LOG_DIR") or "").strip()
    if not log_dir:
        return None
    return Path(log_dir).expanduser() / default_filename


def _close_handlers(logger: logging.Logger) -> None:
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
        try:
            handler.close()
        except Exception:
            pass


def configure_service_logger(
    service_name: str,
    logger_name: str,
    *,
    default_level: str = "INFO",
    stream: Literal["stdout", "stderr"] = "stderr",
    default_filename: str,
) -> logging.Logger:
    logger = logging.getLogger(logger_name)
    _close_handlers(logger)
    logger.propagate = False
    logger.disabled = False

    level = _parse_level(
        os.getenv(f"{service_name}_LOG_LEVEL") or os.getenv("STUDY_AGENT_LOG_LEVEL"),
        default_level,
    )
    logger.setLevel(logging.DEBUG)

    if level >= _LEVELS["OFF"]:
        logger.disabled = True
        return logger

    formatter = logging.Formatter(
        fmt="%(asctime)s %(levelname)s %(name)s > %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    if _truthy_env(f"{service_name}_LOG_TO_CONSOLE", True):
        console_handler = logging.StreamHandler(sys.stdout if stream == "stdout" else sys.stderr)
        console_handler.setLevel(level)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    log_path = _resolve_log_path(service_name, default_filename)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        max_bytes = int(os.getenv("STUDY_AGENT_LOG_MAX_BYTES", str(10 * 1024 * 1024)))
        backup_count = int(os.getenv("STUDY_AGENT_LOG_BACKUP_COUNT", "5"))
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=max_bytes,
            backupCount=backup_count,
            encoding="utf-8",
        )
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger

