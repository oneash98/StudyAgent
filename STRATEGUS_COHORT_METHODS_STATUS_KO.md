# Strategus Cohort Methods 현재 상태 정리

최종 업데이트 기준: 2026-04-28


## 1. 현재 이 셸이 맡는 역할

현재 `Strategus Cohort Methods` 셸은 `OHDSIAssistant::runStrategusCohortMethodsShell()`로 제공되며, cohort method study를 실행 가능한 Strategus/CohortMethod 형태로 넘기기 위한 R-side shell이다.

주요 역할은 아래와 같다.

1. cohort method study 설계에 필요한 study intent, cohort statements, cohort IDs, concept-set placeholders, analytic settings를 수집한다.
2. cohort methods 전용 `cohort_methods_intent_split`을 사용해 target/comparator/outcome statement를 얻는다.
3. target/comparator/outcome role별 phenotype recommendation 또는 selected cohort cache reuse를 통해 최종 cohort를 확정한다.
4. cohort methods 자체 cache와 cohort incidence shell에서 확정된 selected cohort cache를 가능한 경우 재사용한다.
5. 입력, 중간 판단, cache/source 정보, analytic settings, TODO를 artifact로 남긴다.
6. ACP 없이도 나중에 실행 가능한 순수 R script scaffold를 생성한다.

중요한 변경점은, 더 이상 metformin / sulfonylurea / GI bleeding 같은 hardcoded fixed statement fallback을 조용히 쓰지 않는다는 점이다. ACP intent split이 실패하고 explicit 또는 cached statement도 없으면, interactive 실행은 수동 입력으로 넘어가고 non-interactive 실행은 fail-closed 한다.


## 2. 현재 전체 흐름의 큰 구조

현재 cohort methods shell의 큰 흐름은 아래와 같다.

1. study intent 입력 또는 복원
2. explicit/cached statement 확인
3. 필요 시 ACP `/flows/cohort_methods_intent_split` 호출 또는 cached split artifact 재사용
4. target/comparator/outcome statements 확정
   - `outcome_statement`는 primary scalar compatibility field
   - `outcome_statements`는 multi-outcome source of truth
5. role별 explicit cohort ID 확인
6. explicit ID가 없으면 selected cohort cache reuse 또는 phenotype recommendation 수행
   - target
   - comparator
   - outcome 1..N
7. 최종 target / comparator / outcome cohort ID 확정
8. cohort ID 유효성 검사
9. comparison label 결정
10. cohort ID remap 여부 결정
11. negative control concept set / covariate concept set placeholder 입력
12. analytic settings 수집
    - `step_by_step`
    - `free_text`
13. cohort JSON 복사 및 role / mapping artifact 생성
14. `outputs/` state/default/TODO artifact 생성
15. `analysis-settings/cmAnalysis.json` 생성
16. generated R script 작성

즉, 시작하자마자 target/comparator/outcome ID를 먼저 받는 구조가 아니라, 먼저 study intent와 statements를 정리한 뒤 recommendation/cache/explicit ID 규칙으로 cohort를 확정하는 구조다.


## 3. 현재까지 구현된 것

### 3.1 cohort methods intent split

cohort methods shell은 incidence용 `phenotype_intent_split`과 별도로 아래 전용 flow를 사용한다.

- ACP endpoint: `/flows/cohort_methods_intent_split`
- MCP tool: `cohort_methods_intent_split`
- Core helper: `cohort_methods_intent_split()`
- R shell artifact: `outputs/cohort_methods_intent_split.json`

prompt/schema asset은 아래 위치에 있다.

- `mcp_server/prompts/phenotype/overview_cohort_methods_intent_split.md`
- `mcp_server/prompts/phenotype/spec_cohort_methods_intent_split.md`
- `mcp_server/prompts/phenotype/output_schema_cohort_methods_intent_split.json`

현재 split contract는 target/comparator/outcome을 분리하며, outcome은 multi-outcome을 지원한다.

- `target_statement`
- `comparator_statement`
- `outcome_statement`
- `outcome_statements`

R shell 쪽에서는 `outcome_statements`를 정규화/중복 제거해서 실제 multi-outcome recommendation source로 사용하고, `outcome_statement`는 첫 번째 outcome statement를 담는 backward-compatible primary field로 유지한다.


### 3.2 statement source 우선순위

statement 값은 아래 우선순위로 결정된다.

