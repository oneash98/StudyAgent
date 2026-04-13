import pytest

from study_agent_core import net


@pytest.mark.core
def test_rewrite_container_host_url_can_be_disabled(monkeypatch):
    monkeypatch.setattr(net, "running_in_container", lambda: True)
    monkeypatch.setenv("STUDY_AGENT_REWRITE_CONTAINER_HOSTS", "0")

    url = "http://127.0.0.1:3000/api/chat/completions"
    assert net.rewrite_container_host_url(url) == url


@pytest.mark.core
def test_rewrite_container_host_url_defaults_to_gateway(monkeypatch):
    monkeypatch.setattr(net, "running_in_container", lambda: True)
    monkeypatch.delenv("STUDY_AGENT_REWRITE_CONTAINER_HOSTS", raising=False)
    monkeypatch.setenv("STUDY_AGENT_HOST_GATEWAY", "host.docker.internal")

    assert (
        net.rewrite_container_host_url("http://127.0.0.1:3000/api/chat/completions")
        == "http://host.docker.internal:3000/api/chat/completions"
    )
