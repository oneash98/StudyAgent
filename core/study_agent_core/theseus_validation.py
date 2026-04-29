"""Pure validation, merge, and backfill helpers for the Theseus cohort-method spec.

No IO. No network. Rule updates live in THESEUS_SECTION_RULES only.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any, Dict, List, Tuple


THESEUS_TOP_LEVEL_KEYS: List[str] = [
    "name",
    "cohortDefinitions",
    "negativeControlConceptSet",
    "covariateSelection",
    "getDbCohortMethodDataArgs",
    "createStudyPopArgs",
    "propensityScoreAdjustment",
    "fitOutcomeModelArgs",
]

LLM_FILLED_SECTIONS: List[str] = [
    "getDbCohortMethodDataArgs",
    "createStudyPopArgs",
    "propensityScoreAdjustment",
    "fitOutcomeModelArgs",
]

_REMOVE_DUP = {"keep all", "keep first", "remove all"}
_ANCHOR = {"cohort start", "cohort end"}
_CALIPER_SCALE = {"propensity score", "standardized", "standardized logit"}
_BASE_SELECTION = {"all", "target", "comparator"}
_CV_TYPE = {"auto", "grid"}
_NOISE_LEVEL = {"silent", "quiet", "noisy"}
_MODEL_TYPE = {"logistic", "poisson", "cox"}


def validate_theseus_spec(spec: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """Check top-level structural completeness.

    Returns (ok, missing_keys). Does not descend into section contents.
    """
    if not isinstance(spec, dict):
        return False, list(THESEUS_TOP_LEVEL_KEYS)
    missing = [k for k in THESEUS_TOP_LEVEL_KEYS if k not in spec]
    return (len(missing) == 0, missing)


def validate_section(section_name: str, value: Any) -> Tuple[bool, List[str]]:
    """Check enum values and numeric ranges for a single LLM-filled section.

    Returns (ok, violations) where violations is a list of human-readable strings.
    """
    if section_name not in LLM_FILLED_SECTIONS:
        return False, [f"unknown section: {section_name}"]
    if not isinstance(value, dict):
        return False, [f"{section_name} must be an object"]
    checker = _SECTION_CHECKERS[section_name]
    violations: List[str] = []
    checker(value, violations)
    return (len(violations) == 0, violations)


def _check_get_db_args(value: Dict[str, Any], violations: List[str]) -> None:
    max_size = value.get("maxCohortSize")
    if max_size is not None and isinstance(max_size, (int, float)) and max_size < 0:
        violations.append("maxCohortSize must be >= 0")
    periods = value.get("studyPeriods")
    if periods is not None and not isinstance(periods, list):
        violations.append("studyPeriods must be a list")


def _check_study_pop(value: Dict[str, Any], violations: List[str]) -> None:
    dup = value.get("removeDuplicateSubjects")
    if dup is not None and dup not in _REMOVE_DUP:
        violations.append(f"removeDuplicateSubjects must be one of {sorted(_REMOVE_DUP)}")
    washout = value.get("washoutPeriod")
    if isinstance(washout, (int, float)) and washout < 0:
        violations.append("washoutPeriod must be >= 0")
    lookback = value.get("priorOutcomeLookBack")
    if isinstance(lookback, (int, float)) and lookback < 0:
        violations.append("priorOutcomeLookBack must be >= 0")
    tars = value.get("timeAtRisks")
    if tars is None:
        return
    if not isinstance(tars, list):
        violations.append("timeAtRisks must be a list")
        return
    for idx, tar in enumerate(tars):
        if not isinstance(tar, dict):
            violations.append(f"timeAtRisks[{idx}] must be an object")
            continue
        start = tar.get("startAnchor")
        end = tar.get("endAnchor")
        if start is not None and start not in _ANCHOR:
            violations.append(f"timeAtRisks[{idx}].startAnchor must be one of {sorted(_ANCHOR)}")
        if end is not None and end not in _ANCHOR:
            violations.append(f"timeAtRisks[{idx}].endAnchor must be one of {sorted(_ANCHOR)}")
        min_days = tar.get("minDaysAtRisk")
        if isinstance(min_days, (int, float)) and min_days < 1:
            violations.append(f"timeAtRisks[{idx}].minDaysAtRisk must be >= 1")


def _check_ps_adjustment(value: Dict[str, Any], violations: List[str]) -> None:
    settings = value.get("psSettings")
    if settings is None:
        return
    if not isinstance(settings, list):
        violations.append("psSettings must be a list")
    else:
        for idx, ps in enumerate(settings):
            if not isinstance(ps, dict):
                violations.append(f"psSettings[{idx}] must be an object")
                continue
            match = ps.get("matchOnPsArgs")
            strat = ps.get("stratifyByPsArgs")
            if match is not None and isinstance(match, dict):
                ratio = match.get("maxRatio")
                if isinstance(ratio, (int, float)) and ratio < 0:
                    violations.append(f"psSettings[{idx}].matchOnPsArgs.maxRatio must be >= 0")
                cal = match.get("caliper")
                if isinstance(cal, (int, float)) and cal < 0:
                    violations.append(f"psSettings[{idx}].matchOnPsArgs.caliper must be >= 0")
                scale = match.get("caliperScale")
                if scale is not None and scale not in _CALIPER_SCALE:
                    violations.append(
                        f"psSettings[{idx}].matchOnPsArgs.caliperScale must be one of {sorted(_CALIPER_SCALE)}"
                    )
            if strat is not None and isinstance(strat, dict):
                strata = strat.get("numberOfStrata")
                if isinstance(strata, (int, float)) and strata < 2:
                    violations.append(f"psSettings[{idx}].stratifyByPsArgs.numberOfStrata must be >= 2")
                base = strat.get("baseSelection")
                if base is not None and base not in _BASE_SELECTION:
                    violations.append(
                        f"psSettings[{idx}].stratifyByPsArgs.baseSelection must be one of {sorted(_BASE_SELECTION)}"
                    )
    create_ps = value.get("createPsArgs")
    if isinstance(create_ps, dict):
        control = create_ps.get("control")
        if isinstance(control, dict):
            cv = control.get("cvType")
            if cv is not None and cv not in _CV_TYPE:
                violations.append(f"createPsArgs.control.cvType must be one of {sorted(_CV_TYPE)}")
            noise = control.get("noiseLevel")
            if noise is not None and noise not in _NOISE_LEVEL:
                violations.append(f"createPsArgs.control.noiseLevel must be one of {sorted(_NOISE_LEVEL)}")


def _check_outcome_model(value: Dict[str, Any], violations: List[str]) -> None:
    model_type = value.get("modelType")
    if model_type is not None and model_type not in _MODEL_TYPE:
        violations.append(f"modelType must be one of {sorted(_MODEL_TYPE)}")
    control = value.get("control")
    if isinstance(control, dict):
        cv = control.get("cvType")
        if cv is not None and cv not in _CV_TYPE:
            violations.append(f"control.cvType must be one of {sorted(_CV_TYPE)}")
        noise = control.get("noiseLevel")
        if noise is not None and noise not in _NOISE_LEVEL:
            violations.append(f"control.noiseLevel must be one of {sorted(_NOISE_LEVEL)}")


_SECTION_CHECKERS = {
    "getDbCohortMethodDataArgs": _check_get_db_args,
    "createStudyPopArgs": _check_study_pop,
    "propensityScoreAdjustment": _check_ps_adjustment,
    "fitOutcomeModelArgs": _check_outcome_model,
}


def merge_client_metadata(
    spec: Dict[str, Any],
    cohort_definitions: Dict[str, Any],
    negative_control: Dict[str, Any],
    covariate_selection: Dict[str, Any],
) -> Dict[str, Any]:
    """Return a deep copy of `spec` with client-carried metadata fields overwritten.

    Overwrites `cohortDefinitions`, `negativeControlConceptSet`, `covariateSelection`.
    Leaves `name` alone (LLM-supplied).
    """
    merged = deepcopy(spec) if isinstance(spec, dict) else {}
    if cohort_definitions:
        merged["cohortDefinitions"] = deepcopy(cohort_definitions)
    if negative_control:
        merged["negativeControlConceptSet"] = deepcopy(negative_control)
    if covariate_selection:
        merged["covariateSelection"] = deepcopy(covariate_selection)
    return merged


def backfill_section_from_defaults(
    spec: Dict[str, Any],
    defaults: Dict[str, Any],
    section_name: str,
) -> Dict[str, Any]:
    """Return a deep copy of `spec` with `section_name` replaced by the defaults value.

    Raises ValueError for sections outside LLM_FILLED_SECTIONS.
    """
    if section_name not in LLM_FILLED_SECTIONS:
        raise ValueError(f"cannot backfill unknown section: {section_name}")
    out = deepcopy(spec) if isinstance(spec, dict) else {}
    out[section_name] = deepcopy(defaults.get(section_name, {}))
    return out


_TAR_KEYS: Tuple[str, ...] = ("startAnchor", "riskWindowStart", "endAnchor", "riskWindowEnd")


def theseus_to_hanjae_recommendation(
    *,
    theseus_spec: Dict[str, Any],
    raw_description: str,
    defaults_snapshot: Dict[str, Any],
    profile_name: str,
    input_method: str,
    rec_status: str,
) -> Dict[str, Any]:
    """Project a validated Theseus spec into the 4-key recommendation shape the
    cohort-methods R shell expects.

    See docs/COHORT_METHODS_SPECIFICATIONS_RECOMMENDATION_DESIGN.md §6.
    """
    cspa = (theseus_spec or {}).get("createStudyPopArgs") or {}
    cmda = (theseus_spec or {}).get("getDbCohortMethodDataArgs") or {}
    psadj = (theseus_spec or {}).get("propensityScoreAdjustment") or {}
    fmod = (theseus_spec or {}).get("fitOutcomeModelArgs") or {}

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
