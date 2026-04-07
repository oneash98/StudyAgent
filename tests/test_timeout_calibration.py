import pytest

from study_agent_acp.timeout_calibration import (
    calibrate_timeout_recommendations,
    parse_embed_debug_seconds,
    percentile,
    recommend_timeout,
    render_env_fragment,
)


@pytest.mark.acp
def test_percentile_interpolates():
    assert percentile([1.0, 2.0, 3.0, 4.0], 50) == pytest.approx(2.5)


@pytest.mark.acp
def test_parse_embed_debug_seconds():
    log_text = """
EMBED DEBUG > url=http://x model=m timeout=120 texts=1 seconds=2.34
EMBED DEBUG > url=http://x model=m timeout=120 texts=1 seconds=3.21
"""
    assert parse_embed_debug_seconds(log_text) == [2.34, 3.21]


@pytest.mark.acp
def test_recommend_timeout_uses_margin():
    assert recommend_timeout([10.0, 12.0, 14.0], minimum=5, p95_multiplier=1.5, max_multiplier=1.25, pad_seconds=10) >= 28


@pytest.mark.acp
def test_calibrate_timeout_recommendations():
    runs = [
        {
            "flow": "phenotype_intent_split",
            "wall_seconds": 10.0,
            "diagnostics": {"llm_duration_seconds": 8.0, "llm_status": "ok"},
        },
        {
            "flow": "phenotype_recommendation",
            "wall_seconds": 18.0,
            "fallback_reason": None,
            "diagnostics": {"llm_duration_seconds": 12.0, "llm_status": "ok"},
        },
        {
            "flow": "phenotype_recommendation_advice",
            "wall_seconds": 9.0,
            "fallback_reason": "llm_json_parse_failed",
            "diagnostics": {"llm_duration_seconds": 7.0, "llm_status": "json_parse_failed"},
        },
    ]
    calibration = calibrate_timeout_recommendations(runs, embed_seconds=[2.5, 3.5])
    env = calibration["recommended_env"]
    assert env["ACP_TIMEOUT"] > env["LLM_TIMEOUT"] > 0
    assert env["STUDY_AGENT_MCP_TIMEOUT"] >= env["EMBED_TIMEOUT"]
    assert calibration["llm_failures"] == [
        {
            "flow": "phenotype_recommendation_advice",
            "llm_status": "json_parse_failed",
            "fallback_reason": "llm_json_parse_failed",
        }
    ]
    env_text = render_env_fragment(calibration)
    assert "LLM_TIMEOUT=" in env_text
    assert "ACP_TIMEOUT=" in env_text
