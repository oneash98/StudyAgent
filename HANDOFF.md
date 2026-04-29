# Cohort Methods Shell Handoff

## 0. Current Update: Cohort Methods Intent Split

- A separate cohort-methods study intent split flow is now implemented:
  - ACP endpoint: `/flows/cohort_methods_intent_split`
  - MCP tool: `cohort_methods_intent_split`
  - Core helper: `cohort_methods_intent_split()`
- This is intentionally separate from the existing incidence-oriented `/flows/phenotype_intent_split`.
  - Existing `phenotype_intent_split` remains target/outcome only.
  - Cohort methods split returns target/comparator/outcome fields.
- Prompt assets live with the phenotype prompt assets:
  - `mcp_server/prompts/phenotype/overview_cohort_methods_intent_split.md`
  - `mcp_server/prompts/phenotype/spec_cohort_methods_intent_split.md`
  - `mcp_server/prompts/phenotype/output_schema_cohort_methods_intent_split.json`
- The cohort methods split output now supports multi-outcome at the ACP/MCP/Core contract layer:
  - `outcome_statement`: single compatibility / primary outcome statement
  - `outcome_statements`: list of one or more outcome statements
- `runStrategusCohortMethodsShell()` now attempts to use `/flows/cohort_methods_intent_split`
  to derive target/comparator/outcome statement defaults when explicit or cached statements are not already available.
  - Explicit function arguments still win.
  - Cached manual intent/input still win before ACP split.
  - Hardcoded target/comparator/outcome statement fallback has been removed.
    ACP unavailable or split failure now leaves statements empty and requires manual entry in interactive mode,
    or fails closed in non-interactive mode unless explicit/cached statements are supplied.
  - R shell now consumes `outcome_statements` and preserves `outcome_statement` as the primary/backward-compatible scalar.
  - When multiple outcome statements are available and explicit outcome IDs are not supplied, the shell runs
    outcome phenotype recommendation once per outcome statement.
  - Interactive UX now displays all suggested outcome statements and prompts `Outcome 1`, `Outcome 2`, etc.,
    with an option to add more outcome statements manually.
  - The shell persists `outcome_statements`, per-outcome `outcome_recommendations`,
    and `outcome_cohort_statements` in state artifacts where appropriate.
- LLM response parsing has been hardened for schema echo:
  - Some models returned the JSON schema object followed by the actual answer JSON.
  - `llm_client` now scans multiple JSON objects and chooses the one matching required keys.
- New/updated docs:
  - `docs/COHORT_METHODS_INTENT_SPLIT_STRUCTURE.md`
  - `docs/SERVICE_REGISTRY.yaml`
  - `docs/STRATEGUS_COHORT_METHODS_SHELL.md`
  - `docs/TESTING.md`
  - `README.md`
  - `CODING_AGENT_README.md`
- New smoke entry:
  - `tests/cohort_methods_intent_split_smoke_test.py`
  - `doit smoke_cohort_methods_intent_split_flow`

### Current Verification

- Passed targeted Python tests:
  - `python -m pytest -q tests/test_core_tools.py::test_cohort_methods_intent_split_llm tests/test_core_tools.py::test_cohort_methods_intent_split_backfills_outcome_statements tests/test_core_tools.py::test_cohort_methods_intent_split_requires_comparator_when_ok tests/test_core_tools.py::test_cohort_methods_intent_split_allows_clarification tests/test_acp_server.py::test_flow_cohort_methods_intent_split tests/test_acp_server.py::test_flow_cohort_methods_intent_split_schema_mismatch tests/test_mcp_prompt_bundle.py::test_cohort_methods_intent_split_bundle_schema`
  - `python -m pytest -q tests/test_mcp_prompt_bundle.py::test_cohort_methods_intent_split_bundle_schema tests/test_acp_server.py::test_flow_cohort_methods_intent_split tests/test_mcp_tools_registry.py::test_register_all_tools`
- Passed schema parse:
  - `python -m json.tool mcp_server/prompts/phenotype/output_schema_cohort_methods_intent_split.json`
- Passed R checks:
  - `Rscript -e "source('R/OHDSIAssistant/R/strategus_cohort_methods_shell.R')"`
  - Non-interactive cohort methods shell smoke with explicit target/comparator/outcome IDs.
