from __future__ import annotations

import os
from urllib.parse import urlsplit, urlunsplit

_DOCKER_LOCAL_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0", "172.17.0.1"}


def running_in_container() -> bool:
    return os.path.exists("/.dockerenv")


def rewrite_container_host_url(url: str, gateway_host: str | None = None) -> str:
    if not url or not running_in_container():
        return url

    parts = urlsplit(url)
    if not parts.hostname or parts.hostname not in _DOCKER_LOCAL_HOSTS:
        return url

    gateway_host = gateway_host or os.getenv("STUDY_AGENT_HOST_GATEWAY", "host.docker.internal")
    if not gateway_host:
        return url

    auth = ""
    if parts.username:
        auth = parts.username
        if parts.password:
            auth = f"{auth}:{parts.password}"
        auth = f"{auth}@"

    port = f":{parts.port}" if parts.port is not None else ""
    netloc = f"{auth}{gateway_host}{port}"
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))
