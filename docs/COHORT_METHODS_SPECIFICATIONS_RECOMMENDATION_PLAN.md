# Cohort Methods Specifications Recommendation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-align the existing `/flows/cohort_methods_specifications_recommendation` ACP flow, its Pydantic envelope, and the standalone R wrapper to the wire contract the cohort-methods `strategus_cohort_methods_shell.R` already sends and parses. Preserve our cohort-methods spec validation, metadata merge, and per-section backfill as internal pipeline steps.

**Architecture:** Inputs become flat (`target_cohort_id`, `comparator_cohort_id`, `outcome_cohort_ids`, `comparison_label`, `defaults_snapshot`, plus the existing description fields). The LLM is steered by the MCP-owned `cmAnalysis_template.json` and field descriptions from `CM_ANALYSIS_TEMPLATE.md`. After validation/backfill, `cohort_methods_spec_to_shell_recommendation()` projects the cmAnalysis-shaped spec into the shell's flat 4-key recommendation shape (`study_population`, `time_at_risk`, `propensity_score_adjustment`, `outcome_model`). The validated spec survives in the response under the legacy `cohort_methods_specifications` field for traceability. The cohort-methods R shell is **not** modified.

**Tech Stack:** Python 3.12 (pydantic v2, pytest with markers `core`/`mcp`/`acp`), an existing FastMCP-style MCP server, a plain `BaseHTTPRequestHandler` ACP server, and R 4.x (httr + jsonlite, `.acp_post` / `acp_state` helpers).

**Spec:** `docs/COHORT_METHODS_SPECIFICATIONS_RECOMMENDATION_DESIGN.md` (shell-contract revision).

**Template assets:** `mcp_server/prompts/cohort_methods/cmAnalysis_template.json` and `mcp_server/prompts/cohort_methods/CM_ANALYSIS_TEMPLATE.md`.

---

## Task 1: Pydantic Envelope Models — Flat Input, shell-shaped Output

**Files:**
- Modify: `core/study_agent_core/models.py:276-293`
- Modify: `tests/test_cohort_methods_specs_models.py`

- [ ] **Step 1: Replace the failing fixtures**

Overwrite `tests/test_cohort_methods_specs_models.py` with:

```python
import pytest

from study_agent_core.models import (
    CohortMethodSpecsRecommendationInput,
    CohortMethodSpecsRecommendationOutput,
)


pytestmark = pytest.mark.core


def test_input_requires_description() -> None:
    with pytest.raises(Exception):
        CohortMethodSpecsRecommendationInput()  # type: ignore[call-arg]


def test_input_accepts_minimal_payload() -> None:
    payload = CohortMethodSpecsRecommendationInput(
        analytic_settings_description="compare A vs B",
    )
    assert payload.analytic_settings_description == "compare A vs B"
    assert payload.study_intent == ""
    assert payload.study_description is None
    assert payload.target_cohort_id is None
    assert payload.comparator_cohort_id is None
    assert payload.outcome_cohort_ids == []
    assert payload.comparison_label is None
    assert payload.defaults_snapshot == {}


def test_input_accepts_full_shell_body() -> None:
    payload = CohortMethodSpecsRecommendationInput(
        analytic_settings_description="365-day washout, 1:1 PS match, Cox",
        study_description="365-day washout, 1:1 PS match, Cox",
        study_intent="CV outcomes comparative effectiveness",
        target_cohort_id=1001,
        comparator_cohort_id=1002,
        outcome_cohort_ids=[2001, 2002],
        comparison_label="Sitagliptin vs Glipizide",
        defaults_snapshot={"profile_name": "default", "input_method": "typed_text"},
    )
    assert payload.target_cohort_id == 1001
    assert payload.outcome_cohort_ids == [2001, 2002]
    assert payload.defaults_snapshot["input_method"] == "typed_text"


def test_output_defaults() -> None:
    out = CohortMethodSpecsRecommendationOutput(status="ok")
    assert out.status == "ok"
    assert out.recommendation == {}
    assert out.cohort_methods_specifications is None
    assert out.section_rationales == {}
    assert out.diagnostics == {}


def test_output_rejects_unknown_status() -> None:
    with pytest.raises(Exception):
        CohortMethodSpecsRecommendationOutput(status="stub")  # type: ignore[arg-type]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_cohort_methods_specs_models.py`

Expected: FAIL — old model has `current_specifications`, `cohort_definitions`, `negative_control_concept_set`, `covariate_selection`, `sectionRationales` (camelCase) instead of new flat fields.

- [ ] **Step 3: Replace the model definitions**

In `core/study_agent_core/models.py`, replace lines 276–293 (the existing `CohortMethodSpecsRecommendationInput`, `CohortMethodSpecsStatus`, and `CohortMethodSpecsRecommendationOutput` definitions) with:

