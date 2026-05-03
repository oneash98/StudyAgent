# Strategus Cohort Methods Shell (Stage 1)

Current stage scope:

- Cohort methods shell with ACP-assisted intent split and phenotype recommendation.
- The shell can derive target/comparator/outcome statements from a study intent.
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

If you only want to exercise the analytic-settings flow with stable demo inputs, use:

```r
OHDSIAssistant::runStrategusCohortMethodAnalyticSettingsTest(
  outputDir = "demo-strategus-cohort-methods-analytic-settings"
)
```

This helper skips the target/comparator/outcome selection prompts and writes only
analytic-settings-focused artifacts under `outputDir/outputs/`.

## Current Stage Flow

1. Manual collection of required identifiers:
   - `studyIntent`
2. ACP-assisted split of `studyIntent` into:
   - `targetStatement`
   - `comparatorStatement`
   - `outcomeStatement`
3. Role-specific phenotype recommendation / cache reuse for target, comparator, and outcome cohorts.
4. Optional cohort ID remap step to avoid collisions (`remapCohortIds`).
5. Copy cohort JSON definitions from `indexDir/definitions` into selected cohort folders.
6. Optional negative control and covariate concept-set IDs are captured as placeholders.
7. Configure one analytic-settings profile interactively:
   - Analytic settings are always collected in this stage.
   - Choose one mode first:
     - `step_by_step`
     - `free_text`
   - `step_by_step` currently walks through:
     - Study population settings
     - Time-at-risk settings
     - Propensity score adjustment settings
     - Outcome model settings
   - In `step_by_step`, the shell asks each category in order, asks for the core setting(s)
     first, then shows a `keep the defaults or choose each option yourself` prompt followed by the current
     default values for the remaining supported sub-settings.
   - After the profile name is entered, the shell prints the final resolved analytic settings once
     more for review.
   - The analytic-settings profile name is prompted after all four sections are complete.
   - `free_text` first uses `analyticSettingsDescription` when provided.
   - If that is absent, it next uses `analyticSettingsDescriptionPath` when provided.
   - If neither is provided, the shell asks the user to type the description interactively.
   - `free_text` also writes a dummy recommendation artifact and requires confirmation before finalizing the cached state.
8. Write comparison metadata and TODO artifacts.
9. Generate scripts in `scripts/` for cohort generation, keeper review, diagnostics, CM spec, and CM run.

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

User-facing `step_by_step` prompts now follow the ATLAS section grouping, but keep the previously
agreed shell interaction pattern:

- ask only the section's core settings directly
- then offer a keep-defaults step for the remaining hidden/default settings
- if the user declines defaults, ask each remaining exposed setting one by one
- show short setting names only in default summaries and final summaries
- show detailed per-setting descriptions only in the one-by-one customization path

Exception for propensity score adjustment:

- first ask the strategy: `match_on_ps`, `stratify_by_ps`, or `none`
- if `match_on_ps`, ask only `maxRatio`
- if `stratify_by_ps`, ask only `numberOfStrata`
- after that, show the remaining PS defaults and ask whether to keep them
- if the user declines defaults, ask the exposed remaining PS settings one by one
- exposed PS trimming settings in that remaining-defaults path:
  `trimmingStrategy` with `none`, `by_percent`, or `by_equipoise`
- if trimming is customized to `by_percent`, the shell asks for the trimming percent
- if trimming is customized to `by_equipoise`, the shell asks for the lower and upper
  equipoise bounds
- match defaults currently exposed in that remaining-defaults path:
  `maxCohortSizeForFitting`, `errorOnHighCorrelation`, `useRegularization`, `caliper`,
  `caliperScale`
- stratify defaults currently exposed in that remaining-defaults path:
  `maxCohortSizeForFitting`, `errorOnHighCorrelation`, `useRegularization`, `baseSelection`
- hidden internal defaults such as `create_ps.estimator` still remain persisted but are not
  directly prompted

Internally, the persisted JSON still uses the existing `CohortMethod`-aligned field names.

Current execution defaults and persisted artifacts use the following effective analytic-settings fields:

- `profile_name`
- Study population
  - `studyStartDate`
  - `studyEndDate`
  - `maxCohortSize`
  - `firstExposureOnly`
  - `washoutPeriod`
  - `restrictToCommonPeriod`
  - `removeDuplicateSubjects`
  - `censorAtNewRiskWindow`
  - `removeSubjectsWithPriorOutcome`
  - `priorOutcomeLookback`
- Covariate settings
  - current default covariate behavior
  - include-all state
  - include concept-set selection
  - exclude concept-set selection
- Time-at-risk
  - `minDaysAtRisk`
  - `riskWindowStart`
  - `startAnchor`
  - `riskWindowEnd`
  - `endAnchor`
- Propensity score adjustment
  - `strategy`
  - `trimmingStrategy`
  - `trimmingPercent`
  - `equipoiseLowerBound`
  - `equipoiseUpperBound`
  - `estimator`
  - `maxCohortSizeForFitting`
  - `errorOnHighCorrelation`
  - `useRegularization`
  - matching: `caliper`, `caliperScale`, `maxRatio`
  - stratification: `numberOfStrata`, `baseSelection`
- Outcome model
  - `modelType`
  - `stratified`
  - `useCovariates`
  - `inversePtWeighting`
  - `useRegularization`

