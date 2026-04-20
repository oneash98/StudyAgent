from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any, Dict, Iterable

from study_agent_core.net import rewrite_container_host_url

from ._common import with_meta


def resolve_service_base_url(service_prefix: str) -> str:
    explicit = (
        os.getenv(f"{service_prefix}_BASE_URL")
        or os.getenv(f"{service_prefix}_URL")
        or ""
    ).strip()
    if explicit:
        return rewrite_container_host_url(explicit.rstrip("/"))

    host = (os.getenv(f"{service_prefix}_HOST") or "").strip()
    port = (os.getenv(f"{service_prefix}_PORT") or "").strip()
    if not host or not port:
        return ""

    scheme = (os.getenv(f"{service_prefix}_SCHEME") or "http").strip() or "http"
    prefix = (os.getenv(f"{service_prefix}_API_PREFIX") or "").strip().strip("/")
    base = f"{scheme}://{host}:{port}"
    if prefix:
        base = f"{base}/{prefix}"
    return rewrite_container_host_url(base.rstrip("/"))


def resolve_service_token(service_prefix: str) -> str:
    return (
        os.getenv(f"{service_prefix}_TOKEN")
        or os.getenv(f"{service_prefix}_API_TOKEN")
        or os.getenv(f"{service_prefix}_BEARER_TOKEN")
        or ""
    ).strip()


def resolve_service_timeout(service_prefix: str, default: int = 20) -> int:
    raw = (os.getenv(f"{service_prefix}_TIMEOUT") or "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def unavailable_result(tool_name: str, error: str, detail: str = "") -> Dict[str, Any]:
    payload = {"status": "unavailable", "error": error}
    if detail:
        payload["detail"] = detail
    return with_meta(payload, tool_name)


def post_json_service(
    *,
    tool_name: str,
    service_prefix: str,
    path: str,
    payload: Dict[str, Any],
    allowed_statuses: Iterable[str],
    require_auth: bool = False,
) -> Dict[str, Any]:
    allowed = set(allowed_statuses)
    base_url = resolve_service_base_url(service_prefix)
    if not base_url:
        return unavailable_result(tool_name, f"{service_prefix.lower()}_unconfigured")

    token = resolve_service_token(service_prefix)
    if require_auth and not token:
        return unavailable_result(tool_name, f"{service_prefix.lower()}_auth_unconfigured")

    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(f"{base_url}{path}", data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")

    timeout = resolve_service_timeout(service_prefix)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = None
        if isinstance(parsed, dict) and parsed.get("status") in allowed:
            return with_meta(parsed, tool_name)
        return unavailable_result(tool_name, f"http_{exc.code}", raw[:400])
    except urllib.error.URLError as exc:
        return unavailable_result(tool_name, "transport_error", str(exc))
    except TimeoutError as exc:
        return unavailable_result(tool_name, "timeout", str(exc))

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return unavailable_result(tool_name, "invalid_json", raw[:400])
    if not isinstance(parsed, dict):
        return unavailable_result(tool_name, "invalid_payload", type(parsed).__name__)
    if parsed.get("status") not in allowed:
        return unavailable_result(tool_name, "unexpected_status", str(parsed.get("status") or "missing"))
    return with_meta(parsed, tool_name)