```python
class CohortMethodSpecsRecommendationInput(BaseModel):
    analytic_settings_description: str
    study_intent: Optional[str] = ""
    study_description: Optional[str] = None
    target_cohort_id: Optional[int] = None
    comparator_cohort_id: Optional[int] = None
    outcome_cohort_ids: List[int] = Field(default_factory=list)
    comparison_label: Optional[str] = None
    defaults_snapshot: Dict[str, Any] = Field(default_factory=dict)
    llm_result: Optional[Dict[str, Any]] = None


CohortMethodSpecsStatus = Literal["ok", "llm_parse_error", "schema_validation_error"]


class CohortMethodSpecsRecommendationOutput(BaseModel):
    status: CohortMethodSpecsStatus
    recommendation: Dict[str, Any] = Field(default_factory=dict)
    cohort_methods_specifications: Optional[Dict[str, Any]] = None
    section_rationales: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    diagnostics: Dict[str, Any] = Field(default_factory=dict)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q tests/test_cohort_methods_specs_models.py`

Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
git add core/study_agent_core/models.py tests/test_cohort_methods_specs_models.py
git commit -m "$(cat <<'EOF'
refactor(core): align cohort methods specs envelope with R shell contract

Replace nested cohort_definitions/concept-set fields with the flat IDs
sent by the cohort-methods R shell; replace cohort-methods spec-shaped output
with the recommendation/cohort_methods_specifications/section_rationales triple
the shell already parses.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: cohort-methods spec → Shell Recommendation Helper

**Files:**
- Modify: `core/study_agent_core/cohort_methods_spec_validation.py`
- Modify: `tests/test_cohort_methods_spec_validation.py`

- [ ] **Step 1: Append failing tests**

Append the following to the end of `tests/test_cohort_methods_spec_validation.py`:

```python
from study_agent_core.cohort_methods_spec_validation import cohort_methods_spec_to_shell_recommendation


def _full_spec_with_tar() -> dict:
    spec = _minimal_valid_spec()
    spec["createStudyPopArgs"]["washoutPeriod"] = 365
    spec["createStudyPopArgs"]["startAnchor"] = "cohort start"
    spec["createStudyPopArgs"]["riskWindowStart"] = 1
    spec["createStudyPopArgs"]["endAnchor"] = "cohort end"
    spec["createStudyPopArgs"]["riskWindowEnd"] = 365
    return spec


def test_cohort_methods_spec_to_shell_separates_tar_keys() -> None:
    spec = _full_spec_with_tar()
    out = cohort_methods_spec_to_shell_recommendation(
        cohort_methods_spec=spec,
        raw_description="desc",
        defaults_snapshot={"x": 1},
        profile_name="P",
        input_method="typed_text",
        rec_status="received",
    )
    assert out["mode"] == "free_text"
    assert out["source"] == "acp_flow"
    assert out["status"] == "received"
    assert out["profile_name"] == "P"
    assert out["raw_description"] == "desc"
    assert out["defaults_snapshot"] == {"x": 1}
    tar = out["time_at_risk"]
    assert tar["startAnchor"] == "cohort start"
    assert tar["riskWindowStart"] == 1
    assert tar["endAnchor"] == "cohort end"
    assert tar["riskWindowEnd"] == 365
    sp = out["study_population"]
    assert "startAnchor" not in sp
    assert "riskWindowStart" not in sp
    assert sp["washoutPeriod"] == 365
    assert sp["cohortMethodDataArgs"] == spec["getDbCohortMethodDataArgs"]
    assert out["propensity_score_adjustment"] == spec["propensityScoreAdjustment"]
    assert out["outcome_model"] == spec["fitOutcomeModelArgs"]
    assert out["deferred_inputs"]["function_argument_description"] == "implemented"


def test_cohort_methods_spec_to_shell_honors_rec_status_backfilled() -> None:
    out = cohort_methods_spec_to_shell_recommendation(
        cohort_methods_spec=_minimal_valid_spec(),
        raw_description="d",
        defaults_snapshot={},
        profile_name="X",
        input_method="description_argument",
        rec_status="backfilled",
    )
    assert out["status"] == "backfilled"
    assert out["input_method"] == "description_argument"


def test_cohort_methods_spec_to_shell_handles_missing_sections() -> None:
    out = cohort_methods_spec_to_shell_recommendation(
        cohort_methods_spec={},
        raw_description="d",
        defaults_snapshot={},
        profile_name="X",
        input_method="typed_text",
        rec_status="received",
    )
    assert out["study_population"] == {}
    assert out["time_at_risk"] == {}
    assert out["propensity_score_adjustment"] == {}
    assert out["outcome_model"] == {}


def test_cohort_methods_spec_to_shell_does_not_mutate_input() -> None:
    spec = _full_spec_with_tar()
    snapshot = {"profile_name": "snap"}
    out = cohort_methods_spec_to_shell_recommendation(
        cohort_methods_spec=spec,
        raw_description="d",
        defaults_snapshot=snapshot,
        profile_name="X",
        input_method="typed_text",
        rec_status="received",
    )
    out["study_population"]["washoutPeriod"] = 9999
    out["defaults_snapshot"]["profile_name"] = "mutated"
    assert spec["createStudyPopArgs"]["washoutPeriod"] == 365
    assert snapshot["profile_name"] == "snap"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_cohort_methods_spec_validation.py`

Expected: FAIL — `cohort_methods_spec_to_shell_recommendation` does not exist yet.

- [ ] **Step 3: Add the helper**

In `core/study_agent_core/cohort_methods_spec_validation.py`, append the following at the end of the file (after `backfill_section_from_defaults`):

