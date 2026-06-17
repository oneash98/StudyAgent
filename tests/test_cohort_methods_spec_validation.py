import pytest

from study_agent_core.cohort_methods_spec_validation import (
    LLM_FILLED_SECTIONS,
    COHORT_METHODS_SPEC_TOP_LEVEL_KEYS,
    backfill_section_from_defaults,
    cohort_methods_spec_to_shell_recommendation,
    merge_client_metadata,
    validate_cohort_methods_spec,
    validate_section,
)


pytestmark = pytest.mark.core


def _minimal_valid_spec() -> dict:
    return {
        "getDbCohortMethodDataArgs": {
            "studyPeriods": [{"description": "Primary", "studyStartDate": "", "studyEndDate": ""}],
            "firstExposureOnly": False,
            "removeDuplicateSubjects": "keep all",
            "restrictToCommonPeriod": False,
            "washoutPeriod": 365,
            "maxCohortSize": 0,
        },
        "createStudyPopArgs": {
            "removeSubjectsWithPriorOutcome": True,
            "priorOutcomeLookback": 99999,
            "timeAtRisks": [
                {
                    "description": "Primary",
                    "minDaysAtRisk": 1,
                    "riskWindowStart": 1,
                    "startAnchor": "cohort start",
                    "riskWindowEnd": 0,
                    "endAnchor": "cohort end",
                }
            ],
            "censorAtNewRiskWindow": False,
        },
        "psSettings": [
            {
                "description": "Primary",
                "trimByPsArgs": {"trimFraction": 0.05, "equipoiseBounds": None},
                "matchOnPsArgs": {"maxRatio": 1, "caliper": 0.2, "caliperScale": "standardized logit"},
                "stratifyByPsArgs": None,
                "inversePtWeighting": False,
            }
        ],
        "createPsArgs": {
            "maxCohortSizeForFitting": 250000,
            "errorOnHighCorrelation": True,
            "prior": None,
            "control": None,
        },
        "fitOutcomeModelArgs": {
            "outcomeModels": [
                {
                    "description": "Primary",
                    "modelType": "cox",
                    "useCovariates": False,
                }
            ],
            "stratified": False,
            "prior": None,
            "control": None,
        },
    }


def test_top_level_constants() -> None:
    assert LLM_FILLED_SECTIONS == [
        "getDbCohortMethodDataArgs",
        "createStudyPopArgs",
        "psSettings",
        "createPsArgs",
        "fitOutcomeModelArgs",
    ]
    assert COHORT_METHODS_SPEC_TOP_LEVEL_KEYS == LLM_FILLED_SECTIONS


def test_validate_cohort_methods_spec_accepts_minimal() -> None:
    ok, missing = validate_cohort_methods_spec(_minimal_valid_spec())
    assert ok is True
    assert missing == []


def test_validate_cohort_methods_spec_reports_missing_keys() -> None:
    spec = _minimal_valid_spec()
    del spec["fitOutcomeModelArgs"]
    del spec["psSettings"]
    ok, missing = validate_cohort_methods_spec(spec)
    assert ok is False
    assert set(missing) == {"psSettings", "fitOutcomeModelArgs"}


def test_validate_section_accepts_good_study_pop() -> None:
    spec = _minimal_valid_spec()
    ok, violations = validate_section("createStudyPopArgs", spec["createStudyPopArgs"])
    assert ok is True
    assert violations == []


def test_validate_section_flags_bad_enum() -> None:
    bad = {
        "outcomeModels": [{"description": "Bad", "modelType": "svm", "useCovariates": False}],
        "stratified": False,
        "prior": None,
        "control": None,
    }
    ok, violations = validate_section("fitOutcomeModelArgs", bad)
    assert ok is False
    assert any("modelType" in v for v in violations)


def test_validate_section_flags_range() -> None:
    bad = [
        {
            "description": "Bad",
            "trimByPsArgs": None,
            "matchOnPsArgs": {"maxRatio": -1, "caliper": -0.5, "caliperScale": "standardized"},
            "stratifyByPsArgs": None,
            "inversePtWeighting": False,
        }
    ]
    ok, violations = validate_section("psSettings", bad)
    assert ok is False
    assert any("caliper" in v for v in violations)
    assert any("maxRatio" in v for v in violations)


def test_validate_section_rejects_unknown_section() -> None:
    ok, violations = validate_section("unknownSection", {})
    assert ok is False
    assert violations and "unknown section" in violations[0]


def test_merge_client_metadata_overrides_llm_cohorts() -> None:
    spec = _minimal_valid_spec()
    client_cohort_defs = {
        "targetCohort": {"id": 1, "name": "Real Target"},
        "comparatorCohort": {"id": 2, "name": "Real Comp"},
        "outcomeCohort": [{"id": 3, "name": "Real Outcome"}],
    }
    merged = merge_client_metadata(
        spec,
        cohort_definitions=client_cohort_defs,
        negative_control={"id": 42, "name": "NC"},
        covariate_selection={"conceptsToInclude": [{"id": 7}], "conceptsToExclude": []},
    )
    assert merged["cohortDefinitions"]["targetCohort"]["id"] == 1
    assert merged["cohortDefinitions"]["targetCohort"]["name"] == "Real Target"
    assert merged["cohortDefinitions"]["comparatorCohort"]["id"] == 2
    assert merged["negativeControlConceptSet"]["id"] == 42
    assert merged["covariateSelection"]["conceptsToInclude"] == [{"id": 7}]