1. explicit function arguments
2. cached `manual_intent.json` 또는 `manual_inputs.json`
3. cached `outputs/cohort_methods_intent_split.json`
4. ACP `/flows/cohort_methods_intent_split`
5. interactive manual entry

non-interactive 실행에서는 explicit/cached statement 또는 성공한 intent split이 필요하다. statement가 비어 있으면 자동 fallback 문구를 쓰지 않고 중단한다.


### 3.3 role별 phenotype recommendation

각 statement마다 incidence shell과 유사한 recommendation 흐름을 수행한다.

- target statement -> phenotype recommendation
- comparator statement -> phenotype recommendation
- outcome statement(s) -> phenotype recommendation

artifact는 role별로 분리된다.

- `outputs/recommendations_target.json`
- `outputs/recommendations_comparator.json`
- `outputs/recommendations_outcome.json`
- `outputs/recommendations_outcome_2.json`
- `outputs/recommendations_outcome_3.json`

기본 selection 규칙은 아래와 같다.

- target: 단일 선택
- comparator: 단일 선택
- outcome: 다중 outcome statement / 다중 outcome cohort 선택 가능

multi-outcome split 결과가 있고 explicit outcome IDs가 없으면 outcome statement별로 recommendation을 별도 수행한다. 생성 artifact에서는 selected outcome cohort와 그 cohort를 만든 outcome statement mapping을 가능한 범위에서 유지한다.


### 3.4 cache reuse 흐름

recommendation 전에 cache reuse 여부를 먼저 판단한다.

우선순위는 아래와 같다.

1. cohort methods 자체 selected cohort cache가 있으면 그것을 쓸지 먼저 묻는다.
2. cohort methods cache가 없고 cohort incidence selected cohort cache가 있으면 incidence cache를 쓸지 묻는다.
3. 둘 다 없으면 phenotype recommendation을 진행한다.

현재 incidence에서 재사용하는 것은 recommendation artifact 자체가 아니라 이미 최종 확정되어 저장된 cohort selection이다.

참고 경로는 아래와 같다.

- `demo-strategus-cohort-incidence/outputs/cohort_id_map.json`
- `demo-strategus-cohort-incidence/selected-target-cohorts`
- `demo-strategus-cohort-incidence/selected-outcome-cohorts`

comparator는 incidence 쪽에서 바로 가져올 selection이 없으므로, 현재는 cohort methods cache 또는 새 recommendation만 사용한다.

cache reuse prompt는 cohort name + ID를 함께 보여주는 방향으로 정리되어 있다. 예를 들면 target/outcome cache를 재사용할지 묻기 전에 `Metformin exposure (ID ...)`처럼 실제 선택 대상을 확인할 수 있다.


### 3.5 explicit cohort ID 우선 처리

non-interactive 실행에서 호출자가 직접 준 cohort ID가 recommendation auto-selection에 의해 덮어써지던 문제는 수정되었다.

아래 인자가 들어오면 recommendation보다 먼저 최종 선택으로 확정된다.

- `targetCohortId`
- `comparatorCohortId`
- `outcomeCohortIds`

이 경우 cohort methods intent split도 `skipped_explicit_cohort_ids`로 처리될 수 있으며, explicit statements와 IDs만으로 shell smoke가 통과하는 상태다.


### 3.6 incidence cache 로딩 보강

처음에는 incidence cache가 있어도 cohort methods shell이 이를 제대로 감지하지 못하는 문제가 있었다.

주요 원인은 `cohort_id_map.json` 구조 차이였다.

- 실제 incidence artifact는 row-array 형태 JSON을 사용한다.
- 기존 loader는 사실상 column-style 구조만 기대하고 있었다.

현재는 `load_cached_role_selection()`이 두 형태를 모두 읽을 수 있게 보강되었다.


### 3.7 artifact 기록 범위

현재 아래 artifact들에는 intent split, statement, recommendation/cache, analytic settings 관련 정보가 남는다.

- `outputs/manual_intent.json`
- `outputs/manual_inputs.json`
- `outputs/cohort_id_map.json`
- `outputs/cohort_roles.json`
- `outputs/cm_comparisons.json`
- `outputs/cm_analysis_defaults.json`
- `outputs/cm_concept_set_selections.json`
- `outputs/study_agent_state.json`
- `outputs/acp_mcp_todo.json`
- `outputs/improvements_status.json`
- `outputs/cm_evaluation_todo.json`
- `analysis-settings/cmAnalysis.json`