```python
_TAR_KEYS: Tuple[str, ...] = ("startAnchor", "riskWindowStart", "endAnchor", "riskWindowEnd")


def cohort_methods_spec_to_shell_recommendation(
    *,
    cohort_methods_spec: Dict[str, Any],
    raw_description: str,
    defaults_snapshot: Dict[str, Any],
    profile_name: str,
    input_method: str,
    rec_status: str,
) -> Dict[str, Any]:
    """Project a validated cohort-methods spec spec into the 4-key recommendation shape the
    cohort-methods R shell expects.

    See docs/COHORT_METHODS_SPECIFICATIONS_RECOMMENDATION_DESIGN.md §6.
    """
    cspa = (cohort_methods_spec or {}).get("createStudyPopArgs") or {}
    cmda = (cohort_methods_spec or {}).get("getDbCohortMethodDataArgs") or {}
    psadj = (cohort_methods_spec or {}).get("propensityScoreAdjustment") or {}
    fmod = (cohort_methods_spec or {}).get("fitOutcomeModelArgs") or {}

    study_population: Dict[str, Any] = {
        k: deepcopy(v) for k, v in cspa.items() if k not in _TAR_KEYS
    }
    if cmda:
        study_population["cohortMethodDataArgs"] = deepcopy(cmda)

    time_at_risk: Dict[str, Any] = {
        k: deepcopy(cspa[k]) for k in _TAR_KEYS if k in cspa
    }

    return {
        "mode": "free_text",
        "input_method": input_method,
        "source": "acp_flow",
        "status": rec_status,
        "profile_name": profile_name,
        "raw_description": raw_description,
        "study_population": study_population,
        "time_at_risk": time_at_risk,
        "propensity_score_adjustment": deepcopy(psadj),
        "outcome_model": deepcopy(fmod),
        "deferred_inputs": {
            "function_argument_description": "implemented",
            "description_file_path": "implemented",
            "interactive_typed_description": "implemented",
        },
        "defaults_snapshot": deepcopy(defaults_snapshot or {}),
    }
```

Also at the top of the file, change the typing import from `from typing import Any, Dict, List, Tuple` if `Tuple` is not already there. Verify by reading the existing import.

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q tests/test_cohort_methods_spec_validation.py`

Expected: previous tests still pass plus 4 new tests pass — total of 14 (or 15 depending on baseline).

- [ ] **Step 5: Commit**

```bash
git add core/study_agent_core/cohort_methods_spec_validation.py tests/test_cohort_methods_spec_validation.py
git commit -m "$(cat <<'EOF'
feat(core): add cohort_methods_spec_to_shell_recommendation projector

Pure helper that picks the four LLM-filled cohort-methods spec sections and projects
them into the cohort-methods R shell's 4-key recommendation shape, with
TAR fields routed to time_at_risk and getDbCohortMethodDataArgs nested
under study_population.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: ACP Flow Handler — Flat Input, shell-shaped Output

**Files:**
- Modify: `acp_agent/study_agent_acp/agent.py:411-576`
- Modify: `tests/test_acp_cohort_methods_flow.py`

- [ ] **Step 1: Replace the flow tests**

Overwrite `tests/test_acp_cohort_methods_flow.py` with:

