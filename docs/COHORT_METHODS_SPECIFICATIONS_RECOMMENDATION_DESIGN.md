# Cohort Methods Specifications Recommendation — Design

**Status:** active. Supersedes the earlier draft that targeted a Theseus-shaped wire contract.

**Owner of consuming side:** Hanjae (`R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`).
**Owner of this flow:** Minseong (Python core/MCP/ACP plus the standalone R wrapper).

## 1. Overview

Hanjae's cohort-methods R shell already calls
`POST /flows/cohort_methods_specifications_recommendation` (line 2948 in `strategus_cohort_methods_shell.R`)
when free-text analytic settings mode runs and ACP is connected. If the endpoint is missing or returns an unexpected shape, the shell falls back to a local dummy and the rest of the run continues with placeholder analytic settings.

This document defines that endpoint's wire contract, the internal pipeline, and the standalone R wrapper that mirrors it.

The contract is fixed by what Hanjae's shell already sends and what it parses back — that is the source of truth. Earlier drafts of this design proposed a Theseus-shaped envelope; that has been retired in favor of Hanjae's flat, four-section "recommendation" shape.

## 2. Goals

1. Endpoint accepts the request body Hanjae's shell builds at line 4222–4231 of the R shell, **byte-for-byte**, with no shell changes.
2. Endpoint returns a response whose top-level `recommendation` key matches the shape of Hanjae's `build_dummy_analytic_settings_recommendation()` (line 2888–2907) so the shell's existing `response$recommendation %||% …` salvage logic stabilizes on real ACP output.
3. Internally, the LLM is still steered by the annotated Theseus template (better extraction quality, deterministic defaults, per-section validation), but the Theseus document is an internal artifact, not the wire output.
4. Every flat cohort ID in the request flows into the Theseus internal step as `cohortDefinitions` so client metadata wins over LLM drift, exactly as in earlier drafts.
5. Standalone callers (R or Python, outside Hanjae's shell) get the same wire contract via `OHDSIAssistant::suggestCohortMethodSpecs()`.

## 3. Non-Goals

1. **No edits to `strategus_cohort_methods_shell.R`.** Hanjae's shell is left intact.
2. No replacement of Hanjae's `cohort_methods_intent_split` flow — that already lives in `main` and is upstream of this flow.
3. No interactive `step_by_step` ACP path. Hanjae's shell only calls ACP from the `free_text` branch; that is the only path this flow needs to serve.
4. No generation of Strategus R execution code from the recommendation. `06_cm_spec.R` continues to read `cm_analysis_defaults.json`. Wiring `cmAnalysis.json` into the generated script is STATUS_KO §5.9 work and is out of scope here.
5. No PHI/Keeper sanitization step. Inputs are cohort/concept-set IDs (metadata) and user-authored free-text — same judgment as `phenotype_recommendation`.

## 4. Data Flow

```
Hanjae R shell (free_text mode, ACP connected)
  → .acp_post("/flows/cohort_methods_specifications_recommendation", body)
    → ACP route handler
      → CohortMethodSpecsRecommendationInput (pydantic)
      → MCP cohort_methods_prompt_bundle  (annotated template + defaults_spec)
      → build prompt (<Text>, <Study Intent>, <Current Analysis Specifications>=defaults_spec, <Analysis Specifications Template>, <Output Style>)
      → LLM call → fenced JSON { specifications, sectionRationales }
      → core.validate_theseus_spec
      → build internal cohort_definitions from flat IDs → core.merge_client_metadata
      → per-section validate + backfill_section_from_defaults
      → core.theseus_to_hanjae_recommendation(...)
    ← { status, recommendation: { ... Hanjae shape ... }, theseus_specifications, section_rationales, diagnostics }
```

Hanjae's shell wraps the response further (line 2972–2979):

```r
list(flow, source = "acp_flow", status = "received", request, response, recommendation = response$recommendation)
```

So the only field the shell reads off our payload at orchestration time is `response$recommendation` (and via that, `recommendation$profile_name`). Everything else we return is for traceability and for future consumers.

## 5. Wire Contract

### 5.1 Request

The body is exactly what Hanjae's shell builds at line 4222–4231. Field names are snake_case at the boundary.

```json
{
  "study_intent":                    "string | null",
  "study_description":               "string | null",
  "analytic_settings_description":   "string (required, non-empty)",
  "target_cohort_id":                123,
  "comparator_cohort_id":            456,
  "outcome_cohort_ids":              [789],
  "comparison_label":                "string | null",
  "defaults_snapshot":               { "...": "nested analytic settings as the shell built them" }
}
```

Notes:

1. `study_description` and `analytic_settings_description` carry the same string in Hanjae's shell. The endpoint requires `analytic_settings_description`; `study_description` is accepted but ignored if `analytic_settings_description` is present.
2. `outcome_cohort_ids` is a JSON array even when there is only one outcome.
3. `defaults_snapshot` is `effective_analytic_settings` from the shell — a nested R list serialized by jsonlite. The endpoint does not validate its inner structure; it is passed through to the response and used as the prompt's "current settings" hint when no Theseus defaults exist for a value.
4. There is **no** `cohort_definitions`, `negative_control_concept_set`, `covariate_selection`, or `current_specifications` field on the wire. Internal Theseus processing builds `cohortDefinitions` from the flat IDs.

### 5.2 Response

```json
{
  "status": "ok | llm_parse_error | schema_validation_error",
  "recommendation": {
    "mode":                          "free_text",
    "input_method":                  "typed_text | description_argument | description_file_path",
    "source":                        "acp_flow",
    "status":                        "received | backfilled",
    "profile_name":                  "string",
    "raw_description":               "string (echoed analytic_settings_description)",
    "study_population":              { "...": "Theseus createStudyPopArgs without TAR fields" },
    "time_at_risk":                  { "startAnchor": "...", "riskWindowStart": 0, "endAnchor": "...", "riskWindowEnd": 0 },
    "propensity_score_adjustment":   { "...": "Theseus propensityScoreAdjustment" },
    "outcome_model":                 { "...": "Theseus fitOutcomeModelArgs" },
    "deferred_inputs":               {
      "function_argument_description":   "implemented",
      "description_file_path":           "implemented",
      "interactive_typed_description":   "implemented"
    },
    "defaults_snapshot":             "echo of request.defaults_snapshot"
  },
  "theseus_specifications": { "...": "full Theseus document, internal traceability" },
  "section_rationales": {
    "getDbCohortMethodDataArgs":   { "rationale": "...", "confidence": "high|medium|low" },
    "createStudyPopArgs":          { "rationale": "...", "confidence": "high|medium|low" },
    "propensityScoreAdjustment":   { "rationale": "...", "confidence": "high|medium|low" },
    "fitOutcomeModelArgs":         { "rationale": "...", "confidence": "high|medium|low" }
  },
  "diagnostics": {
    "llm_parse_stage": "ok | json_extract_failed | json_decode_failed | schema_validation_failed",
    "schema_valid":    true,
    "failed_sections": [],
    "latency_ms":      0
  }
}
```

`status` semantics:

1. `"ok"` and `failed_sections == []` — LLM output passed every check.
2. `"ok"` and `failed_sections` non-empty — top-level Theseus structure was valid; listed sections failed their rule check, were backfilled from defaults, and `recommendation.status` becomes `"backfilled"`. Affected `section_rationales[*].confidence` is forced to `"low"`.
3. `"schema_validation_error"` — top-level Theseus keys missing. `theseus_specifications` is the full defaults; `recommendation` is built from defaults. `recommendation.status == "backfilled"`.
4. `"llm_parse_error"` — JSON could not be extracted/decoded, or the request had no description. Same fallback as (3).

`recommendation.input_method` is set to `"typed_text"` unless the client opts to pass a different value via the wrapper (R-side detail). The server accepts the field through `defaults_snapshot.input_method` as a soft hint; if absent it defaults to `"typed_text"`.

The shell's wrapper status (`"stub"` when `acp_state$url` is NULL) is a wrapper-side extension. The server enum is strictly the four values above.

## 6. Theseus → Hanjae Mapping (`theseus_to_hanjae_recommendation`)

A pure helper added to `core/study_agent_core/theseus_validation.py`:

```python
def theseus_to_hanjae_recommendation(
    *,
    theseus_spec: Dict[str, Any],
    raw_description: str,
    defaults_snapshot: Dict[str, Any],
    profile_name: str,
    input_method: str,
    rec_status: str,                # "received" | "backfilled"
) -> Dict[str, Any]: ...
```

Mapping rules:

1. `study_population` ← `createStudyPopArgs` minus the four TAR keys (`startAnchor`, `riskWindowStart`, `endAnchor`, `riskWindowEnd`). Plus `cohortMethodDataArgs` set to the entire `getDbCohortMethodDataArgs` value (so cohort window restrictions travel under the same banner the shell already calls "study population").
2. `time_at_risk` ← only the four TAR keys, picked from `createStudyPopArgs`. Missing keys are omitted.
3. `propensity_score_adjustment` ← entire `propensityScoreAdjustment` subtree.
4. `outcome_model` ← entire `fitOutcomeModelArgs` subtree.
5. `deferred_inputs` is constant — three `"implemented"` strings, mirroring Hanjae's dummy builder so the shell's introspection finds the same keys.
6. `defaults_snapshot` is the request's pass-through.

Note: when `createStudyPopArgs.timeAtRisks` exists (it is the canonical Theseus structure for TAR — a list of TAR objects), the helper additionally projects the **first** TAR object into the `time_at_risk` flat dict so both shapes are populated. The list survives in `theseus_specifications` for downstream consumers that prefer it.

## 7. Internal Pipeline (Pseudocode)

```python
def run_cohort_methods_specs_recommendation_flow(
    analytic_settings_description: str,
    study_intent: str = "",
    target_cohort_id: Optional[int] = None,
    comparator_cohort_id: Optional[int] = None,
    outcome_cohort_ids: Optional[List[int]] = None,
    comparison_label: Optional[str] = None,
    defaults_snapshot: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    bundle = call_tool("cohort_methods_prompt_bundle")
    defaults_spec  = bundle["defaults_spec"]
    annotated_tpl  = bundle["annotated_template"]
    instruction    = bundle["instruction_template"]
    output_style   = bundle["output_style_template"]

    cohort_definitions = build_internal_cohort_definitions(
        target_cohort_id, comparator_cohort_id, outcome_cohort_ids, comparison_label
    )

    # Empty description → fallback before LLM.
    if not analytic_settings_description.strip():
        return _fallback("llm_parse_error", reason="analytic_settings_description is required",
                         defaults_spec, cohort_definitions, raw_description="",
                         defaults_snapshot=defaults_snapshot)

    prompt = build_prompt(instruction, output_style, annotated_tpl,
                          analytic_settings_description, study_intent,
                          starting_spec=defaults_spec)
    llm_result = call_llm(prompt, required_keys=["specifications", "sectionRationales"])
    payload    = parse_fenced_json(llm_result)

    if payload is None or "specifications" not in payload:
        return _fallback("llm_parse_error", ..., diagnostics_stage="json_extract_failed | json_decode_failed")

    spec = payload["specifications"]
    ok_top, missing = validate_theseus_spec(spec)
    if not ok_top:
        return _fallback("schema_validation_error", ..., missing_keys=missing)

    spec = merge_client_metadata(spec, cohort_definitions, {}, {})

    rationales_in  = payload.get("sectionRationales") or {}
    rationales_out = {}
    failed_sections = []
    for section in LLM_FILLED_SECTIONS:
        ok_sec, violations = validate_section(section, spec.get(section))
        if not ok_sec:
            spec = backfill_section_from_defaults(spec, defaults_spec, section)
            failed_sections.append(section)
            rationales_out[section] = {"rationale": "[backfilled: " + "; ".join(violations) + "]",
                                       "confidence": "low"}
        else:
            rationales_out[section] = _normalize_rationale(rationales_in.get(section))

    rec_status = "backfilled" if failed_sections else "received"
    recommendation = theseus_to_hanjae_recommendation(
        theseus_spec=spec,
        raw_description=analytic_settings_description,
        defaults_snapshot=defaults_snapshot or {},
        profile_name=spec.get("name") or "Recommended from free-text description",
        input_method=(defaults_snapshot or {}).get("input_method") or "typed_text",
        rec_status=rec_status,
    )
    return {
        "status": "ok",
        "recommendation": recommendation,
        "theseus_specifications": spec,
        "section_rationales": rationales_out,
        "diagnostics": { "llm_parse_stage": "ok", "schema_valid": True,
                         "failed_sections": failed_sections, "latency_ms": ... },
    }
```

`build_internal_cohort_definitions` is a small private helper inside the flow handler:

```python
{
  "targetCohort":     {"id": int(target_cohort_id), "name": comparison_label_target  or ""},
  "comparatorCohort": {"id": int(comparator_cohort_id), "name": comparison_label_comp or ""},
  "outcomeCohort":    [{"id": int(i), "name": ""} for i in (outcome_cohort_ids or [])],
}
```

Names are filled from `comparison_label` only when it carries clearly delimited target/comparator labels — otherwise empty strings, matching the existing `merge_client_metadata` precedence (the LLM's `name` field still drives the study name).

## 8. Pydantic Models

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
    theseus_specifications: Optional[Dict[str, Any]] = None
    section_rationales: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    diagnostics: Dict[str, Any] = Field(default_factory=dict)
```

`section_rationales` (snake_case) is the new wire field. The earlier `sectionRationales` (camelCase) was specific to a Theseus-out wire contract and is dropped.

## 9. R Wrapper (`suggestCohortMethodSpecs`)

File: `R/OHDSIAssistant/R/cohort_methods_workflow.R`. Hanjae's shell does **not** call this wrapper — the shell builds its own body and `.acp_post`s directly. The wrapper exists for standalone R use, smoke testing, and parity across `OHDSIAssistant::suggest*` helpers.

Signature:

```r
suggestCohortMethodSpecs(
  analyticSettingsDescription,
  targetCohortId      = NULL,
  comparatorCohortId  = NULL,
  outcomeCohortIds    = NULL,
  comparisonLabel     = NULL,
  defaultsSnapshot    = NULL,
  studyIntent         = NULL,
  interactive         = TRUE
)
```

Body matches §5.1 verbatim. When `acp_state$url` is NULL, returns a local stub whose response shape mirrors §5.2 with `status = "stub"` (wrapper-only) and `recommendation$source = "local_stub_no_acp"`.

## 10. Files Modified

1. `core/study_agent_core/models.py` — replace `CohortMethodSpecsRecommendationInput` and `CohortMethodSpecsRecommendationOutput`.
2. `core/study_agent_core/theseus_validation.py` — add `theseus_to_hanjae_recommendation()`.
3. `acp_agent/study_agent_acp/agent.py` — rewrite `run_cohort_methods_specs_recommendation_flow()`.
4. `acp_agent/study_agent_acp/server.py` — update the route handler at `/flows/cohort_methods_specifications_recommendation` to pass the new field names.
5. `R/OHDSIAssistant/R/cohort_methods_workflow.R` — rewrite `suggestCohortMethodSpecs()` and `local_cohort_method_specs()`.
6. `R/OHDSIAssistant/README.md` — refresh the usage block in §"Cohort method specifications" to match the new signature.
7. `tests/test_cohort_methods_specs_models.py` — replace fixtures.
8. `tests/test_acp_cohort_methods_flow.py` — replace fixtures and assertions.
9. `tests/test_theseus_validation.py` — add coverage for `theseus_to_hanjae_recommendation()`.
10. `tests/cohort_methods_specs_flow_smoke_test.py` — replace request body.
11. `docs/SERVICE_REGISTRY.yaml` — update the `cohort_methods_specifications_recommendation` entry's request/response sketch.

Files **not** modified:

- `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R` (Hanjae's territory).
- `mcp_server/study_agent_mcp/tools/cohort_methods_prompt_bundle.py` (the bundle still serves the same Theseus assets).
- `theseus/customAtlasTemplate_v1.3.0_annotated.txt`.
- `tests/test_cohort_methods_prompt_bundle.py` (bundle behavior unchanged).
- `tests/test_acp_cohort_methods_route.py` (only checks SERVICES registration).

## 11. End-to-End Executability After This Change

With MCP, ACP, and Ollama all running, and with Hanjae's shell `acp_connect()`'d to the ACP URL:

1. Shell enters the free-text branch of analytic settings collection.
2. Shell calls `.acp_post("/flows/cohort_methods_specifications_recommendation", body)` with the §5.1 body.
3. Endpoint returns `{ status, recommendation, theseus_specifications, section_rationales, diagnostics }`.
4. Shell reads `response$recommendation`, writes the full response to `outputs/cm_acp_specifications_recommendation.json`, and writes `recommendation` itself to `outputs/cm_analytic_settings_recommendation.json`.
5. Shell uses `recommendation$profile_name` to update the `effective_analytic_settings` profile name. The other four section keys (`study_population`, …, `outcome_model`) are persisted to JSON but **not** merged into `effective_analytic_settings`. Generated `06_cm_spec.R` continues to read `cm_analysis_defaults.json`.

**What this change buys, end-to-end:** the flow runs against a real LLM, produces a structured, validated, defaults-backfilled recommendation, and Hanjae's shell completes the run with provenance recorded. **What it does not buy:** the recommendation flowing into the generated Strategus script. That requires §5.9 (downstream consumption of `cmAnalysis.json` or `cm_analytic_settings_recommendation.json` by `06_cm_spec.R`), which is shell-side work and out of scope here.

## 12. Test Strategy

1. `tests/test_cohort_methods_specs_models.py` — flat fields parse, missing description rejected, output validates Hanjae shape.
2. `tests/test_theseus_validation.py` — new unit tests on `theseus_to_hanjae_recommendation()`: TAR fields land only in `time_at_risk`; non-TAR `createStudyPopArgs` fields land in `study_population`; `cohortMethodDataArgs` nests under `study_population`; entire PS and outcome model subtrees pass through; `rec_status` field is honored; `defaults_snapshot` is echoed.
3. `tests/test_acp_cohort_methods_flow.py` — happy path emits Hanjae shape; backfill flips `recommendation.status` to `"backfilled"`; client cohort IDs survive into `theseus_specifications.cohortDefinitions`; missing description short-circuits to `llm_parse_error`; MCP failure raises.
4. `tests/cohort_methods_specs_flow_smoke_test.py` — live request body matches §5.1; assertion: `result["recommendation"]["raw_description"]` is non-empty and `result["theseus_specifications"]["cohortDefinitions"]["targetCohort"]["id"] == request.target_cohort_id`.
5. `dodo.py smoke_cohort_methods_specs_recommend_flow` — unchanged invocation; passes when ACP+MCP+LLM are up.

## 13. Out of Scope (Deferred / Other Owners)

Tracked separately in `STRATEGUS_COHORT_METHODS_STATUS_KO.md`:

- §5.1 comparator settings finalization (shell-side; Hanjae's highest-priority TODO).
- §5.2 intent-split prompt hardening (separate flow, owned upstream).
- §5.3 cached manual-input precedence (shell-side policy).
- §5.4 malformed cohort ID validation (shell-side).
- §5.5 incidence cache path resolution (shell-side; partially landed).
- §5.6 negative control / covariate concept set real import (cross-cutting MCP + shell).
- §5.8 incidence-shell structural alignment (shell-side refactor).
- §5.9 generated `06_cm_spec.R` consuming `cmAnalysis.json` directly (shell-side; downstream of this flow).
- §5.10 broader regression coverage (cross-cutting).
