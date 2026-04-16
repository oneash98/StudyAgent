# Cohort Methods Shell Handoff

## 1. Completed Work

- Added and exported `runStrategusCohortMethodsShell()` in:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
  - `R/OHDSIAssistant/NAMESPACE`
- Implemented the cohort methods shell output/artifact structure, including:
  - `manual_intent.json`
  - `manual_inputs.json`
  - `cohort_id_map.json`
  - `cohort_roles.json`
  - `cm_comparisons.json`
  - `cm_analysis_defaults.json`
  - `cm_concept_set_selections.json`
  - `study_agent_state.json`
  - `acp_mcp_todo.json`
  - `improvements_status.json`
  - `cm_evaluation_todo.json`
- Implemented generated script scaffolds:
  - `03_generate_cohorts.R`
  - `04_keeper_review.R`
  - `05_diagnostics.R`
  - `06_cm_spec.R`
  - `07_cm_run_analyses.R`
- Added cohort/concept set validation and cache/resume behavior.
- Changed outcome collection to repeated single-ID entry with `Add another outcome cohort id?`.
- Added optional negative control concept set and covariate concept set placeholder capture.
- Added analytic settings artifacts and schema wiring into `06_cm_spec.R`.
- Moved cohort ID remap prompt to run before analytic settings configuration.
- Changed analytic settings flow so it is always collected.
- Added analytic settings mode selection:
  - `1. Step-by-step`
  - `2. Free-text`
- Added explanatory prompt text for the two analytic settings modes.
- Implemented current `step_by_step` flow as section-order guidance only:
  - `study_population`
  - `time_at_risk`
  - `propensity_score_adjustment`
  - `outcome_model`
  - detailed prompts inside those sections are still TODO
- Implemented current `free_text` flow so description input is resolved in this order:
  - `analyticSettingsDescription`
  - `analyticSettingsDescriptionPath`
  - interactive typed input
- Added dummy recommendation artifact generation for free-text mode:
  - `outputs/cm_analytic_settings_recommendation.json`
- Added placeholder ACP/stub call stage after study description is available in free-text mode:
  - flow name: `cohort_methods_specifications_recommendation`
  - response artifact: `outputs/cm_acp_specifications_recommendation.json`
- Added graceful stub fallback when ACP is unavailable, ACP helpers are not loaded, or the flow is unimplemented.
- Updated docs:
  - `docs/STRATEGUS_COHORT_METHODS_SHELL.md`
  - `R/OHDSIAssistant/README.md`

## 2. In-Progress Work

- The cohort methods shell now calls a placeholder ACP/stub flow for free-text analytic settings, but the ACP-side flow is not implemented yet.
- The overall ACP integration is only partially aligned with `strategus_incidence_shell.R`.
  - The current implementation uses a local helper in the cohort methods shell.
  - It does not yet fully reuse the incidence shell's `acp_connect()` + `acp_try()` pattern and checkpoint/retry behavior.
- The `step_by_step` analytic settings path currently establishes the intended flow only; it does not yet collect detailed values section-by-section.

## 3. Remaining TODO

- Implement the real ACP flow:
  - `/flows/cohort_methods_specifications_recommendation`
- Add ACP integration for comparator setting as well.
  - This should follow the same broad direction as the Strategus incidence shell's ACP-connected orchestration.
  - The exact call shape, timing, and flow contract are still to be decided.
- Decide whether cohort methods ACP behavior should fully match incidence shell behavior or intentionally remain more fault-tolerant.
  - Incidence shell currently fails hard on ACP problems in non-interactive mode.
  - Cohort methods currently falls back to a stub placeholder.
- Refactor cohort methods ACP handling to match incidence shell more closely if desired:
  - explicit `acp_connect(acpUrl)` phase
  - shared `acp_try()`-style wrapper
  - consistent retry/checkpoint behavior
- Implement real section-level prompts for `step_by_step` analytic settings:
  - study population
  - time-at-risk
  - propensity score adjustment
  - outcome model
- Decide whether covariate settings should rejoin the required step-by-step analytic settings flow or remain separate as concept set placeholder handling.
- Replace dummy recommendation generation with real recommendation parsing/mapping from ACP output.
- Decide and implement the final response schema expected from ACP for cohort method specifications.
- Add lightweight regression coverage for:
  - step-by-step mode
  - free-text mode with `analyticSettingsDescription`
  - free-text mode with `analyticSettingsDescriptionPath`
  - ACP stub fallback
  - cache/resume behavior
- Clean up and possibly share duplicated helper logic between:
  - `strategus_incidence_shell.R`
  - `strategus_cohort_methods_shell.R`

## 4. Important Decisions And Why

- Analytic settings are now mandatory instead of optional.
  - Reason: this matches the updated shell flow requirement and makes analytic configuration an explicit part of every run.
- Analytic settings mode is selected first as `step_by_step` or `free_text`.
  - Reason: this keeps the UX clear and supports two future implementation paths.
- `step_by_step` currently preserves defaults and only walks the user through the intended sections.
  - Reason: the user asked to establish the flow now and leave detailed section-level configuration as TODO.
- `free_text` description resolution prefers function arguments over interactive input.
  - Reason: the user explicitly clarified that input method selection should not be another user-facing prompt.
- A separate ACP response artifact and a separate recommendation artifact are both written.
  - Reason: this keeps provenance clear:
    - ACP/stub response in `cm_acp_specifications_recommendation.json`
    - user-facing recommendation payload in `cm_analytic_settings_recommendation.json`
- Cohort methods ACP integration currently degrades to a stub instead of stopping.
  - Reason: ACP is not implemented yet, but the shell should still be runnable and produce traceable artifacts.
- The placeholder ACP flow name is already fixed as `cohort_methods_specifications_recommendation`.
  - Reason: this sets the contract target for the future ACP implementation.

## 5. Context Needed For The Next Session

- Main file under active development:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
- Related reference implementation:
  - `R/OHDSIAssistant/R/strategus_incidence_shell.R`
- Current free-text ACP/stub artifacts created during validation:
  - `tmp_validation/cm_acp_stub_check/outputs/cm_acp_specifications_recommendation.json`
  - `tmp_validation/cm_acp_stub_check/outputs/cm_analytic_settings_recommendation.json`
  - `tmp_validation/cm_acp_stub_check/outputs/manual_inputs.json`
  - `tmp_validation/cm_acp_stub_check/outputs/study_agent_state.json`
- Important current behavior:
  - If ACP client helpers are not loaded, cohort methods does not fail.
  - It records a stub placeholder ACP response and continues.
- Important gap:
  - The user asked whether the ACP calling structure was similar to cohort incidence.
  - The answer is: partially yes in intent/artifacts, but not yet structurally identical.
  - If the next step is “make it truly incidence-like,” the work should focus on adopting the same connection/retry/checkpoint pattern.
- Current git/worktree note:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R` is still untracked in the shown status.
  - `docs/STRATEGUS_COHORT_METHODS_SHELL.md` is also untracked in the shown status.
  - `R/OHDSIAssistant/README.md` and `R/OHDSIAssistant/NAMESPACE` are modified.