```python
import json
from typing import Any, Dict
from unittest.mock import MagicMock

import pytest

from study_agent_acp.agent import StudyAgent


pytestmark = pytest.mark.acp


def _annotated_template() -> str:
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.abspath(os.path.join(here, "..", "mcp_server", "prompts", "cohort_methods", "cmAnalysis_template.json"))
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
    agent = StudyAgent.__new__(StudyAgent)
    agent._mcp_client = MagicMock()
    agent.call_tool = MagicMock(return_value=bundle_payload)
    agent._call_llm = MagicMock(return_value=llm_result)
    agent.debug = False
    return agent


def test_happy_path_returns_shell_shape() -> None:
    defaults = _defaults_spec()
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(_valid_llm_payload(defaults)))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="compare A vs B with 1-year washout",
        target_cohort_id=1,
        comparator_cohort_id=2,
        outcome_cohort_ids=[3],
        comparison_label="A vs B",
        defaults_snapshot={"profile_name": "snapshot", "input_method": "typed_text"},
    )
    assert result["status"] == "ok"
    rec = result["recommendation"]
    assert rec["mode"] == "free_text"
    assert rec["source"] == "acp_flow"
    assert rec["status"] == "received"
    assert rec["profile_name"] == "Example"
    assert rec["raw_description"] == "compare A vs B with 1-year washout"
    assert rec["study_population"]["washoutPeriod"] == 365
    assert rec["defaults_snapshot"]["profile_name"] == "snapshot"
    assert "section_rationales" in result
    assert result["section_rationales"]["createStudyPopArgs"]["confidence"] == "high"
    assert result["cohort_methods_specifications"]["cohortDefinitions"]["targetCohort"]["id"] == 1


def test_client_cohort_ids_override_llm_drift() -> None:
    defaults = _defaults_spec()
    drifted = _valid_llm_payload(defaults)
    drifted["specifications"]["cohortDefinitions"] = {"targetCohort": {"id": 666, "name": "LLM drifted"}}
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(drifted))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
        target_cohort_id=1,
        comparator_cohort_id=2,
        outcome_cohort_ids=[3],
    )
    assert result["cohort_methods_specifications"]["cohortDefinitions"]["targetCohort"]["id"] == 1


def test_llm_parse_error_returns_defaults_fallback() -> None:
    bad = _make_llm_result({}, status="error")
    bad.parsed_payload = None
    bad.raw_response = "this is not json"
    agent = _build_agent_with_mocks(_make_bundle_payload(), bad)
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
    )
    assert result["status"] == "llm_parse_error"
    assert result["recommendation"]["status"] == "backfilled"
    assert result["diagnostics"]["llm_parse_stage"] in {"json_extract_failed", "json_decode_failed"}


def test_section_schema_violation_backfills_with_low_confidence() -> None:
    defaults = _defaults_spec()
    payload = _valid_llm_payload(defaults)
    payload["specifications"]["fitOutcomeModelArgs"] = {
        "modelType": "svm", "stratified": False, "useCovariates": False,
        "inversePtWeighting": False, "prior": None, "control": None,
    }
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result(payload))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="desc",
    )
    assert result["status"] == "ok"
    assert "fitOutcomeModelArgs" in result["diagnostics"]["failed_sections"]
    assert result["recommendation"]["status"] == "backfilled"
    assert result["recommendation"]["outcome_model"]["modelType"] == "cox"
    assert result["section_rationales"]["fitOutcomeModelArgs"]["confidence"] == "low"


def test_missing_description_errors_out() -> None:
    agent = _build_agent_with_mocks(_make_bundle_payload(), _make_llm_result({}))
    result = agent.run_cohort_methods_specs_recommendation_flow(
        analytic_settings_description="",
    )
    assert result["status"] == "llm_parse_error"
    assert "analytic_settings_description" in json.dumps(result["diagnostics"])


def test_mcp_bundle_failure_raises() -> None:
    bundle_fail = {"status": "error", "error": "bundle unavailable"}
    agent = _build_agent_with_mocks(bundle_fail, _make_llm_result({}))
    with pytest.raises(RuntimeError):
        agent.run_cohort_methods_specs_recommendation_flow(
            analytic_settings_description="desc",
        )
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_acp_cohort_methods_flow.py`

Expected: FAIL — old flow signature accepts `cohort_definitions=`/`negative_control_concept_set=`/`covariate_selection=`/`current_specifications=` and emits `specifications`/`sectionRationales` (camelCase) at top level.

- [ ] **Step 3: Replace the flow handler**

In `acp_agent/study_agent_acp/agent.py`, replace the entire `run_cohort_methods_specs_recommendation_flow` method (lines 411 through 576, ending just before `def run_phenotype_recommendation_advice_flow`) with:

