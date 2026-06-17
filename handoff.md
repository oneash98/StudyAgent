# Cohort Methods cmAnalysis Handoff

## Current State

- The cohort-method analysis settings now use the actual `cmAnalysis` template shape from the provided research files.
- Source template files are:
  - `mcp_server/prompts/cohort_methods/cmAnalysis_template.json`
  - `R/slashOhdsiStrategusAssistant/inst/templates/cmAnalysis_template.json`
  - `mcp_server/prompts/cohort_methods/CM_ANALYSIS_TEMPLATE.md`
- The incorrect `scmAnalysis_template.json` files created during the earlier mistaken pass were removed.

## Actual cmAnalysis Shape

The top-level analysis specification keys are:

- `getDbCohortMethodDataArgs`
- `createStudyPopArgs`
- `psSettings`
- `createPsArgs`
- `fitOutcomeModelArgs`

Multiple analysis settings are represented only through array fields already present in the template:

- `getDbCohortMethodDataArgs.studyPeriods`
- `createStudyPopArgs.timeAtRisks`
- top-level `psSettings`
- `fitOutcomeModelArgs.outcomeModels`

Important details:

- There is no top-level `description` in the actual template.
- There is no `propensityScoreAdjustment` object in the actual template.
- There is no `fitOutcomeModelArgs.outcomeModelSettings` in the actual template.
- `createPsArgs` is top-level, not repeated inside each PS setting.
- `fitOutcomeModelArgs.stratified`, `prior`, and `control` are top-level outcome-model settings, not repeated inside each outcome model.

## Implemented Changes

- Replaced MCP and R package `cmAnalysis_template.json` with the attached research template structure.
- Replaced `CM_ANALYSIS_TEMPLATE.md` with the attached field notes content.
- Updated `cohort_methods_prompt_bundle` to load `cmAnalysis_template.json` directly and to accept the field notes document without requiring a `## Top-Level Shape` marker.
- Updated cohort-method spec validation to validate the real top-level keys and list fields.
- Updated ACP cohort-method recommendation flow to validate `psSettings` and `createPsArgs` as separate sections.
- Updated the R shell cmAnalysis builder so saved `cmAnalysis.json` uses the real template shape.
- Preserved R shell internal compatibility fields where needed for existing shell/script-generation code, but those should not leak into the saved `cmAnalysis.json`.
- Prompt instruction was adjusted to stay close to the research prompt while retaining section-level rationale and confidence requirements.

## R Shell Behavior

`.studyAgentBuildCmAnalysisJson()` now emits:

- `getDbCohortMethodDataArgs.studyPeriods`
- `createStudyPopArgs.timeAtRisks`
- top-level `psSettings`
- top-level `createPsArgs`
- `fitOutcomeModelArgs.outcomeModels`
- top-level `fitOutcomeModelArgs.stratified`

Outcome stratification is derived from PS settings:

- `TRUE` for PS stratification.
- `TRUE` for variable-ratio matching.
- `FALSE` for 1:1 matching, IPTW, or no matching.

IPTW is represented as:

- `psSettings[].inversePtWeighting = true`
- `matchOnPsArgs = null`
- `stratifyByPsArgs = null`

## Not Yet Changed

- Strategus script generation blocks were intentionally not redesigned for multiple analyses yet.
- Existing generated-script static tests still target the current script-generation behavior.
- Internal R cache keys may still use names such as `fit_outcome_model.outcomeModelSettings`; these are compatibility fields, not final cmAnalysis JSON fields.

## Verification Run

- `python -m py_compile core/study_agent_core/cohort_methods_spec_validation.py mcp_server/study_agent_mcp/tools/cohort_methods_prompt_bundle.py acp_agent/study_agent_acp/agent.py`
- `Rscript -e "invisible(parse(file='R/slashOhdsiStrategusAssistant/R/strategus_cohort_methods_shell.R'))"`
- R cmAnalysis builder smoke test for:
  - expected top-level keys
  - no `propensityScoreAdjustment`
  - no top-level `description`
  - `fitOutcomeModelArgs.outcomeModels`
  - IPTW behavior
  - variable-ratio stratification behavior
- `python -m pytest -q tests/test_cohort_methods_prompt_bundle.py tests/test_cohort_methods_spec_validation.py tests/test_acp_cohort_methods_flow.py tests/test_acp_cohort_methods_route.py tests/test_cohort_methods_specs_models.py tests/test_mcp_tools_registry.py tests/test_mcp_prompt_bundle.py`
  - Result: `49 passed`
- `python -m pytest -q tests/test_cohort_methods_generated_scripts.py tests/test_r_workflow_context_dialogue_wrapper.py tests/test_cohort_methods_shell_recommendation_support.py tests/test_cohort_methods_specs_models.py tests/test_mcp_tools_registry.py`
  - Result: `19 passed, 3 skipped`

## Next Step

The next large change should focus on how multiple `studyPeriods`, `timeAtRisks`, `psSettings`, and `outcomeModels` should expand into Strategus analyses or CohortMethod analysis objects. That should be designed separately from the current analysis-setting capture work.

Before making that next large change, the user wants to manually check the current step-by-step shell flow first. If the user later asks to continue or modify the workflow, pause and ask them to run or confirm the manual step-by-step check before changing the next layer. In particular, do not assume the current prompt order, defaults, labels, sensitivity-analysis prompts, or review screen are acceptable until the user has inspected them.

After all required implementation changes are complete, update the relevant docs before calling the work finished. At minimum, review the cohort-method shell and workflow docs for stale references to the old single-analysis shape or any outdated analytic-settings behavior.
