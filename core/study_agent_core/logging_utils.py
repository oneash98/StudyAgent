from __future__ import annotations

import logging
import os
import re
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Literal


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

_SENSITIVE_KEY_NAMES = (
    "password",
    "passwd",
    "pwd",
    "secret",
    "token",
    "api_key",
    "apikey",
    "access_key",
    "access_token",
    "refresh_token",
    "authorization",
    "bearer",
    "dsn",
    "connection_string",
    "database_url",
    "person_id",
    "personid",
    "patient_id",
    "subject_id",
    "visit_id",
    "mrn",
    "medical_record_number",
)

_URI_CREDENTIALS_RE = re.compile(r"([a-z][a-z0-9+.\-]*://)([^/\s:@]+)(?::([^@/\s]*))?@", re.IGNORECASE)
_BEARER_RE = re.compile(r"\b(Bearer)\s+[A-Za-z0-9._~+/=-]+\b", re.IGNORECASE)
_KV_SECRET_RE = re.compile(
    r"(?i)\b(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?token|refresh[_-]?token|authorization)\b"
    r"(\s*[:=]\s*)([^\s,;]+)"
)
_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_PHONE_RE = re.compile(r"\b\+?\d{1,2}[\s.-]?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b")
_DATE_RE = re.compile(r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}-\d{1,2}-\d{1,2}\b")
_SSN_RE = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
_MRN_RE = re.compile(r"(?i)\b(mrn|medical_record_number|person_id|personid|subject_id|patient_id)\b(\s*[:=]\s*)([^\s,;]+)")


def _sanitize_string(text: str) -> str:
    value = str(text)
    value = _URI_CREDENTIALS_RE.sub(r"\1[REDACTED_CREDENTIALS]@", value)
    value = _BEARER_RE.sub(r"\1 [REDACTED_TOKEN]", value)
    value = _KV_SECRET_RE.sub(r"\1\2[REDACTED]", value)
    value = _EMAIL_RE.sub("[REDACTED_EMAIL]", value)
    value = _PHONE_RE.sub("[REDACTED_PHONE]", value)
    value = _DATE_RE.sub("[REDACTED_DATE]", value)
    value = _SSN_RE.sub("[REDACTED_SSN]", value)
    value = _MRN_RE.sub(r"\1\2[REDACTED_ID]", value)
    return value


def _is_sensitive_key(key: Any) -> bool:
    key_norm = re.sub(r"[^a-z0-9]+", "_", str(key).strip().lower()).strip("_")
    return key_norm in _SENSITIVE_KEY_NAMES


def _sanitize_field(key: Any, value: Any, depth: int) -> Any:
    if _is_sensitive_key(key):
        return "[REDACTED]"
    return sanitize_log_value(value, depth + 1)


def sanitize_log_value(value: Any, depth: int = 0) -> Any:
    if depth > 4:
        return _sanitize_string(repr(value))
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        return _sanitize_string(value)
    if isinstance(value, dict):
        sanitized: dict[Any, Any] = {}
        for key, inner in value.items():
            key_text = _sanitize_string(str(key))
            sanitized[key_text] = _sanitize_field(key, inner, depth)
        return sanitized
    if isinstance(value, tuple):
        return tuple(sanitize_log_value(item, depth + 1) for item in value)
    if isinstance(value, list):
        return [sanitize_log_value(item, depth + 1) for item in value]
    if isinstance(value, set):
        return {sanitize_log_value(item, depth + 1) for item in value}
    return _sanitize_string(str(value))


def format_log_kv(fields: dict[str, Any]) -> str:
    parts = []
    for key in sorted(fields):
        parts.append(f"{key}={_sanitize_field(key, fields[key], 0)}")
    return " ".join(parts)


class SensitiveDataFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = sanitize_log_value(record.msg)
        if isinstance(record.args, dict):
            record.args = {key: sanitize_log_value(value) for key, value in record.args.items()}
        elif isinstance(record.args, tuple):
            record.args = tuple(sanitize_log_value(value) for value in record.args)
        elif record.args:
            record.args = sanitize_log_value(record.args)
        return True


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
        console_handler.addFilter(SensitiveDataFilter())
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
        file_handler.addFilter(SensitiveDataFilter())
        logger.addHandler(file_handler)

    return logger