```python
    def run_cohort_methods_specs_recommendation_flow(
        self,
        analytic_settings_description: str,
        study_intent: str = "",
        target_cohort_id: Optional[int] = None,
        comparator_cohort_id: Optional[int] = None,
        outcome_cohort_ids: Optional[List[int]] = None,
        comparison_label: Optional[str] = None,
        defaults_snapshot: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        import re as _re

        from study_agent_core.cohort_methods_spec_validation import (
            LLM_FILLED_SECTIONS,
            backfill_section_from_defaults,
            merge_client_metadata,
            cohort_methods_spec_to_shell_recommendation,
            validate_section,
            validate_cohort_methods_spec,
        )

        if self._mcp_client is None:
            raise RuntimeError("MCP client unavailable")

        bundle = self.call_tool(name="cohort_methods_prompt_bundle", arguments={})
        if bundle.get("status") != "ok":
            raise RuntimeError(f"cohort_methods_prompt_bundle failed: {bundle}")
        bundle_full = bundle.get("full_result") or {}
        defaults_spec: Dict[str, Any] = bundle_full.get("defaults_spec", {})
        analysis_template: str = (
            bundle_full.get("analysis_specifications_template")
            or bundle_full.get("annotated_template", "")
        )
        json_field_descriptions: str = bundle_full.get("json_field_descriptions", "")
        instruction: str = bundle_full.get("instruction_template", "")
        output_style: str = bundle_full.get("output_style_template", "")

        defaults_snapshot = defaults_snapshot or {}
        outcome_cohort_ids = list(outcome_cohort_ids or [])
        input_method = str(defaults_snapshot.get("input_method") or "typed_text")
        profile_name_default = "Recommended from free-text description"

        cohort_definitions: Dict[str, Any] = {}
        if target_cohort_id is not None:
            cohort_definitions["targetCohort"] = {"id": int(target_cohort_id), "name": ""}
        if comparator_cohort_id is not None:
            cohort_definitions["comparatorCohort"] = {"id": int(comparator_cohort_id), "name": ""}
        if outcome_cohort_ids:
            cohort_definitions["outcomeCohort"] = [{"id": int(cid), "name": ""} for cid in outcome_cohort_ids]

        diagnostics: Dict[str, Any] = {
            "llm_parse_stage": "ok",
            "schema_valid": True,
            "failed_sections": [],
            "latency_ms": 0,
        }

        def _fallback(status: str, *, reason: Optional[str] = None) -> Dict[str, Any]:
            merged_defaults = merge_client_metadata(
                defaults_spec,
                cohort_definitions=cohort_definitions,
                negative_control={},
                covariate_selection={},
            )
            recommendation = cohort_methods_spec_to_shell_recommendation(
                cohort_methods_spec=merged_defaults,
                raw_description=analytic_settings_description or "",
                defaults_snapshot=defaults_snapshot,
                profile_name=merged_defaults.get("description") or merged_defaults.get("name") or profile_name_default,
                input_method=input_method,
                rec_status="backfilled",
            )
            if reason:
                diagnostics["reason"] = reason
            diagnostics["schema_valid"] = False
            return {
                "status": status,
                "recommendation": recommendation,
                "cohort_methods_specifications": merged_defaults,
                "section_rationales": {s: {"rationale": "", "confidence": "low"} for s in LLM_FILLED_SECTIONS},
                "diagnostics": diagnostics,
            }

        if not analytic_settings_description or not analytic_settings_description.strip():
            diagnostics["llm_parse_stage"] = "json_extract_failed"
            return _fallback("llm_parse_error", reason="analytic_settings_description is required")

        prompt_parts = [
            instruction,
            "",
            "<Text>",
            analytic_settings_description.strip(),
            "</Text>",
            "",
            "<Study Intent>",
            (study_intent or "").strip(),
            "</Study Intent>",
            "",
            "<Analysis Specifications Template>",
            analysis_template,
            "</Analysis Specifications Template>",
            "",
            "<JSON Fields Descriptions>",
            json_field_descriptions,
            "</JSON Fields Descriptions>",
            "",
            output_style,
        ]
        prompt = "\n".join(prompt_parts)

        llm_result = self._call_llm(prompt, required_keys=["specifications", "sectionRationales"])
        diagnostics.update(self._llm_diagnostics(llm_result))

        payload: Optional[Dict[str, Any]] = getattr(llm_result, "parsed_payload", None)
        if payload is None and getattr(llm_result, "raw_response", None):
            match = _re.search(r"```json\s*(\{.*?\})\s*```", llm_result.raw_response or "", flags=_re.DOTALL)
            if match:
                try:
                    payload = json.loads(match.group(1))
                except Exception:
                    payload = None
                    diagnostics["llm_parse_stage"] = "json_decode_failed"
            else:
                diagnostics["llm_parse_stage"] = "json_extract_failed"

        if not isinstance(payload, dict) or "specifications" not in payload:
            return _fallback("llm_parse_error")

        spec = payload.get("specifications") or {}
        ok_top, missing = validate_cohort_methods_spec(spec)
        if not ok_top:
            diagnostics["llm_parse_stage"] = "schema_validation_failed"
            diagnostics["missing_keys"] = missing
            return _fallback("schema_validation_error")

        spec = merge_client_metadata(
            spec,
            cohort_definitions=cohort_definitions,
            negative_control={},
            covariate_selection={},
        )

        rationales_in = payload.get("sectionRationales") or {}
        rationales_out: Dict[str, Dict[str, Any]] = {}
        for section in LLM_FILLED_SECTIONS:
            incoming = rationales_in.get(section) if isinstance(rationales_in, dict) else None
            if isinstance(incoming, dict):
                rationales_out[section] = {
                    "rationale": str(incoming.get("rationale", "")),
                    "confidence": incoming.get("confidence", "low") if incoming.get("confidence") in {"high", "medium", "low"} else "low",
                }
            else:
                rationales_out[section] = {"rationale": "", "confidence": "low"}

            ok_sec, violations = validate_section(section, spec.get(section))
            if not ok_sec:
                spec = backfill_section_from_defaults(spec, defaults_spec, section)
                diagnostics["failed_sections"].append(section)
                rationales_out[section] = {
                    "rationale": (rationales_out[section].get("rationale") or "") + f" [backfilled: {'; '.join(violations)}]",
                    "confidence": "low",
                }

        rec_status = "backfilled" if diagnostics["failed_sections"] else "received"
        recommendation = cohort_methods_spec_to_shell_recommendation(
            cohort_methods_spec=spec,
            raw_description=analytic_settings_description,
            defaults_snapshot=defaults_snapshot,
            profile_name=spec.get("name") or profile_name_default,
            input_method=input_method,
            rec_status=rec_status,
        )
        return {
            "status": "ok",
            "recommendation": recommendation,
            "cohort_methods_specifications": spec,
            "section_rationales": rationales_out,
            "diagnostics": diagnostics,
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q tests/test_acp_cohort_methods_flow.py`

Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
git add acp_agent/study_agent_acp/agent.py tests/test_acp_cohort_methods_flow.py
git commit -m "$(cat <<'EOF'
refactor(acp): rewrite cohort_methods_specs flow for R shell contract

Take flat IDs from the R shell, build cohortDefinitions internally for
metadata merge, validate cohort-methods spec output, then project to the 4-key
recommendation shape via cohort_methods_spec_to_shell_recommendation. Internal
Validated spec and per-section rationales remain as response fields
for traceability.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: ACP Server Route — Pass New Field Names