특히 `manual_intent.json`에는 TODO placeholder가 아니라 실제 target/comparator/outcome statement가 저장된다. `study_agent_state.json`, `manual_inputs.json`, `cm_analysis_defaults.json`에는 `analysis-settings/cmAnalysis.json` 경로도 함께 기록된다.


### 3.8 analytic settings

analytic settings는 현재 항상 수집된다. 지원 mode는 아래 두 가지다.

- `step_by_step`
- `free_text`

`free_text` mode는 아직 placeholder ACP/stub 흐름이다. 설명 source 우선순위는 아래와 같다.

1. `analyticSettingsDescription`
2. `analyticSettingsDescriptionPath`
3. cached description/path
4. interactive typed input

생성 artifact는 아래와 같다.

- `outputs/cm_analytic_settings_recommendation.json`
- `outputs/cm_acp_specifications_recommendation.json`

`step_by_step` mode는 이제 section-level prompting이 실제 구현되어 있다. section 순서는 아래와 같다.

1. `study_population`
2. `time_at_risk`
3. `propensity_score_adjustment`
4. `outcome_model`

각 section은 core setting을 먼저 묻고, 나머지 exposed setting은 defaults summary를 보여준 뒤 사용자가 원할 때만 하나씩 custom 입력을 받는다. analytic settings profile name은 네 section 입력이 끝난 뒤 마지막에 묻는다.

현재 core prompt는 대략 아래 범위를 포함한다.

- study population: `studyStartDate`, `studyEndDate`
- time at risk: `startAnchor`, `riskWindowStart`, `endAnchor`, `riskWindowEnd`
- PS adjustment: `strategy`, `maxRatio` 또는 `numberOfStrata`
- outcome model: `modelType`

그 외 expanded defaults에는 PS trimming, fitting controls, outcome-model covariate/regularization flags 등이 포함된다.


### 3.9 `cmAnalysis.json` contract artifact

현재 shell은 `analysis-settings/cmAnalysis.json`을 추가로 생성한다. 이 파일은 public OHDSI/Strategus/CohortMethod schema가 아니라, 현재 StudyAgent cohort methods shell에서 downstream CohortMethod-oriented 처리를 위해 쓰는 임시 contract artifact다.

관련 파일은 아래에 있다.

- `R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`
- `R/OHDSIAssistant/inst/templates/CM_ANALYSIS_TEMPLATE.md`

conditional field 규칙은 아래처럼 정리되어 있다.

- `trimByPsArgs = null` when trimming is `none`
- `matchOnPsArgs = null` unless strategy is `match_on_ps`
- `stratifyByPsArgs = null` unless strategy is `stratify_by_ps`
- `createPsArgs = null` only when both PS adjustment and PS trimming are `none`
- regularization controls are expanded into `prior` / `control`, or `null` when disabled

단, generated `06_cm_spec.R`는 아직 `analysis-settings/cmAnalysis.json`을 직접 읽지 않고 `outputs/cm_analysis_defaults.json`를 사용한다.


### 3.10 generated script

generated script는 현재 아래 파일들을 만든다.

- `03_generate_cohorts.R`
- `04_keeper_review.R`
- `05_diagnostics.R`
- `06_cm_spec.R`
- `07_cm_run_analyses.R`

`06_cm_spec.R` 생성은 expanded analytic defaults를 반영한다.

- `studyStartDate` / `studyEndDate`를 `createGetDbCohortMethodDataArgs()`에 전달
- PS strategy가 `none`이면 `createPsArgs = NULL`
- trimming strategy에 따라 `trimByPsArgs` 구성
- `match_on_ps`일 때만 `matchOnPsArgs` 구성
- `stratify_by_ps`일 때만 `stratifyByPsArgs` 구성
- PS regularization을 `prior` object로 변환
- outcome model의 `useCovariates`, `inversePtWeighting`, `useRegularization` 반영
- PS strategy와 `maxRatio`로 outcome model `stratified` default 파생


## 4. 현재 검증된 것

현재까지 확인된 주요 검증은 아래와 같다.

