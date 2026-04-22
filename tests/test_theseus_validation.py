import pytest

from study_agent_core.theseus_validation import (
    LLM_FILLED_SECTIONS,
    THESEUS_TOP_LEVEL_KEYS,
    validate_section,
    validate_theseus_spec,
)


pytestmark = pytest.mark.core


def _minimal_valid_spec() -> dict:
    return {
        "name": "Study",
        "cohortDefinitions": {"targetCohort": {"id": 1, "name": "T"}},
        "negativeControlConceptSet": {"id": None, "name": None},
        "covariateSelection": {"conceptsToInclude": [], "conceptsToExclude": []},
        "getDbCohortMethodDataArgs": {"studyPeriods": [], "maxCohortSize": 0},
        "createStudyPopArgs": {
            "restrictToCommonPeriod": False,
            "firstExposureOnly": False,
            "washoutPeriod": 0,
            "removeDuplicateSubjects": "keep all",
            "censorAtNewRiskWindow": False,
            "removeSubjectsWithPriorOutcome": True,
            "priorOutcomeLookBack": 99999,
            "timeAtRisks": [
                {
                    "description": "TAR 1",
                    "riskWindowStart": 0,
                    "startAnchor": "cohort start",
                    "riskWindowEnd": 0,
                    "endAnchor": "cohort end",
                    "minDaysAtRisk": 1,
                }
            ],
        },
        "propensityScoreAdjustment": {
            "psSettings": [
                {
                    "description": "PS 1",
                    "matchOnPsArgs": {"maxRatio": 1, "caliper": 0.2, "caliperScale": "standardized logit"},
                    "stratifyByPsArgs": None,
                }
            ],
            "createPsArgs": {"maxCohortSizeForFitting": 250000, "errorOnHighCorrelation": True, "prior": None, "control": None},
        },
        "fitOutcomeModelArgs": {
            "modelType": "cox",
            "stratified": False,
            "useCovariates": False,
            "inversePtWeighting": False,
            "prior": None,
            "control": None,
        },
    }


def test_top_level_constants() -> None:
    assert LLM_FILLED_SECTIONS == [
        "getDbCohortMethodDataArgs",
        "createStudyPopArgs",
        "propensityScoreAdjustment",
        "fitOutcomeModelArgs",
    ]
    assert "name" in THESEUS_TOP_LEVEL_KEYS


def test_validate_theseus_spec_accepts_minimal() -> None:
    ok, missing = validate_theseus_spec(_minimal_valid_spec())
    assert ok is True
    assert missing == []


def test_validate_theseus_spec_reports_missing_keys() -> None:
    spec = _minimal_valid_spec()
    del spec["fitOutcomeModelArgs"]
    del spec["name"]
    ok, missing = validate_theseus_spec(spec)
    assert ok is False
    assert set(missing) == {"name", "fitOutcomeModelArgs"}


def test_validate_section_accepts_good_study_pop() -> None:
    spec = _minimal_valid_spec()
    ok, violations = validate_section("createStudyPopArgs", spec["createStudyPopArgs"])
    assert ok is True
    assert violations == []


def test_validate_section_flags_bad_enum() -> None:
    bad = {
        "modelType": "svm",
        "stratified": False,
        "useCovariates": False,
        "inversePtWeighting": False,
        "prior": None,
        "control": None,
    }
    ok, violations = validate_section("fitOutcomeModelArgs", bad)
    assert ok is False
    assert any("modelType" in v for v in violations)


def test_validate_section_flags_range() -> None:
    bad = {
        "psSettings": [
            {
                "description": "bad",
                "matchOnPsArgs": {"maxRatio": -1, "caliper": -0.5, "caliperScale": "standardized"},
                "stratifyByPsArgs": None,
            }
        ],
        "createPsArgs": {"maxCohortSizeForFitting": 0, "errorOnHighCorrelation": True, "prior": None, "control": None},
    }
    ok, violations = validate_section("propensityScoreAdjustment", bad)
    assert ok is False
    assert any("caliper" in v for v in violations)
    assert any("maxRatio" in v for v in violations)


def test_validate_section_rejects_unknown_section() -> None:
    ok, violations = validate_section("unknownSection", {})
    assert ok is False
    assert violations and "unknown section" in violations[0]