**Files:**
- Modify: `acp_agent/study_agent_acp/server.py:285-312`

- [ ] **Step 1: Replace the route handler block**

In `acp_agent/study_agent_acp/server.py`, replace lines 285–312 (the entire `if self.path == "/flows/cohort_methods_specifications_recommendation":` block) with:

```python
        if self.path == "/flows/cohort_methods_specifications_recommendation":
            try:
                body = _read_json(self)
            except Exception as exc:
                _write_json(self, 400, {"error": f"invalid_json: {exc}"})
                return
            try:
                from study_agent_core.models import CohortMethodSpecsRecommendationInput
                payload = CohortMethodSpecsRecommendationInput(**body)
            except Exception as exc:
                _write_json(self, 422, {"error": f"invalid_payload: {exc}"})
                return
            try:
                result = self.agent.run_cohort_methods_specs_recommendation_flow(
                    analytic_settings_description=payload.analytic_settings_description,
                    study_intent=payload.study_intent or "",
                    target_cohort_id=payload.target_cohort_id,
                    comparator_cohort_id=payload.comparator_cohort_id,
                    outcome_cohort_ids=payload.outcome_cohort_ids,
                    comparison_label=payload.comparison_label,
                    defaults_snapshot=payload.defaults_snapshot,
                )
            except Exception as exc:
                if self.debug:
                    logger.exception("flow_failed name=cohort_methods_specifications_recommendation")
                _write_json(self, 500, {"error": "flow_failed", "detail": str(exc) if self.debug else None})
                return
            _write_json(self, 200, result)
            return
```

- [ ] **Step 2: Verify the route registration test still passes**

Run: `pytest -q tests/test_acp_cohort_methods_route.py`

Expected: 1 passed (the test only checks that `cohort_methods_specifications_recommendation` is in `SERVICES`).

- [ ] **Step 3: Verify Python syntax**

Run: `python -c "import study_agent_acp.server; print('ok')"`

Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add acp_agent/study_agent_acp/server.py
git commit -m "$(cat <<'EOF'
refactor(acp): wire flat cohort-methods specs fields through HTTP route

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: R Wrapper — Flat Contract

**Files:**
- Modify: `R/OHDSIAssistant/R/cohort_methods_workflow.R`

- [ ] **Step 1: Replace the wrapper file**

Overwrite `R/OHDSIAssistant/R/cohort_methods_workflow.R` with:

```r
#' Suggest cohort method study specifications from a free-text description.
#'
#' Calls the ACP flow `/flows/cohort_methods_specifications_recommendation`
#' and returns the cohort-methods recommendation, full analysis spec for
#' traceability, and per-section rationales. Falls back to a local stub
#' when `acp_state$url` is NULL.
#'
#' @param analyticSettingsDescription free-text description of the study design
#' @param targetCohortId optional integer cohort ID for the target arm
#' @param comparatorCohortId optional integer cohort ID for the comparator arm
#' @param outcomeCohortIds optional integer vector of outcome cohort IDs
#' @param comparisonLabel optional comparison label string
#' @param defaultsSnapshot optional list mirroring `effective_analytic_settings`
#' @param studyIntent optional protocol context string
#' @param interactive when TRUE, prints a section summary (default: TRUE)
#' @return list response from ACP flow or local stub
#' @export
suggestCohortMethodSpecs <- function(analyticSettingsDescription,
                                     targetCohortId = NULL,
                                     comparatorCohortId = NULL,
                                     outcomeCohortIds = NULL,
                                     comparisonLabel = NULL,
                                     defaultsSnapshot = NULL,
                                     studyIntent = NULL,
                                     interactive = TRUE) {
  if (is.null(analyticSettingsDescription) || !nzchar(trimws(analyticSettingsDescription))) {
    stop("Provide a non-empty analyticSettingsDescription.")
  }

  body <- list(
    analytic_settings_description = analyticSettingsDescription,
    study_description             = analyticSettingsDescription,
    study_intent                  = studyIntent %||% "",
    target_cohort_id              = if (is.null(targetCohortId)) NULL else as.integer(targetCohortId),
    comparator_cohort_id          = if (is.null(comparatorCohortId)) NULL else as.integer(comparatorCohortId),
    outcome_cohort_ids            = if (is.null(outcomeCohortIds)) list() else as.list(as.integer(outcomeCohortIds)),
    comparison_label              = comparisonLabel,
    defaults_snapshot             = defaultsSnapshot %||% list()
  )

  res <- if (!is.null(acp_state$url)) {
    .acp_post("/flows/cohort_methods_specifications_recommendation", body)
  } else {
    local_cohort_method_specs(body)
  }

  if (isTRUE(interactive)) {
    cat("\n== Cohort Method Specifications ==\n")
    cat("Status:", res$status %||% "(missing)", "\n")
    rec <- res$recommendation %||% list()
    if (length(rec) > 0) {
      cat("Profile:", rec$profile_name %||% "(none)", "\n")
      cat("Recommendation status:", rec$status %||% "(none)", "\n")
    }
    rats <- res$section_rationales %||% list()
    if (length(rats) > 0) {
      for (section in names(rats)) {
        entry <- rats[[section]]
        cat(sprintf("  - %s: confidence=%s  %s\n",
                    section,
                    entry$confidence %||% "?",
                    entry$rationale %||% ""))
      }
    }
    failed <- res$diagnostics$failed_sections %||% list()
    if (length(failed) > 0) {
      cat("Backfilled sections:", paste(unlist(failed), collapse = ", "), "\n")
    }
  }
  invisible(res)
}

local_cohort_method_specs <- function(body) {
  list(
    status = "stub",
    recommendation = list(
      mode = "free_text",
      input_method = "typed_text",
      source = "local_stub_no_acp",
      status = "stub",
      profile_name = "Recommended from free-text description (stub)",
      raw_description = body$analytic_settings_description %||% "",
      study_population = list(),
      time_at_risk = list(),
      propensity_score_adjustment = list(),
      outcome_model = list(),
      deferred_inputs = list(
        function_argument_description = "implemented",
        description_file_path = "implemented",
        interactive_typed_description = "implemented"
      ),
      defaults_snapshot = body$defaults_snapshot %||% list()
    ),
    cohort_methods_specifications = list(),
    section_rationales = list(),
    diagnostics = list(
      source = "local_stub_no_acp",
      reason = "acp_state$url is NULL; call acp_connect(url) first."
    ),
    request = body
  )
}
```