def test_merge_client_metadata_leaves_spec_alone_without_metadata() -> None:
    spec = _minimal_valid_spec()
    merged = merge_client_metadata(
        spec,
        cohort_definitions={},
        negative_control={},
        covariate_selection={},
    )
    assert merged == spec


def test_merge_client_metadata_does_not_mutate_input() -> None:
    spec = _minimal_valid_spec()
    merge_client_metadata(
        spec,
        cohort_definitions={"targetCohort": {"id": 42, "name": "X"}},
        negative_control={},
        covariate_selection={},
    )
    assert "cohortDefinitions" not in spec


def test_backfill_section_from_defaults_replaces_single_section() -> None:
    spec = _minimal_valid_spec()
    defaults = _minimal_valid_spec()
    defaults["fitOutcomeModelArgs"]["outcomeModels"][0]["modelType"] = "cox"
    defaults["fitOutcomeModelArgs"]["stratified"] = True
    spec["fitOutcomeModelArgs"] = {"outcomeModels": [{"modelType": "BROKEN"}]}
    out = backfill_section_from_defaults(spec, defaults, "fitOutcomeModelArgs")
    assert out["fitOutcomeModelArgs"]["outcomeModels"][0]["modelType"] == "cox"
    assert out["fitOutcomeModelArgs"]["stratified"] is True
    assert out["createStudyPopArgs"] == spec["createStudyPopArgs"]


def test_backfill_section_rejects_unknown_section() -> None:
    spec = _minimal_valid_spec()
    defaults = _minimal_valid_spec()
    with pytest.raises(ValueError):
        backfill_section_from_defaults(spec, defaults, "unknownSection")


def _full_spec_with_tar() -> dict:
    spec = _minimal_valid_spec()
    spec["createStudyPopArgs"]["timeAtRisks"][0]["startAnchor"] = "cohort start"
    spec["createStudyPopArgs"]["timeAtRisks"][0]["riskWindowStart"] = 1
    spec["createStudyPopArgs"]["timeAtRisks"][0]["endAnchor"] = "cohort end"
    spec["createStudyPopArgs"]["timeAtRisks"][0]["riskWindowEnd"] = 365
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
    assert sp["cohortMethodDataArgs"]["studyPeriods"] == spec["getDbCohortMethodDataArgs"]["studyPeriods"]
    assert sp["cohortMethodDataArgs"]["studyStartDate"] == ""
    assert sp["cohortMethodDataArgs"]["studyEndDate"] == ""
    assert out["propensity_score_adjustment"]["psSettings"] == spec["psSettings"]
    assert out["propensity_score_adjustment"]["matchOnPsArgs"] == spec["psSettings"][0]["matchOnPsArgs"]
    assert out["propensity_score_adjustment"]["createPsArgs"] == spec["createPsArgs"]
    assert out["outcome_model"]["outcomeModels"][0]["modelType"] == spec["fitOutcomeModelArgs"]["outcomeModels"][0]["modelType"]
    assert out["outcome_model"]["outcomeModels"][0]["stratified"] is False
    assert out["outcome_model"]["outcomeModels"][0]["inversePtWeighting"] is False
    assert out["outcome_model"]["modelType"] == "cox"
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
    assert out["propensity_score_adjustment"] == {
        "psSettings": [],
        "trimByPsArgs": None,
        "matchOnPsArgs": None,
        "stratifyByPsArgs": None,
        "createPsArgs": None,
        "inversePtWeighting": False,
    }
    assert out["outcome_model"] == {"stratified": False, "inversePtWeighting": False}


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
    assert spec["getDbCohortMethodDataArgs"]["washoutPeriod"] == 365
    assert snapshot["profile_name"] == "snap"


def test_cohort_methods_spec_to_shell_derives_outcome_flags_from_ps_settings() -> None:
    spec = _minimal_valid_spec()
    spec["psSettings"] = [
        {
            "description": "IPTW",
            "trimByPsArgs": None,
            "matchOnPsArgs": None,
            "stratifyByPsArgs": None,
            "inversePtWeighting": True,
        },
        {
            "description": "Variable ratio",
            "trimByPsArgs": None,
            "matchOnPsArgs": {"maxRatio": 4, "caliper": 0.2, "caliperScale": "standardized logit"},
            "stratifyByPsArgs": None,
            "inversePtWeighting": False,
        },
    ]
    spec["fitOutcomeModelArgs"]["outcomeModels"] = [
        {"description": "Primary", "modelType": "cox", "useCovariates": False},
        {"description": "Sensitivity", "modelType": "cox", "useCovariates": False},
    ]
    out = cohort_methods_spec_to_shell_recommendation(
        cohort_methods_spec=spec,
        raw_description="d",
        defaults_snapshot={},
        profile_name="X",
        input_method="typed_text",
        rec_status="received",
    )
    models = out["outcome_model"]["outcomeModels"]
    assert models[0]["stratified"] is False
    assert models[0]["inversePtWeighting"] is True
    assert models[1]["stratified"] is True
    assert models[1]["inversePtWeighting"] is False
