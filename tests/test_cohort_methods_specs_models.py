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
    assert out.theseus_specifications is None
    assert out.section_rationales == {}
    assert out.diagnostics == {}


def test_output_rejects_unknown_status() -> None:
    with pytest.raises(Exception):
        CohortMethodSpecsRecommendationOutput(status="stub")  # type: ignore[arg-type]