- [ ] **Step 2: Verify R syntax**

Run: `Rscript -e "source('R/OHDSIAssistant/R/cohort_methods_workflow.R'); cat('ok\n')"`

Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add R/OHDSIAssistant/R/cohort_methods_workflow.R
git commit -m "$(cat <<'EOF'
refactor(R): align suggestCohortMethodSpecs with cohort-methods shell contract

Wrapper now sends the same flat IDs the cohort-methods R shell sends and
parses the recommendation/cohort_methods_specifications/section_rationales
response shape. Local stub mirrors the live wire contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Smoke Test Payload — Flat Body

**Files:**
- Modify: `tests/cohort_methods_specs_flow_smoke_test.py`

- [ ] **Step 1: Replace the request body and assertions**

Overwrite `tests/cohort_methods_specs_flow_smoke_test.py` with:

```python
"""Live ACP + MCP smoke test for the cohort methods specs flow.

Requires the ACP server to be running at http://127.0.0.1:8765 with MCP
reachable and LLM credentials configured. Invoked by
`doit smoke_cohort_methods_specs_recommend_flow`.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request


URL = "http://127.0.0.1:8765/flows/cohort_methods_specifications_recommendation"

DESCRIPTION = (
    "Compare sitagliptin new users vs glipizide new users for acute myocardial "
    "infarction. Use a 365-day washout, intent-to-treat follow-up, 1:1 propensity "
    "score matching on standardized logit with a caliper of 0.2, and a Cox model."
)

REQUEST_BODY = {
    "analytic_settings_description": DESCRIPTION,
    "study_description": DESCRIPTION,
    "study_intent": "Comparative effectiveness study on CV outcomes.",
    "target_cohort_id": 1001,
    "comparator_cohort_id": 1002,
    "outcome_cohort_ids": [2001],
    "comparison_label": "Sitagliptin vs Glipizide",
    "defaults_snapshot": {
        "profile_name": "smoke-test",
        "input_method": "typed_text",
    },
}


def main() -> int:
    req = urllib.request.Request(
        URL,
        data=json.dumps(REQUEST_BODY).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=240) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        print(f"HTTPError {exc.code}: {exc.read().decode('utf-8', errors='replace')}")
        return 2

    result = json.loads(body)
    print("status:", result.get("status"))
    rec = result.get("recommendation") or {}
    print("recommendation.status:", rec.get("status"))
    print("profile_name:", rec.get("profile_name"))
    print("failed_sections:", result.get("diagnostics", {}).get("failed_sections"))
    for section, entry in (result.get("section_rationales") or {}).items():
        print(f"  {section}: {entry.get('confidence')}  {entry.get('rationale')}")

    assert result.get("status") in {"ok", "schema_validation_error", "llm_parse_error"}, result
    assert rec.get("raw_description"), "recommendation.raw_description must be non-empty"
    cohort_methods_spec = result.get("cohort_methods_specifications") or {}
    assert cohort_methods_spec.get("cohortDefinitions", {}).get("targetCohort", {}).get("id") == 1001, (
        "client target cohort ID must be preserved in cohort_methods_specifications"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Verify Python syntax**

Run: `python -c "import ast; ast.parse(open('tests/cohort_methods_specs_flow_smoke_test.py').read()); print('ok')"`

Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add tests/cohort_methods_specs_flow_smoke_test.py
git commit -m "$(cat <<'EOF'
test: update cohort methods specs smoke payload to flat shell contract

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: SERVICE_REGISTRY and R README

**Files:**
- Modify: `docs/SERVICE_REGISTRY.yaml` (entry `cohort_methods_specifications_recommendation`)
- Modify: `R/OHDSIAssistant/README.md` (cohort method specifications usage block)

- [ ] **Step 1: Read the current registry entry**

Run: `grep -n -A 30 "cohort_methods_specifications_recommendation:" docs/SERVICE_REGISTRY.yaml`

Note the line range. Replace the entire entry under that key with:

```yaml
  cohort_methods_specifications_recommendation:
    endpoint: /flows/cohort_methods_specifications_recommendation
    method: POST
    layer: acp+mcp+core
    purpose: >
      Translate a free-text description of a comparative-cohort study design into the
      4-key analytic-settings recommendation shape (`study_population`, `time_at_risk`,
      `propensity_score_adjustment`, `outcome_model`) consumed by the cohort-methods
      R shell, with the full cmAnalysis-shaped specification returned alongside for traceability.
    request:
      analytic_settings_description: required string
      study_description: optional string (echo of analytic_settings_description)
      study_intent: optional string
      target_cohort_id: optional integer
      comparator_cohort_id: optional integer
      outcome_cohort_ids: list of integers (default empty)
      comparison_label: optional string
      defaults_snapshot: optional nested dict (effective_analytic_settings)
    response:
      status: ok | llm_parse_error | schema_validation_error
      recommendation: 4-key object (study_population, time_at_risk, propensity_score_adjustment, outcome_model) plus mode/input_method/source/status/profile_name/raw_description/deferred_inputs/defaults_snapshot
      cohort_methods_specifications: full cmAnalysis-shaped specification (internal traceability)
      section_rationales: per-cohort-methods spec-section { rationale, confidence }
      diagnostics: { llm_parse_stage, schema_valid, failed_sections, latency_ms }
    pipeline:
      - mcp.cohort_methods_prompt_bundle
      - llm
      - core.validate_cohort_methods_spec
      - core.merge_client_metadata (built from flat IDs)
      - core.validate_section + core.backfill_section_from_defaults
      - core.cohort_methods_spec_to_shell_recommendation