- Passed current focused checks:
  - `python -m pytest -q tests/test_llm_client.py`
  - `python -m py_compile acp_agent/study_agent_acp/llm_client.py`
  - `git diff --check -- acp_agent/study_agent_acp/llm_client.py tests/test_llm_client.py`
  - `git diff --check -- R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
  - R source check using `C:/Program Files/R/R-4.5.3/bin/Rscript.exe`
  - R non-interactive explicit-ID smoke after hardcoded fallback removal
  - R mock-ACP multi-outcome smoke confirming two outcome recommendation calls
- Full `pytest` is currently blocked by local pytest temp/cache permission errors involving `pytest-cache-files-*`
  and `tmp/pytest-*` directories, not by observed test assertion failures.

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
- Cohort methods intent split is now active in the shell:
  - It writes/reads `outputs/cohort_methods_intent_split.json`.
  - It no longer falls back to fixed metformin/sulfonylurea/GI bleeding statements.
  - If ACP returns an error, interactive runs print a concise split error summary and continue to manual statement entry.
  - Non-interactive runs require explicit/cached statements or a successful split.
  - `outcome_statements` are normalized/deduplicated and can drive per-outcome phenotype recommendation.
  - `outcome_statement` remains the first/primary outcome for compatibility.
  - Per-outcome recommendation files use:
    - `outputs/recommendations_outcome.json`
    - `outputs/recommendations_outcome_2.json`
    - `outputs/recommendations_outcome_3.json`, etc.
  - `cm_comparisons.json` outcomes now include the statement mapped to the selected outcome cohort when available.
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
  - `tests/test_llm_client.py` passes after adding coverage for schema-echo followed by valid answer JSON.
  - Mock ACP multi-outcome R shell smoke confirmed:
    - split result can include GI bleeding and MACE as separate outcome statements
    - the shell creates separate outcome recommendation calls/files
    - selected outcome cohorts keep statement mappings in generated artifacts
  - Explicit-ID R shell smoke confirmed:
    - explicit statements and IDs bypass intent split/recommendation as intended
    - hardcoded statement fallback is no longer used

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
- ACP/MCP prompt-bundle calls can still be sensitive to the running ACP/MCP process version/state.
  If `/flows/cohort_methods_intent_split` returns `not_found` or `cohort_methods_intent_split_prompt_failed`,
  restart ACP/MCP from the current workspace before debugging the R shell.
- When re-testing intent split, remove stale caches such as:
  - `demo-strategus-cohort-methods/outputs/cohort_methods_intent_split.json`
  - `demo-strategus-cohort-methods/outputs/manual_inputs.json`
  - selected cohort cache directories if recommendation/selection behavior should be re-run from scratch.

## 4. Remaining TODO

- Highest-priority next steps:
  1. Finish comparator settings.
  2. Harden prompt instructions for cohort methods intent split so models do not echo the schema.
  3. Complete ACP/MCP implementation for analysis settings recommendation.
- Consider API-level structured output / response format support for intent split flows instead of relying
  only on prompt instructions and parser salvage.
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
  - interactive multi-outcome statement confirmation UX
  - stale cache behavior around multi-outcome split and selected outcome IDs
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
- Hardcoded cohort statement fallback was removed.
  - Reason: after cohort methods intent split became available, silent fallback to metformin/sulfonylurea/GI bleeding
    could hide ACP, MCP, or LLM failures and produce misleading downstream recommendations.
- `outcome_statement` remains as a scalar compatibility field, but `outcome_statements` is the multi-outcome source of truth.
  - Reason: downstream artifacts and older code paths still expect a primary outcome statement, while cohort methods
    studies can naturally include multiple outcomes such as GI bleeding and MACE.
- LLM parser salvage for schema echo was added.
  - Reason: small models may echo the output schema JSON before emitting the actual answer JSON; the parser now chooses
    the JSON object matching required keys rather than failing on the schema object.

## 6. Files Changed In This Session

- `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
- `acp_agent/study_agent_acp/llm_client.py`
- `tests/test_llm_client.py`
- `R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`
- `R/OHDSIAssistant/inst/templates/CM_ANALYSIS_TEMPLATE.md`

## 7. Current Git / Worktree Note

