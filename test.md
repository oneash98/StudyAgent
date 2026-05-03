# Cohort Methods 수동 검증

**검증 대상:**
1. ACP endpoint + MCP 구현 (`/flows/cohort_methods_specifications_recommendation`)
2. `suggestCohortMethodSpecs()` R wrapper (study intent + analytic settings description만 전달)
3. `runStrategusCohortMethodsShell` `free_text` 모드 (wrapper를 통해 ACP 호출함)
4. `runStrategusCohortMethodsShell` `step_by_step` 모드 (ACP 호출 **안** 함)

---

## 0. Pre-flight

```bash
export LLM_API_KEY=...
export LLM_API_URL=https://api.openai.com/v1/chat/completions
export LLM_MODEL=gpt-4o-mini

source .venv/bin/activate && pip install -e . >/dev/null
Rscript -e 'install.packages(c("jsonlite","httr","devtools"), repos="https://cloud.r-project.org"); devtools::install_local("R/OHDSIAssistant", upgrade="never")'
```

PASS: `which study-agent-acp` 보임 + `Rscript -e 'library(OHDSIAssistant)'` 에러 없음.

---

## 1. ACP endpoint + MCP

```bash
.venv/bin/doit smoke_cohort_methods_specs_recommend_flow
```

**PASS:**
```
status: ok
recommendation.status: received
profile_name: <비어있지 않음>
failed_sections: []
  getDbCohortMethodDataArgs: high|medium  ...
  createStudyPopArgs:        high|medium  ...
  propensityScoreAdjustment: high|medium  ...
  fitOutcomeModelArgs:       high|medium  ...
```

FAIL: `llm_parse_error` / `schema_validation_error` / `recommendation.status: backfilled` / 모든 섹션 `low`.

---

## 2. `suggestCohortMethodSpecs()` R wrapper

R REPL에서:
```r
library(OHDSIAssistant); acp_connect("http://127.0.0.1:8765")
res <- suggestCohortMethodSpecs(
  studyIntent = "Compare sitagliptin vs glipizide new users for AMI.",
  analyticSettingsDescription = "365-day washout, 1:1 PS match (caliper 0.2, standardized logit), Cox.",
  interactive = TRUE
)
```

**PASS (3가지 모두):**
- 콘솔에 `== Cohort Method Specifications ==`와 비어있지 않은 profile/status가 보임.
- 콘솔에 `[Study Population]`, `[Time At Risk]`, `[Propensity Score Adjustment]`, `[Outcome Model]` 섹션별 analytic settings summary가 보임.
- `res$status`가 `"ok"`.
- 아래 R 결과가 모두 `TRUE`:
  ```r
  identical(names(res$request), c("study_intent", "study_description", "analytic_settings_description"))
  !("target_cohort_id" %in% names(res$request))
  !("defaults_snapshot" %in% names(res$request))
  ```

---

## 3. `runStrategusCohortMethodsShell` — `free_text` 모드

별도 터미널에서 MCP + ACP 가동 (백그라운드):
```bash
cd /Users/minseongkim/Desktop/StudyAgent && source .venv/bin/activate

MCP_TRANSPORT=http MCP_HOST=127.0.0.1 MCP_PORT=8790 MCP_PATH=/mcp \
  study-agent-mcp > /tmp/mcp.log 2>&1 &

STUDY_AGENT_MCP_URL=http://127.0.0.1:8790/mcp \
STUDY_AGENT_HOST=127.0.0.1 STUDY_AGENT_PORT=8765 \
LLM_API_KEY="$LLM_API_KEY" LLM_API_URL="$LLM_API_URL" LLM_MODEL="$LLM_MODEL" \
LLM_LOG=1 LLM_LOG_PROMPT=1 LLM_LOG_RESPONSE=1 \
  study-agent-acp > /tmp/acp.log 2>&1 &

sleep 2 && curl -s http://127.0.0.1:8765/health
```
헬스 응답에 `"mcp":{"ok":true,...}` 떠야 PASS.

종료: `pkill -f study-agent-mcp; pkill -f study-agent-acp`

**중요:** 인터랙티브 셸은 `Rscript -e`로 돌리면 `readline()`이 비대화형이라 무한루프. **R REPL 안**에서 돌려야 함.

```bash
R
```
프롬프트(`>`)에 붙여넣기:
```r
library(OHDSIAssistant); acp_connect("http://127.0.0.1:8765")
runStrategusCohortMethodsShell(
  outputDir   = "~/cm-test/free_text",
  studyIntent = "Compare sitagliptin vs glipizide new users for AMI.",
  targetCohortId = 1001, comparatorCohortId = 1002, outcomeCohortIds = c(2001),
  comparisonLabel = "Sitagliptin vs Glipizide",
  analyticSettingsDescription = "365-day washout, 1:1 PS match (caliper 0.2, standardized logit), Cox.",
  interactive = TRUE, reset = TRUE)
```

프롬프트 입력: 모드 선택 → `2`, confirm → `Y` (그 외는 default Enter).

**PASS (3가지 모두):**
- 콘솔에 `Calling ACP flow: cohort_methods_specifications_recommendation` 등장.
- `~/cm-test/free_text/outputs/cm_acp_specifications_recommendation.json` 생성.
- 아래 jq 결과:
  ```bash
  jq '.source, .status, .recommendation.status, (.request | keys), (.request | has("target_cohort_id")), (.request | has("defaults_snapshot"))' \
    ~/cm-test/free_text/outputs/cm_acp_specifications_recommendation.json
  ```
  ```
  "acp_flow"
  "received"
  "received"
  [
    "analytic_settings_description",
    "study_description",
    "study_intent"
  ]
  false
  false
  ```

---

## 4. `runStrategusCohortMethodsShell` — `step_by_step` 모드

R REPL에서:
```r
library(OHDSIAssistant); acp_connect("http://127.0.0.1:8765")
runStrategusCohortMethodsShell(
  outputDir   = "~/cm-test/step_by_step",
  studyIntent = "Compare sitagliptin vs glipizide new users for AMI.",
  targetCohortId = 1001, comparatorCohortId = 1002, outcomeCohortIds = c(2001),
  comparisonLabel = "Sitagliptin vs Glipizide",
  interactive = TRUE, reset = TRUE)
```
(`analyticSettingsDescription` 인자 **빼야** 모드 선택지가 나옴)

프롬프트 입력: 모드 선택 → `1`, 각 섹션 "Keep these defaults?" → `Y`.

**PASS (3가지 모두):**
- 콘솔에 `Calling ACP flow: cohort_methods_specifications_recommendation` **없음**.
- `~/cm-test/step_by_step/outputs/cm_acp_specifications_recommendation.json` 파일 **없음**.
- 아래 jq 결과:
  ```bash
  jq '.analytic_settings_mode, .analytic_settings_recommendation_source' \
    ~/cm-test/step_by_step/outputs/manual_inputs.json
  ```
  ```
  "step_by_step"
  "not_applicable"
  ```

---

## 디버그 위치

- ACP/MCP 로그: `/tmp/study_agent_acp_*.log`, `/tmp/study_agent_mcp_*.log`
- 디스크 아티팩트: `<outputDir>/outputs/*.json`
- 회귀: `.venv/bin/pytest -q -k "cohort_methods or cohort_methods_spec"`
