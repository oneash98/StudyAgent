# Cohort Methods Shell Handoff

## 1. Completed Work

- `runStrategusCohortMethodsShell()` remains the main active shell entrypoint in:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
- The shell still writes the same core output/artifact structure, including:
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
- The shell now also writes a template-shaped CohortMethod analysis settings JSON:
  - `analysis-settings/cmAnalysis.json`
  - The path is echoed in `outputs/manual_inputs.json`, `outputs/study_agent_state.json`,
    and `outputs/cm_analysis_defaults.json`.
  - This is separate from `outputs/` state/cache artifacts; it is the analysis-settings
    contract artifact intended for CohortMethod-oriented downstream use.
- The executable JSON template and explanation live under:
  - `R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`
  - `R/OHDSIAssistant/inst/templates/CM_ANALYSIS_TEMPLATE.md`
- `CM_ANALYSIS_TEMPLATE.md` explicitly documents that this structure is a temporary
  StudyAgent-specific contract for the Strategus CohortMethod shell, not a public
  OHDSI / Strategus / CohortMethod schema.
- Study start/end date prompts now ask users for `YYYYMMDD` directly, and validation rejects
  `YYYY-MM-DD` instead of silently converting it.
- The generated script scaffolds are still present:
  - `03_generate_cohorts.R`
  - `04_keeper_review.R`
  - `05_diagnostics.R`
  - `06_cm_spec.R`
  - `07_cm_run_analyses.R`
- Cohort/concept-set validation, cache/resume behavior, repeated outcome ID entry, and placeholder concept-set capture remain in place.
- Analytic settings are still always collected, with mode selection:
  - `step_by_step`
  - `free_text`
- `free_text` mode behavior is unchanged in broad shape:
  - description resolution order:
    - `analyticSettingsDescription`
    - `analyticSettingsDescriptionPath`
    - cached description/path
    - interactive typed input
  - dummy recommendation artifact:
    - `outputs/cm_analytic_settings_recommendation.json`
  - placeholder ACP/stub artifact:
    - `outputs/cm_acp_specifications_recommendation.json`
- The major new work completed in this session is real `step_by_step` section-level prompting.
  - Section order is now actually implemented:
    - `study_population`
    - `time_at_risk`
    - `propensity_score_adjustment`
    - `outcome_model`
  - The analytic settings profile name is now asked after all four sections are complete.
  - `study_population` now asks the core settings first:
    - `studyStartDate`
    - `studyEndDate`
  - `time_at_risk` now asks the core settings first:
    - `startAnchor` + `riskWindowStart`
    - `endAnchor` + `riskWindowEnd`
  - `outcome_model` now asks the core setting first:
    - `modelType`
  - `propensity_score_adjustment` now asks the core settings first:
    - trimming strategy:
      - `none`
      - `by_percent`
      - `by_equipoise`
      - this is exposed only in the PS remaining-defaults customization path, not as a core question
    - strategy:
      - `match_on_ps`
      - `stratify_by_ps`
      - `none`
    - if `match_on_ps`, ask only:
      - `maxRatio`
    - if `stratify_by_ps`, ask only:
      - `numberOfStrata`
    - if `none`, no strategy-specific follow-up is asked
  - Every section now follows the same pattern:
    - ask the section's core settings first
    - show `keep defaults?` for the remaining exposed settings
    - if the user answers `No`, ask those remaining settings one by one
  - Default summaries and final summaries now use short labels only.
  - Detailed ATLAS-style descriptions are shown only in the one-by-one customization path.
  - A final resolved analytic-settings summary is printed after all sections complete.
- `step_by_step` now explicitly resets non-core section fields from system defaults instead of accidentally preserving cached overrides.
- The analytic-settings schema was expanded and wired through:
  - `get_db_cohort_method_data.studyStartDate`
  - `get_db_cohort_method_data.studyEndDate`
  - `ps_adjustment.strategy`
  - `ps_adjustment.trimmingStrategy`
  - `ps_adjustment.trimmingPercent`
  - `ps_adjustment.equipoiseLowerBound`
  - `ps_adjustment.equipoiseUpperBound`
  - `create_study_population.maxCohortSize`
  - `create_study_population.minDaysAtRisk`
  - `create_ps.maxCohortSizeForFitting`
  - `create_ps.errorOnHighCorrelation`
  - `create_ps.useRegularization`
  - `match_on_ps.caliper`
  - `match_on_ps.caliperScale`
  - `match_on_ps.maxRatio`
  - `stratify_by_ps.numberOfStrata`
  - `stratify_by_ps.baseSelection`