- `Rscript -e "source('R/OHDSIAssistant/R/strategus_cohort_methods_shell.R')"` 통과
- explicit target/comparator/outcome IDs를 넣은 non-interactive cohort methods shell smoke 통과
- mock ACP multi-outcome smoke에서 GI bleeding / MACE 같은 복수 outcome statement가 별도 recommendation call/file로 이어지는 것 확인
- explicit-ID smoke에서 intent split/recommendation을 우회하고 hardcoded statement fallback을 쓰지 않는 것 확인
- `python -m json.tool mcp_server/prompts/phenotype/output_schema_cohort_methods_intent_split.json` 통과
- `python -m json.tool R/OHDSIAssistant/inst/templates/cmAnalysis_template.json` 통과
- `tests/test_llm_client.py` 통과
- cohort methods intent split 관련 targeted Python tests 통과
- `testthat` 기반 lightweight analytic-settings test 통과
- `cmAnalysis.json` 생성 및 null-rule helper checks 확인

단, 전체 `pytest`는 로컬 pytest temp/cache permission 문제로 막힌 이력이 있다. 알려진 assertion failure 때문이 아니라 `pytest-cache-files-*`, `tmp/pytest-*` 디렉터리 권한 문제로 분리해서 봐야 한다.


## 5. 아직 남아 있는 TODO

### 5.1 comparator settings 마무리

현재 highest-priority product TODO는 comparator settings를 마무리하는 것이다. cohort methods 비교 설계에서 comparator 관련 설정이 실제 downstream 분석 설정과 어떻게 연결될지 정리해야 한다.


### 5.2 cohort methods intent split hardening

`cohort_methods_intent_split`은 동작하지만 더 단단하게 만들 여지가 있다.

- clarification answer를 받아 re-split하는 interactive branch 보강
- 모델이 schema를 echo하지 않도록 prompt instruction hardening
- 가능하면 API-level structured output / response format 적용 검토
- broader regression coverage 추가

현재 `llm_client`에는 schema echo 뒤에 실제 answer JSON이 이어지는 경우를 salvage하는 parser 보강이 들어가 있다. 다만 prompt 자체도 더 튼튼하게 만들 필요가 있다.


### 5.3 cached manual input 우선순위 정리

explicit function argument override 문제는 수정되었지만, cached `manual_inputs.json`에 있던 cohort ID가 recommendation/cache보다 먼저 확정되어야 하는지는 정책 정리가 더 필요하다.

현재 상태는 아래와 같다.

- explicit function argument는 보호된다.
- cached manual input 기반 rerun에서는 cohort methods cache 또는 recommendation 쪽으로 selection이 바뀔 수 있는 리스크가 남아 있다.

따라서 resume/cache/manual input precedence를 명시적으로 정리해야 한다.


### 5.4 malformed explicit cohort ID 처리

예를 들어 `targetCohortId = "abc"`처럼 잘못된 값을 함수 인자로 주었을 때 즉시 invalid input으로 막는 validation을 더 엄격하게 만들 필요가 있다.


### 5.5 incidence cache 경로 해석 안정화

현재 기본 incidence 경로는 `demo-strategus-cohort-incidence`다. 실행 위치와 `studyAgentBaseDir`에 따라 상대경로 해석이 흔들릴 수 있으므로 아래를 안정화해야 한다.

- repo root 기준 fallback
- `studyAgentBaseDir` 기준 해석
- `getwd()`가 달라져도 incidence outputs를 찾을 수 있는지


### 5.6 negative control / covariates concept set 실제 구현

현재 negative control concept set과 covariate concept set은 수동 concept set ID 입력 + dummy placeholder artifact 생성 수준이다.

향후 구현에서는 concept set definition을 외부 source에서 가져와 materialize할 수 있어야 한다. 특히 `OHDSI/OmopConcepts` 같은 repo에서 negative control 및 covariate include/exclude concept set을 가져오는 방향을 검토할 필요가 있다.

장기적으로는 아래가 필요하다.

- selected concept set ID뿐 아니라 source repo/path/version 기록
- 실제 concept set definition import
- dummy placeholder JSON을 imported concept set artifact로 대체
- generated script와 TODO artifact에 source provenance 기록


### 5.7 cohort methods specifications recommendation ACP

analytic settings recommendation은 아직 실제 ACP flow가 없다.

필요한 작업은 아래와 같다.

- `/flows/cohort_methods_specifications_recommendation` 구현
- recommendation payload schema 결정
- defaults override 방식 결정
- section별 설정 표현 방식 결정
- R shell의 placeholder response parsing을 실제 ACP response에 맞춰 교체


### 5.8 incidence shell과의 구조 정렬

cohort methods recommendation/cache 흐름은 incidence shell을 참고했지만, ACP 연결/실패 처리 구조가 완전히 같지는 않다.

앞으로 결정할 것:

- cohort methods도 shell 초반에 `acp_connect(acpUrl)`를 명시할지
- incidence shell의 `acp_try()` 패턴을 공유할지
- failure policy를 incidence처럼 더 강하게 가져갈지, 지금처럼 일부 fallback/stub을 유지할지
- checkpoint / resume를 ACP 단계까지 incidence처럼 정교화할지
- `strategus_incidence_shell.R`와 `strategus_cohort_methods_shell.R` 사이 helper logic을 공유할지


### 5.9 generated spec의 settings source 정리

현재 `analysis-settings/cmAnalysis.json`은 생성되지만 `06_cm_spec.R`는 여전히 `outputs/cm_analysis_defaults.json`를 읽는다.

앞으로 결정해야 한다.

- `06_cm_spec.R`가 계속 `cm_analysis_defaults.json`를 읽을지
- 더 명시적인 `analysis-settings/cmAnalysis.json` contract를 직접 소비하게 바꿀지
- 두 artifact의 책임을 어떻게 나눌지


### 5.10 test coverage 보강

앞으로 최소한 아래를 더 검증해야 한다.

- interactive multi-outcome statement confirmation UX
- stale cache behavior around multi-outcome split and selected outcome IDs
- full shell `step_by_step` runs
- `free_text` mode with `analyticSettingsDescription`
- `free_text` mode with `analyticSettingsDescriptionPath`
- ACP stub fallback
- cache/resume behavior
- explicit function argument가 recommendation에 덮어써지지 않는지
- incidence cache reuse prompt가 실제로 뜨는지
- malformed explicit ID가 적절히 실패하는지


## 6. 중요한 결정 사항

- Analytic settings는 mandatory로 유지한다. 모든 run에서 cohort-method configuration이 명시적으로 남도록 하기 위해서다.
- `step_by_step`과 `free_text` 두 mode를 유지한다. ACP recommendation이 미완성인 동안에도 사용자가 구조화 입력 또는 자유 입력 중 선택할 수 있어야 한다.
- `step_by_step`은 모든 parameter를 다 묻는 방식이 아니라 constrained wizard model이다. section별 core setting을 먼저 묻고, 나머지는 default 유지 또는 선택적 customization으로 둔다.
- `maxRatio` 기본값은 `1`이고, `maxRatio = 0`도 valid로 허용한다.
- PS trimming은 `none`, `by_percent`, `by_equipoise`를 지원하며 equipoise default는 `0.25 / 0.75`다.
- `customized_sections`는 cached section names를 신뢰하지 않고 system defaults와 실제 값의 diff로 다시 계산한다.
- hardcoded cohort statement fallback은 제거되었다. ACP/MCP/LLM failure를 조용히 숨기고 잘못된 downstream recommendation을 만들 수 있기 때문이다.
- `outcome_statement`는 compatibility scalar로 남기고, `outcome_statements`를 multi-outcome source of truth로 사용한다.


## 7. 관련 주요 파일

- `R/OHDSIAssistant/R/strategus_cohort_methods_shell.R`
- `R/OHDSIAssistant/R/strategus_cohort_methods_analytic_settings.R`
- `R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`
- `R/OHDSIAssistant/inst/templates/CM_ANALYSIS_TEMPLATE.md`
- `acp_agent/study_agent_acp/agent.py`
- `acp_agent/study_agent_acp/llm_client.py`
- `acp_agent/study_agent_acp/server.py`
- `core/study_agent_core/tools.py`
- `mcp_server/study_agent_mcp/tools/cohort_methods_intent_split.py`
- `mcp_server/prompts/phenotype/overview_cohort_methods_intent_split.md`
- `mcp_server/prompts/phenotype/spec_cohort_methods_intent_split.md`
- `mcp_server/prompts/phenotype/output_schema_cohort_methods_intent_split.json`
- `docs/STRATEGUS_COHORT_METHODS_SHELL.md`
- `docs/TESTING.md`
- `HANDOFF.md`


## 8. 다음 작업 추천

가장 자연스러운 다음 순서는 아래다.

1. comparator settings 마무리
2. cohort methods intent split prompt hardening 및 structured-output 검토
3. `/flows/cohort_methods_specifications_recommendation` 실제 ACP/MCP 구현
4. full shell `step_by_step`, multi-outcome, cache/resume regression coverage 보강
5. `06_cm_spec.R`가 `cmAnalysis.json`을 직접 소비할지 결정
