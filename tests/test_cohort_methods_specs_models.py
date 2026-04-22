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
    assert payload.current_specifications is None
    assert payload.cohort_definitions == {}
    assert payload.negative_control_concept_set == {}
    assert payload.covariate_selection == {}


def test_input_accepts_iterative_current_spec() -> None:
    payload = CohortMethodSpecsRecommendationInput(
        analytic_settings_description="tighten follow-up",
        current_specifications={"name": "Study", "createStudyPopArgs": {"washoutPeriod": 365}},
    )
    assert payload.current_specifications is not None
    assert payload.current_specifications["createStudyPopArgs"]["washoutPeriod"] == 365


def test_output_defaults() -> None:
    out = CohortMethodSpecsRecommendationOutput(status="ok")
    assert out.status == "ok"
    assert out.specifications == {}
    assert out.sectionRationales == {}
    assert out.diagnostics == {}


def test_output_rejects_unknown_status() -> None:
    with pytest.raises(Exception):
        CohortMethodSpecsRecommendationOutput(status="stub")  # type: ignore[arg-type]