```

(Adjust the indentation to match the surrounding YAML — check 2-space indentation under `flows:`.)

- [ ] **Step 2: Update the R README usage block**

Run: `grep -n -B 1 -A 20 "suggestCohortMethodSpecs" R/OHDSIAssistant/README.md`

Replace the existing usage block with:

```r
acp_connect("http://127.0.0.1:8765")
res <- suggestCohortMethodSpecs(
  analyticSettingsDescription = "365-day washout, 1:1 PS match, Cox",
  targetCohortId      = 1001,
  comparatorCohortId  = 1002,
  outcomeCohortIds    = c(2001),
  comparisonLabel     = "Sitagliptin vs Glipizide",
  defaultsSnapshot    = list(profile_name = "default", input_method = "typed_text"),
  studyIntent         = "CV outcomes comparative effectiveness"
)
res$recommendation$profile_name
res$recommendation$study_population
```

- [ ] **Step 3: Commit**

```bash
git add docs/SERVICE_REGISTRY.yaml R/OHDSIAssistant/README.md
git commit -m "$(cat <<'EOF'
docs: refresh cohort methods specs flow registry and R usage example

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Final Verification

**Files:** none (read-only verification)

- [ ] **Step 1: Run cohort-methods + cohort_methods_spec targeted tests**

Run: `pytest -q -k "cohort_methods or cohort_methods_spec" -v`

Expected: every test passes. The set of tests is approximately:
- `tests/test_cohort_methods_specs_models.py` — 5 tests
- `tests/test_acp_cohort_methods_flow.py` — 6 tests
- `tests/test_acp_cohort_methods_route.py` — 1 test
- `tests/test_cohort_methods_prompt_bundle.py` — unchanged baseline (≈3-5 tests)
- `tests/test_cohort_methods_spec_validation.py` — baseline + 4 new tests
- (May include a few other matching files; total ≥ 41.)

- [ ] **Step 2: Run the full core marker**

Run: `pytest -q -m core`

Expected: all pass. No regression in `core/` from the new helper.

- [ ] **Step 3: Run the full acp marker**

Run: `pytest -q -m acp`

Expected: all pass. No regression in `acp_agent/` from the route or flow changes.

- [ ] **Step 4: Verify the design and plan docs are saved**

Run: `git status -s docs/`

Expected: both files staged and clean (or untracked if not yet `git add`-ed in the design doc commit).

- [ ] **Step 5: Final commit (if any cleanup)**

Only if Steps 1–3 surfaced a fix:

```bash
git add <fixed-file>
git commit -m "$(cat <<'EOF'
fix(...): <one-line summary>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If everything was clean, do nothing; this task is just the verification gate.

---

## Notes For The Implementer

1. **Do not modify `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`.** That file is owned upstream and deliberately left alone here.
2. **Keep `mcp_server/study_agent_mcp/tools/cohort_methods_prompt_bundle.py` aligned with the MCP-owned cmAnalysis assets.** The prompt bundle now sources `cmAnalysis_template.json` and field descriptions from `CM_ANALYSIS_TEMPLATE.md`.
3. The `Tuple` import in `core/study_agent_core/cohort_methods_spec_validation.py` may already be present; verify before adding it.
4. The `Optional` and `List` imports in `acp_agent/study_agent_acp/agent.py` are already present (used by other flow methods), so no import changes are needed there.
5. After Task 8, the existing `feat/cohort-methods-specs` branch will have nine refactor commits on top of the original nine feature commits. They can be squashed before PR via `git rebase -i origin/main` if desired — that decision is left to the merger, not this plan.