- `fit_outcome_model.useCovariates`
- `fit_outcome_model.inversePtWeighting`
- `fit_outcome_model.useRegularization`
- `match_on_ps.maxRatio` validation now allows `0`.
- `match_on_ps.maxRatio` default is now `1`.
- `cm_analysis_defaults.json` now includes:
  - `ps_adjustment`
  - `stratify_by_ps`
  - study start/end dates inside `get_db_cohort_method_data`
  - expanded PS defaults and trimming metadata
  - expanded outcome-model defaults
- `06_cm_spec.R` generation now uses the expanded defaults:
  - passes `studyStartDate` / `studyEndDate` into `createGetDbCohortMethodDataArgs()`
  - chooses `createPsArgs = NULL` when PS strategy is `none`
  - chooses `trimByPsArgs` from trimming settings:
    - `trimFraction` for `by_percent`
    - `equipoiseBounds` for `by_equipoise`
  - chooses `matchOnPsArgs` only for `match_on_ps`
  - chooses `stratifyByPsArgs` only for `stratify_by_ps`
  - adds PS `errorOnHighCorrelation`
  - derives PS regularization into the `prior` object used by `createCreatePsArgs()`
  - carries `useCovariates`, `inversePtWeighting`, and `useRegularization` into `createFitOutcomeModelArgs()`
  - derives outcome-model `stratified` defaults from PS strategy + `maxRatio`
- `customized_sections` is now recomputed from actual diffs versus system defaults instead of trusting cached section names.
- `effective_analytic_settings` is converted into `cmAnalysis.json` using a pure helper after
  final normalization. Conditional template fields are handled as follows:
  - `trimByPsArgs = null` when trimming is `none`
  - `matchOnPsArgs = null` unless strategy is `match_on_ps`
  - `stratifyByPsArgs = null` unless strategy is `stratify_by_ps`
  - `createPsArgs = null` only when both PS adjustment and PS trimming are `none`
  - regularization controls are expanded into `prior` / `control`, or `null` when disabled

## 2. Tests And Verification Completed

- `Rscript -e "source('R/OHDSIAssistant/R/strategus_cohort_methods_shell.R')"` passes.
- Non-interactive smoke validation ran successfully with:
  - `targetCohortId = 6`
  - `comparatorCohortId = 7`
  - `outcomeCohortIds = c(8, 9)`
  - `interactive = FALSE`
  - `allowCache = FALSE`
  - `promptOnCache = FALSE`
  - `remapCohortIds = FALSE`
- Verified generated outputs under `/tmp/cm_shell_step_by_step_check/` showed the new analytic-settings fields in:
  - `outputs/cm_analysis_defaults.json`
  - `scripts/06_cm_spec.R`
- Added lightweight R package-level tests:
  - `R/OHDSIAssistant/tests/testthat.R`
  - `R/OHDSIAssistant/tests/testthat/test-step-by-step-analytic-settings.R`
