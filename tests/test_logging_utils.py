import logging

from study_agent_core.logging_utils import configure_service_logger


def test_configure_service_logger_writes_to_file(tmp_path, monkeypatch):
    log_dir = tmp_path / "logs"
    monkeypatch.setenv("STUDY_AGENT_LOG_DIR", str(log_dir))
    monkeypatch.setenv("ACP_LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("ACP_LOG_TO_CONSOLE", "0")

    logger = configure_service_logger(
        "ACP",
        "study_agent.test.acp",
        default_level="INFO",
        stream="stderr",
        default_filename="study-agent-acp.log",
    )
    logger.info("hello file logger")

    log_file = log_dir / "study-agent-acp.log"
    assert log_file.exists()
    assert "hello file logger" in log_file.read_text(encoding="utf-8")


def test_configure_service_logger_off_disables_logger(monkeypatch):
    monkeypatch.setenv("ACP_LOG_LEVEL", "OFF")

    logger = configure_service_logger(
        "ACP",
        "study_agent.test.acp.off",
        default_level="INFO",
        stream="stderr",
        default_filename="study-agent-acp.log",
    )

    assert logger.disabled is True
    assert logger.handlers == []

    logger.disabled = False
    logger.handlers.clear()
    logging.getLogger("study_agent.test.acp.off").handlers.clear()