For the currently supported hidden sub-settings, the shell displays the actual OHDSI /
CohortMethod defaults as values only when offering to keep defaults, using short setting names
instead of prompt-length explanatory text. If the user chooses to customize the remaining settings,
the shell now asks each exposed remaining setting individually and shows its detailed description at
that point. Hidden internal fields such as `create_ps.estimator` and extraction-level duplicate
handling remain persisted but are still not asked directly in the current prompt flow.

Important current default behavior:

- Matching defaults now follow CohortMethod defaults, including `maxRatio = 1`,
  `caliper = 0.2`, and `caliperScale = "standardized logit"`.
- PS fitting defaults currently exposed in the shell include:
  - `maxCohortSizeForFitting = 250000`
  - `errorOnHighCorrelation = FALSE`
  - `useRegularization = TRUE`
- PS trimming defaults currently exposed in the shell include:
  - `trimmingStrategy = none`
  - `trimmingPercent = 5`
  - `equipoise bounds = c(0.25, 0.75)`
- Time-at-risk defaults now follow CohortMethod defaults, including `riskWindowStart = 0`
  and `censorAtNewRiskWindow = FALSE`.
- Outcome-model defaults are partially dynamic:
  - `stratified = FALSE` for no PS adjustment
  - `stratified = FALSE` for one-to-one matching (`maxRatio = 1`)
  - `stratified = TRUE` for variable-ratio matching and PS stratification
  - `useCovariates = FALSE`
  - `inversePtWeighting = FALSE`
  - `useRegularization = TRUE`

The effective selected profile is written to `outputs/cm_analysis_defaults.json`, which retains
profile metadata such as `profile_name`, `source`, and `customized_sections`. The generated
`scripts/06_cm_spec.R` combines those defaults with `outputs/cm_comparisons.json` and the selected
cohort definitions to create a Strategus analysis specification.

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
- `cohort_methods_intent_split.json`
- `cohort_id_map.json`
- `cohort_roles.json`
- `cm_comparisons.json`
- `cm_analysis_defaults.json`
- `cm_analytic_settings_recommendation.json` (free-text mode only)
- `cm_concept_set_selections.json`
- `improvements_target.json`
- `improvements_comparator.json`
- `improvements_outcome.json`
- `improvements_status.json`
- `cm_evaluation_todo.json`
- `acp_mcp_todo.json`
- `study_agent_state.json`

`cm_analysis_defaults.json` stores the effective analytic-settings profile used by the generated
`06_cm_spec.R` when projecting shell settings into Strategus module specifications.

`manual_inputs.json` is the cache/resume-friendly shell artifact for the same run. It includes the
effective `analytic_settings` object plus `customized_sections`.

`06_cm_spec.R` reads the expanded analytic-settings schema and uses it directly when constructing
the CohortMethod module settings:

- `getDbCohortMethodDataArgs`
- `createStudyPopulationArgs`
- `createPsArgs`
- `matchOnPsArgs`
- `fitOutcomeModelArgs`

It also writes `analysis-settings/analysisSpecification.json`, a Strategus specification containing:

- a shared cohort-definition resource
- `CharacterizationModule`
- `CohortIncidenceModule`
- `CohortMethodModule`

The generated Strategus specification intentionally omits `CohortGeneratorModule` and
`CohortDiagnosticsModule` because cohort generation and diagnostics are handled by
`03_generate_cohorts.R` and `05_diagnostics.R`.

The same `06_cm_spec.R` script then executes the just-created specification with
`Strategus::execute()`. There is no separate `07_cm_run_analyses.R` in the merged Strategus
CohortMethod flow.

## Generated Scripts

- `scripts/02_apply_improvements.R`
- `scripts/03_generate_cohorts.R`
- `scripts/04_keeper_review.R`
- `scripts/05_diagnostics.R`
- `scripts/06_cm_spec.R`

Generated scripts that connect to the database expect these site-specific files at the root of
`outputDir`:

- `strategus-db-details.json`
- `strategus-execution-settings.json`

The scripts still contain placeholders for values that are not captured in those files yet, such as
`databaseId` for Keeper/export steps.

## Current Boundaries

- `phenotype_improvements` is wired for target, comparator, and outcome cohorts. The shell writes
  role-specific improvement artifacts after prompting whether to run improvements for each role,
  can apply mutating actions (`set`, `replace`, `update`), keeps advisory `note` actions as
  recommendations, and keeps `patched-cohorts/` complete for downstream scripts when any mutating
  improvement is applied.
- Remaining deferred integration points:
  - comparator reuse lookup
  - phenotype index search for suggestion workflows
- Atlas settings deferred in this stage:
  - negative control cohort-definition logic
  - positive control synthesis
  - empirical calibration configuration
  - minimum days at risk
  - PS trimming
  - IPTW execution branches
  - detailed covariate feature-group selection beyond the current default-plus-include/exclude model
- Evaluation settings from section 12.7.3 remain deferred as well.
- Multiple analytic-settings profiles, multi-comparison support, and broader CohortMethod branching
  remain for a later stage.
- Script TODO comments document where these extensions are expected.

## Notes

- This stage is designed as a bridge: it provides structured inputs and reproducible
  script generation before ACP/MCP-assisted recommendations and improvement loops are connected.