- Added a lightweight analytic-settings-only helper for fast manual verification:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_analytic_settings.R`
- Added `testthat` package metadata to:
  - `R/OHDSIAssistant/DESCRIPTION`
- Added `.gitignore` exceptions so these R test files are not swallowed by the repo-wide `test*.R` ignore rule.
- Local `testthat` execution passes by sourcing:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
  - `R/OHDSIAssistant/tests/testthat/test-step-by-step-analytic-settings.R`
- Current session verification also completed:
  - `python -m json.tool R/OHDSIAssistant/inst/templates/cmAnalysis_template.json` passes.
  - `Rscript` source check passes using the installed R path:
    `C:/Program Files/R/R-4.5.3/bin/Rscript.exe`.
  - A non-interactive shell smoke run generated and parsed
    `analysis-settings/cmAnalysis.json`.
  - Helper checks confirmed the `null` rules for no-PS/no-trim and stratify/equipoise cases.
  - Date validation now accepts `YYYYMMDD` and rejects `YYYY-MM-DD`.

## 3. In-Progress / Important Current State

- `free_text` analytic settings still use a placeholder ACP/stub flow; ACP-side implementation is still missing.
- The overall ACP integration is still only partially aligned with `strategus_incidence_shell.R`.
  - cohort methods still uses a local fallback helper
  - it does not yet fully reuse the incidence shell's `acp_connect()` + `acp_try()` + checkpoint/retry pattern
- `step_by_step` is now functional, but it is still intentionally selective:
  - it does not expose every possible CohortMethod parameter
  - it uses a core-setting-first UX with defaults for the rest
- The current user-facing prompt flow is now intentionally ATLAS-shaped but not ATLAS-complete:
  - it matches the requested section grouping and prompt order
  - it still exposes only the agreed subset of settings
- The shell now persists a template-shaped `analysis-settings/cmAnalysis.json` artifact, while
  `outputs/cm_analysis_defaults.json` remains in place for current generated-script compatibility.
- `06_cm_spec.R` still reads `outputs/cm_analysis_defaults.json`; it has not yet been switched
  to consume `analysis-settings/cmAnalysis.json` directly.

## 4. Remaining TODO

- Highest-priority next steps:
  1. Finish comparator settings.
  2. Complete ACP/MCP implementation for analysis settings recommendation.
- Implement the real ACP flow:
  - `/flows/cohort_methods_specifications_recommendation`
- Decide whether cohort methods ACP behavior should fully match incidence-shell behavior or intentionally remain more fault-tolerant.
- Refactor cohort methods ACP handling to match incidence shell more closely if desired:
  - explicit `acp_connect(acpUrl)`
  - shared `acp_try()`-style wrapper
  - consistent retry/checkpoint behavior
- Add ACP integration for comparator setting if that is still desired.
- Replace dummy recommendation generation with real recommendation parsing/mapping from ACP output.
- Decide and implement the final ACP response schema for cohort method specifications.
- Decide whether the generated `06_cm_spec.R` should continue reading `cm_analysis_defaults.json` directly or instead consume a more explicit analytic-settings JSON contract.
- Decide whether covariate settings should stay outside the required step-by-step section flow or be folded back in later.
- Add broader regression coverage for:
  - full shell `step_by_step` runs
  - `free_text` mode with `analyticSettingsDescription`
  - `free_text` mode with `analyticSettingsDescriptionPath`
  - ACP stub fallback
  - cache/resume behavior
- Clean up or share helper logic between:
  - `R/OHDSIAssistant/R/strategus_incidence_shell.R`
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`

## 5. Important Decisions And Why

- Analytic settings remain mandatory.
  - Reason: this keeps cohort-method configuration explicit for every run.
- The shell still uses two modes:
  - `step_by_step`
  - `free_text`
  - Reason: this preserves the current UX split while ACP recommendations are still under development.
- `step_by_step` now follows a constrained wizard model instead of “ask everything.”
  - Reason: the user wanted one category at a time, core settings first, and defaults for the rest.
- For PS settings:
  - `match_on_ps` now asks only `maxRatio` as the core question
  - `stratify_by_ps` now asks only `numberOfStrata` as the core question
  - trimming is not asked as a core PS question; it is exposed only when the user declines PS defaults
  - the remaining PS settings are shown in a `keep defaults?` summary and can now be customized one by one if the user answers `No`
  - Reason: this matches the user's final requested PS UX.
- `maxRatio` now defaults to `1`.
  - Reason: explicit user request to align defaults with OHDSI / CohortMethod behavior.
- `maxRatio = 0` is now valid.
  - Reason: explicit user request, aligned with the intended “no maximum” semantics.
- Profile name is now collected last in `step_by_step`.
  - Reason: explicit user requirement during this session.
- Outcome-model `useRegularization` is now exposed and persisted.
  - Reason: explicit user requirement during this session.
- PS common defaults now include:
  - `maxCohortSizeForFitting`
  - `errorOnHighCorrelation`
  - `useRegularization`
  - Reason: explicit user requirement during this session.
- PS trimming now supports:
  - `none`
  - `by_percent`
  - `by_equipoise`
  - with equipoise defaults `0.25 / 0.75`
  - Reason: explicit user requirement during this session, aligned to OHDSI references.
- `customized_sections` is computed from actual values versus defaults.
  - Reason: avoids stale cache-driven section labels and better reflects the real effective configuration.

## 6. Files Changed In This Session

- `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
- `R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`
- `R/OHDSIAssistant/inst/templates/CM_ANALYSIS_TEMPLATE.md`

## 7. Current Git / Worktree Note

- As of this update, relevant modified/untracked files include:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
  - `R/OHDSIAssistant/inst/templates/` (new)

## 8. Best Next Step

- If continuing product behavior:
  - first finish comparator settings
  - then complete ACP/MCP support for analysis settings recommendation
- If continuing hardening:
  - add full-shell regression coverage for `step_by_step` and cache/resume paths
- If continuing UX:
  - decide whether to keep the current selective wizard permanently or expose more non-core settings later
