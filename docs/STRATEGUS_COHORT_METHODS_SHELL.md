# Strategus Cohort Methods Shell (Stage 1)

Current stage scope:

- Manual shell only.
- No ACP or MCP calls are executed inside the shell.
- The shell writes reproducible R script scaffolds for later CohortMethod execution.

This shell is provided as `OHDSIAssistant::runStrategusCohortMethodsShell()`.

## Running

```r
OHDSIAssistant::runStrategusCohortMethodsShell(
  outputDir = "demo-strategus-cohort-methods",
  studyIntent = "Compare metformin versus sulfonylurea on GI bleed outcomes.",
  targetCohortId = 12345,
  comparatorCohortId = 23456,
  outcomeCohortIds = c(34567, 45678),
  comparisonLabel = "metformin_vs_sulfonylurea"
)
```

## Current Stage Flow

1. Manual collection of required identifiers:
   - `studyIntent`
   - `targetCohortId` (single ID)
   - `comparatorCohortId` (single ID)
   - `outcomeCohortIds` (one or more IDs)
2. Optional cohort ID remap step to avoid collisions (`remapCohortIds`).
3. Copy cohort JSON definitions from `indexDir/definitions` into selected cohort folders.
4. Optional negative control and covariate concept-set IDs are captured as placeholders.
5. Configure one analytic-settings profile interactively:
   - Analytic settings are always collected in this stage.
   - Choose one mode first:
     - `step_by_step`
     - `free_text`
   - `step_by_step` currently walks through:
     - Study population settings
     - Time-at-risk settings
     - Propensity score adjustment settings
     - Outcome model settings
   - Detailed prompts inside those sections are still TODO in the current stage, so defaults are kept for now.
   - `free_text` first uses `analyticSettingsDescription` when provided.
   - If that is absent, it next uses `analyticSettingsDescriptionPath` when provided.
   - If neither is provided, the shell asks the user to type the description interactively.
   - `free_text` also writes a dummy recommendation artifact and requires confirmation before finalizing the cached state.
6. Write comparison metadata and TODO artifacts.
7. Generate scripts in `scripts/` for cohort generation, keeper review, diagnostics, CM spec, and CM run.

## Analytic Settings

The cohort methods shell now prompts for a single effective analytic-settings profile. This remains
prompt/cache-driven only; there is no public analytic-settings function argument added in this
stage.

Supported configuration modes:

- `step_by_step`
- `free_text`

Current `step_by_step` section flow:

- `study_population`
- `time_at_risk`
- `propensity_score_adjustment`
- `outcome_model`

Current execution defaults still use the same effective analytic-settings fields:

- `profile_name`
- Study population
  - `firstExposureOnly`
  - `washoutPeriod`
  - `restrictToCommonPeriod`
  - `removeDuplicateSubjects`
  - `removeSubjectsWithPriorOutcome`
  - `priorOutcomeLookback`
  - `censorAtNewRiskWindow`
- Covariate settings
  - current default covariate behavior
  - include-all state
  - include concept-set selection
  - exclude concept-set selection
- Time-at-risk
  - `riskWindowStart`
  - `startAnchor`
  - `riskWindowEnd`
  - `endAnchor`
- Propensity score adjustment
  - `estimator`
  - `maxCohortSizeForFitting`
  - `caliper`
- `caliperScale`
- `maxRatio`
- Outcome model
  - `modelType`
  - `stratified`

The effective selected profile is written to `outputs/cm_analysis_defaults.json`, which retains
profile metadata such as `profile_name`, `source`, and `customized_sections` and remains the
canonical analytic-settings artifact consumed by `scripts/06_cm_spec.R`.

For traceability:

- `outputs/manual_inputs.json` stores the effective `analytic_settings` block plus the
  `customized_sections` array, the selected analytic-settings mode, and any free-text metadata.
- `outputs/cm_analytic_settings_recommendation.json` is written only for `free_text` mode in the
  current stage. It is a dummy recommendation artifact for review/confirmation and is not the
  execution defaults file.
- `outputs/study_agent_state.json` echoes `analytic_settings_profile_name` and
  `analytic_settings_customized_sections`, plus analytic-settings mode / confirmation summary.

## Output Layout

The following directories are created under `outputDir`:

- `outputs/`
- `selected-cohorts/`
- `selected-target-cohorts/`
- `selected-comparator-cohorts/`
- `selected-outcome-cohorts/`
- `patched-cohorts/`
- `patched-target-cohorts/`
- `patched-comparator-cohorts/`
- `patched-outcome-cohorts/`
- `keeper-case-review/`
- `analysis-settings/`
- `scripts/`
- `cm-results/`
- `cm-diagnostics/`
- `cm-data/`

### `outputs/` artifacts

- `manual_intent.json`
- `manual_inputs.json`
- `cohort_id_map.json`
- `cohort_roles.json`
- `cm_comparisons.json`
- `cm_analysis_defaults.json`
- `cm_analytic_settings_recommendation.json` (free-text mode only)
- `cm_concept_set_selections.json`
- `improvements_status.json`
- `cm_evaluation_todo.json`
- `acp_mcp_todo.json`
- `study_agent_state.json`

`cm_analysis_defaults.json` stores the canonical effective analytic-settings profile used by the
generated `06_cm_spec.R`.

`manual_inputs.json` is the cache/resume-friendly shell artifact for the same run. It includes the
effective `analytic_settings` object plus `customized_sections`.

`06_cm_spec.R` reads the expanded analytic-settings schema and uses it directly when constructing:

- `getDbCohortMethodDataArgs`
- `createStudyPopulationArgs`
- `createPsArgs`
- `matchOnPsArgs`
- `fitOutcomeModelArgs`

## Generated Scripts

- `scripts/03_generate_cohorts.R`
- `scripts/04_keeper_review.R`
- `scripts/05_diagnostics.R`
- `scripts/06_cm_spec.R`
- `scripts/07_cm_run_analyses.R`

Each script is generated as a runnable scaffold and contains placeholders (for example
`<FILL IN>`) where site-specific settings are required, especially connection and
execution details.

## TODO Boundaries (Current Stage)

- ACP integration points are currently deferred:
  - `phenotype_intent_split`
  - `phenotype_recommendation` for target/comparator/outcomes
  - `phenotype_recommendation_advice`
  - `phenotype_improvements`
  - comparator reuse lookup
  - phenotype index search for suggestion workflows
- Atlas settings deferred in this stage:
  - negative control cohort-definition logic
  - positive control synthesis
  - empirical calibration configuration
  - study start/end date restrictions
  - minimum days at risk
  - PS trimming
  - stratification and IPTW execution branches
  - covariate correlation checks
  - regularization toggles
  - detailed covariate feature-group selection beyond the current default-plus-include/exclude model
- Evaluation settings from section 12.7.3 remain deferred as well.
- Multiple analytic-settings profiles, multi-comparison support, and broader CohortMethod branching
  remain for a later stage.
- Script TODO comments document where these extensions are expected.

## Notes

- This stage is designed as a bridge: it provides structured inputs and reproducible
  script generation before ACP/MCP-assisted recommendations and improvement loops are connected.