- As of this update, relevant modified/untracked files include:
  - `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
  - `acp_agent/study_agent_acp/llm_client.py`
  - `tests/test_llm_client.py`
  - `R/OHDSIAssistant/inst/templates/` (new)

## 8. Best Next Step

- If continuing product behavior:
  - first finish comparator settings
  - then complete ACP/MCP support for analysis settings recommendation
- If continuing hardening:
  - add full-shell regression coverage for `step_by_step` and cache/resume paths
- If continuing UX:
  - decide whether to keep the current selective wizard permanently or expose more non-core settings later

---

## 2026-04-29: Cohort Methods Specifications Recommendation 재정렬 + ACP LLM 파서 fix

`/flows/cohort_methods_specifications_recommendation` 의 wire contract를 `strategus_cohort_methods_shell.R`가 이미 보내고/파싱하는 모양에 맞춰 재정렬하고, 실제 happy-path를 막던 ACP 파서 버그 하나를 같이 잡았음.

### 한 일

- **Pydantic envelope 재정렬** (`core/study_agent_core/models.py`): nested `cohort_definitions` / `negative_control_concept_set` / `covariate_selection` / `current_specifications` → flat IDs (`target_cohort_id`, `comparator_cohort_id`, `outcome_cohort_ids`, `comparison_label`, `defaults_snapshot`). 응답 모양도 `specifications` / `sectionRationales`(camelCase) → `recommendation` / `theseus_specifications` / `section_rationales` triple.
- **Theseus → Hanjae projector 추가** (`core/study_agent_core/theseus_validation.py`): `theseus_to_hanjae_recommendation()` 순수 헬퍼. TAR 4개 키 → `time_at_risk`, 나머지 `createStudyPopArgs` + `getDbCohortMethodDataArgs` → `study_population.cohortMethodDataArgs`. 모두 deepcopy.
- **ACP flow handler 재작성** (`acp_agent/study_agent_acp/agent.py:411`): flat IDs 입력, 내부에서 `cohortDefinitions` 조립 → `merge_client_metadata` (LLM drift override) → 섹션별 validate/backfill → projector. Theseus 문서는 `theseus_specifications`로 traceability 유지.
- **ACP HTTP route 갱신** (`acp_agent/study_agent_acp/server.py:285`): 새 Pydantic 필드 그대로 통과.
- **R 래퍼 정렬** (`R/OHDSIAssistant/R/cohort_methods_workflow.R`): `suggestCohortMethodSpecs()`가 셸이 보내는 flat body 그대로 전송, `recommendation` / `theseus_specifications` / `section_rationales` 응답 파싱. 로컬 stub도 wire 모양 그대로.
- **Bug fix:** flow가 존재하지 않는 `parsed_payload` 속성을 보고 있어서 모든 실제 LLM 응답이 fallback(`backfilled`)으로 떨어지던 문제 수정 → `parsed_content` 사용 + fenced-block 폴백을 `content_text`(메시지 본문)에서 추출. MagicMock 테스트도 `parsed_content`로 맞춰 회귀 가능하게.
- 스모크/`SERVICE_REGISTRY.yaml`/`R/OHDSIAssistant/README.md`/모식도/테스트 런북 업데이트.

### 검증

`test.md` 참조해서 그대로 따라가면 됨:

1. **Pre-flight** — env, `pip install -e .`, R 패키지, `pytest -k "cohort_methods or theseus"` 41 passed.
2. **ACP endpoint + MCP** — `doit smoke_cohort_methods_specs_recommend_flow` → `status: ok`, 4섹션 high|medium.
3. **Shell free_text 모드** — R REPL에서 `runStrategusCohortMethodsShell(... analyticSettingsDescription=...)` → `cm_acp_specifications_recommendation.json` 에 `source: acp_flow`, `recommendation.status: received`, `manual_inputs.json` 에 `confirmed_via_acp`.
4. **Shell step_by_step 모드** — `analyticSettingsDescription` 빼고 모드 prompt 에 `1` → ACP 호출 안 떠야 PASS, `cm_acp_specifications_recommendation.json` 생성 안 됨, `manual_inputs.json` 에 `step_by_step` / `not_applicable`.

본인 머신에서 3개 시나리오 모두 PASS 확인 (2026-04-29).

> ⚠️ 인터랙티브 셸은 `Rscript -e` 로 돌리면 `readline()` 이 비대화형이라 prompt 무한루프. R REPL 안에서 돌릴 것.

### 모식도

- `cohort_methods_architecture.png` — 레이어별 데이터 흐름 (R Shell → ACP route → Flow handler ↔ MCP/LLM/core helpers → Hanjae 응답)
- `cohort_methods_scenarios.png` — Hanjae 셸 진입부터 모든 분기 (`step_by_step` / `free_text` × description 출처 4종 × ACP 가용성 × HTTP/flow 상태)
- 소스: `cohort_methods_architecture.mmd`, `cohort_methods_scenarios.mmd`
