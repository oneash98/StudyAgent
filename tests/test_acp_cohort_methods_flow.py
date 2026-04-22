import json
from typing import Any, Dict, Optional
from unittest.mock import MagicMock

import pytest

from study_agent_acp.agent import StudyAgent


pytestmark = pytest.mark.acp


def _annotated_template() -> str:
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.abspath(os.path.join(here, "..", "theseus", "customAtlasTemplate_v1.3.0_annotated.txt"))
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def _defaults_spec() -> Dict[str, Any]:
    import re
    stripped = re.sub(r"/\*.*?\*/", "", _annotated_template(), flags=re.DOTALL)
    return json.loads(stripped)


def _make_bundle_payload() -> Dict[str, Any]:
    return {
        "status": "ok",
        "full_result": {
            "instruction_template": "<Instruction>...</Instruction>",
            "output_style_template": "<Output Style>...</Output Style>",
            "annotated_template": _annotated_template(),
            "defaults_spec": _defaults_spec(),
            "schema_version": "v1.3.0",
        },
    }


def _make_llm_result(content: Dict[str, Any], status: str = "ok") -> MagicMock:
    m = MagicMock()
    m.status = status
    m.duration_seconds = 1.23
    m.error = None
    m.parse_stage = "ok" if status == "ok" else "json_decode_failed"
    m.schema_valid = True if status == "ok" else False
    m.request_mode = "structured"
    m.missing_keys = []
    m.raw_response = json.dumps(content) if status == "ok" else "<bad>"
    m.content_text = m.raw_response
    m.parsed_payload = content if status == "ok" else None
    return m


def _valid_llm_payload(defaults: Dict[str, Any]) -> Dict[str, Any]:
    spec = json.loads(json.dumps(defaults))
    spec["name"] = "Example"
    spec["createStudyPopArgs"]["washoutPeriod"] = 365
    return {
        "specifications": spec,
        "sectionRationales": {
            "getDbCohortMethodDataArgs":  {"rationale": "ok", "confidence": "medium"},
            "createStudyPopArgs":         {"rationale": "washout lengthened", "confidence": "high"},
            "propensityScoreAdjustment":  {"rationale": "defaults", "confidence": "medium"},
            "fitOutcomeModelArgs":        {"rationale": "defaults", "confidence": "medium"},
        },
    }


def _build_agent_with_mocks(bundle_payload: Dict[str, Any], llm_result) -> StudyAgent:
    agent = StudyAgent.__new__(StudyAgent)  # bypass __init__ network setup
    agent._mcp_client = MagicMock()
    agent.call_tool = MagicMock(return_value=bundle_payload)
    agent._call_llm = MagicMock(return_value=llm_result)
    agent.debug = False
    return agent


def test_happy_path_returns_ok_with_specifications() -> None:
    defaults = _defaults_spec()
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(_valid_llm_payload(defaults)))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="compare A vs B with 1-year washout",
        cohort_definitions={"targetCohort": {"id": 1, "name": "T"}, "comparatorCohort": {"id": 2, "name": "C"}, "outcomeCohort": [{"id": 3, "name": "O"}]},
        negative_control_concept_set={"id": 99, "name": "NC"},
        covariate_selection={"conceptsToInclude": [], "conceptsToExclude": []},
    )
    assert result["status"] == "ok"
    assert result["specifications"]["cohortDefinitions"]["targetCohort"]["id"] == 1
    assert result["specifications"]["negativeControlConceptSet"]["id"] == 99
    assert result["specifications"]["createStudyPopArgs"]["washoutPeriod"] == 365
    assert "sectionRationales" in result
    assert result["sectionRationales"]["createStudyPopArgs"]["confidence"] == "high"


def test_client_cohort_ids_override_llm_drift() -> None:
    defaults = _defaults_spec()
    drifted = _valid_llm_payload(defaults)
    drifted["specifications"]["cohortDefinitions"] = {"targetCohort": {"id": 666, "name": "LLM drifted"}}
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(drifted))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
        cohort_definitions={"targetCohort": {"id": 1, "name": "Real"}, "comparatorCohort": {"id": 2, "name": "C"}, "outcomeCohort": [{"id": 3, "name": "O"}]},
    )
    assert result["specifications"]["cohortDefinitions"]["targetCohort"]["id"] == 1
    assert result["specifications"]["cohortDefinitions"]["targetCohort"]["name"] == "Real"


def test_llm_parse_error_returns_defaults_fallback() -> None:
    defaults = _defaults_spec()
    bad = _make_llm_result({}, status="error")
    bad.parsed_payload = None
    bad.raw_response = "this is not json"
    agent = _build_agent_with_mocks(_make_bundle_payload(), bad)
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
    )
    assert result["status"] == "llm_parse_error"
    assert result["specifications"]["name"] == defaults["name"]
    assert result["diagnostics"]["llm_parse_stage"] in {"json_extract_failed", "json_decode_failed"}


def test_section_schema_violation_backfills_with_low_confidence() -> None:
    defaults = _defaults_spec()
    payload = _valid_llm_payload(defaults)
    payload["specifications"]["fitOutcomeModelArgs"] = {"modelType": "svm", "stratified": False, "useCovariates": False, "inversePtWeighting": False, "prior": None, "control": None}
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(payload))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
    )
    assert result["status"] == "ok"
    assert "fitOutcomeModelArgs" in result["diagnostics"]["failed_sections"]
    assert result["specifications"]["fitOutcomeModelArgs"]["modelType"] == "cox"
    assert result["sectionRationales"]["fitOutcomeModelArgs"]["confidence"] == "low"


def test_missing_description_errors_out() -> None:
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result({}))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="",
    )
    assert result["status"] == "llm_parse_error"  # treated as invalid request → fallback to defaults
    assert "analytic_settings_description" in json.dumps(result["diagnostics"])


def test_mcp_bundle_failure_raises() -> None:
    bundle_fail = {"status": "error", "error": "bundle unavailable"}
    agent = _build_agent_with_mocks(bundle_fail, _make_llm_result({}))
    with pytest.raises(RuntimeError):
        agent.run_cohort_methods_specs_recommendation_flow(
            analytic_settings_description="desc",
        )
